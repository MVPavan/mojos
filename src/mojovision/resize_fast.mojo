# ===----------------------------------------------------------------------=== #
# High-Performance Image Resize with Maximum CPU Optimization
# 
# Optimizations implemented:
# 1. Coefficient precomputation (avoids per-pixel coordinate math)
# 2. Separable processing for bilinear/bicubic (H-pass → V-pass)
# 3. Row-level parallelization with parallelize[]
# 4. X-loop vectorization with vectorize[]
# 5. Y-computation hoisting (computed once per row)
# 6. SIMD weight computation (4 weights in parallel)
# 7. Cache-optimized row caching for vertical pass
# 8. Aligned intermediate float32 buffer for SIMD efficiency
# ===----------------------------------------------------------------------=== #

from algorithm import parallelize, vectorize
from memory import UnsafePointer, memcpy, memset_zero, alloc
from math import floor, ceil, clamp
from sys import simd_width_of

from .image import ImageTensor

comptime UI8 = DType.uint8
comptime F32 = DType.float32
comptime I32 = DType.int32

# SIMD width for float32 operations
comptime SIMD_WIDTH: Int = 8


# =============================================================================
# Interpolation Mode Enum
# =============================================================================
struct InterpolationMode:
    """Interpolation modes for resize."""
    comptime NEAREST: Int = 0
    comptime BILINEAR: Int = 1
    comptime BICUBIC: Int = 2


# =============================================================================
# Cubic Kernel (OpenCV/PyTorch compatible, a = -0.75)
# =============================================================================
@always_inline
fn cubic_kernel(x: Float32) -> Float32:
    """Keys' cubic interpolation kernel with a = -0.75 (OpenCV/PyTorch)."""
    comptime a: Float32 = -0.75
    var abs_x = abs(x)
    var abs_x2 = abs_x * abs_x
    var abs_x3 = abs_x2 * abs_x
    
    if abs_x <= 1.0:
        return (a + 2.0) * abs_x3 - (a + 3.0) * abs_x2 + 1.0
    elif abs_x < 2.0:
        return a * abs_x3 - 5.0 * a * abs_x2 + 8.0 * a * abs_x - 4.0 * a
    return 0.0


@always_inline
fn cubic_kernel_simd(x: SIMD[F32, 4]) -> SIMD[F32, 4]:
    """SIMD cubic kernel - compute 4 weights in parallel."""
    comptime a = SIMD[F32, 4](-0.75)
    var abs_x = abs(x)
    var abs_x2 = abs_x * abs_x
    var abs_x3 = abs_x2 * abs_x
    
    var case1 = (a + 2.0) * abs_x3 - (a + 3.0) * abs_x2 + 1.0
    var case2 = a * abs_x3 - 5.0 * a * abs_x2 + 8.0 * a * abs_x - 4.0 * a
    var zero = SIMD[F32, 4](0.0)
    
    # Select based on |x| ranges
    return abs_x.le(1.0).select(case1, abs_x.lt(2.0).select(case2, zero))


# =============================================================================
# Image Resize Structure - Main API
# =============================================================================
struct ImageResizer:
    """High-performance image resizer with optimized algorithms."""
    
    @staticmethod
    fn resize_nearest(
        src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        src_h: Int, src_w: Int,
        dst_h: Int, dst_w: Int,
        channels: Int,
    ):
        """Nearest neighbor resize with vectorized x-loop."""
        var scale_y = Float32(src_h) / Float32(dst_h)
        var scale_x = Float32(src_w) / Float32(dst_w)
        var src_stride = src_w * channels
        var dst_stride = dst_w * channels
        var src_h_1 = src_h - 1
        var src_w_1 = src_w - 1
        
        @parameter
        fn process_row(y: Int):
            var src_y = min(Int(Float32(y) * scale_y), src_h_1)
            var src_row = src_ptr + src_y * src_stride
            var dst_row = dst_ptr + y * dst_stride
            
            @parameter
            fn copy_pixel[width: Int](x_base: Int) unified {mut}:
                @parameter
                for i in range(width):
                    var x = x_base + i
                    var src_x = min(Int(Float32(x) * scale_x), src_w_1)
                    var src_off = src_x * channels
                    var dst_off = x * channels
                    
                    # Unrolled RGB copy
                    @parameter
                    for c in range(3):
                        dst_row[dst_off + c] = src_row[src_off + c]
            
            vectorize[SIMD_WIDTH](dst_w, copy_pixel)
        
        parallelize[process_row](dst_h)
    
    @staticmethod
    fn resize_bilinear_separable(
        src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        src_h: Int, src_w: Int,
        dst_h: Int, dst_w: Int,
        channels: Int,
    ):
        """Bilinear resize using separable processing (H-pass → V-pass)."""
        # Allocate intermediate buffer (float32 for precision)
        var tmp_h = src_h  # After H-pass: src_h x dst_w
        var tmp_w = dst_w
        var tmp_size = tmp_h * tmp_w * channels
        var tmp_ptr = alloc[Float32](tmp_size)
        
        # Precompute X coefficients
        var x_offsets = alloc[Int32](dst_w)
        var x_coeffs = alloc[Float32](dst_w * 2)
        var scale_x = Float32(src_w) / Float32(dst_w)
        var src_w_1 = src_w - 1
        
        for i in range(dst_w):
            var src_f = (Float32(i) + 0.5) * scale_x - 0.5
            var src_i = Int(floor(src_f))
            var frac = src_f - Float32(src_i)
            src_i = max(0, min(src_i, src_w - 2))
            x_offsets[i] = Int32(src_i)
            x_coeffs[i * 2] = 1.0 - frac
            x_coeffs[i * 2 + 1] = frac
        
        # Precompute Y coefficients
        var y_offsets = alloc[Int32](dst_h)
        var y_coeffs = alloc[Float32](dst_h * 2)
        var scale_y = Float32(src_h) / Float32(dst_h)
        var tmp_h_1 = tmp_h - 1
        
        for i in range(dst_h):
            var src_f = (Float32(i) + 0.5) * scale_y - 0.5
            var src_i = Int(floor(src_f))
            var frac = src_f - Float32(src_i)
            src_i = max(0, min(src_i, src_h - 2))
            y_offsets[i] = Int32(src_i)
            y_coeffs[i * 2] = 1.0 - frac
            y_coeffs[i * 2 + 1] = frac
        
        var src_stride = src_w * channels
        var tmp_stride = tmp_w * channels
        var dst_stride = dst_w * channels
        
        # =====================================================================
        # PASS 1: Horizontal resize (src_h x src_w) → (src_h x dst_w)
        # =====================================================================
        @parameter
        fn h_pass_row(y: Int):
            var src_row = src_ptr + y * src_stride
            var tmp_row = tmp_ptr + y * tmp_stride
            
            @parameter
            fn h_interp[width: Int](x_base: Int) unified {mut}:
                @parameter
                for i in range(width):
                    var x = x_base + i
                    var x0 = Int(x_offsets[x])
                    var x1 = min(x0 + 1, src_w_1)
                    var w0 = x_coeffs[x * 2]
                    var w1 = x_coeffs[x * 2 + 1]
                    
                    var off0 = x0 * channels
                    var off1 = x1 * channels
                    var dst_off = x * channels
                    
                    @parameter
                    for c in range(3):
                        var v0 = Float32(Int(src_row[off0 + c]))
                        var v1 = Float32(Int(src_row[off1 + c]))
                        tmp_row[dst_off + c] = v0 * w0 + v1 * w1
            
            vectorize[SIMD_WIDTH](dst_w, h_interp)
        
        parallelize[h_pass_row](src_h)
        
        # =====================================================================
        # PASS 2: Vertical resize (src_h x dst_w) → (dst_h x dst_w)
        # =====================================================================
        @parameter
        fn v_pass_row(y: Int):
            var y0 = Int(y_offsets[y])
            var y1 = min(y0 + 1, tmp_h_1)
            var w0 = y_coeffs[y * 2]
            var w1 = y_coeffs[y * 2 + 1]
            
            var tmp_row0 = tmp_ptr + y0 * tmp_stride
            var tmp_row1 = tmp_ptr + y1 * tmp_stride
            var dst_row = dst_ptr + y * dst_stride
            
            @parameter
            fn v_interp[width: Int](x_base: Int) unified {mut}:
                @parameter
                for i in range(width):
                    var x = x_base + i
                    var off = x * channels
                    
                    @parameter
                    for c in range(3):
                        var v0 = tmp_row0[off + c]
                        var v1 = tmp_row1[off + c]
                        var val = v0 * w0 + v1 * w1
                        dst_row[off + c] = UInt8(Int(clamp(val, 0.0, 255.0)))
            
            vectorize[SIMD_WIDTH](dst_w, v_interp)
        
        parallelize[v_pass_row](dst_h)
        
        # Cleanup
        tmp_ptr.free()
        x_offsets.free()
        x_coeffs.free()
        y_offsets.free()
        y_coeffs.free()

    @staticmethod
    fn resize_bilinear_separable_fixed(
        src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        src_h: Int, src_w: Int,
        dst_h: Int, dst_w: Int,
        channels: Int,
    ):
        """
        Bilinear resize using separable processing with Q7.7 fixed-point.
        
        Uses int16 intermediate buffer (half the memory of float32) and
        fixed-point arithmetic for faster integer operations.
        
        Q7.7 format: Uses weights in [0, 128] where 128 = 1.0
        - H-pass: v0*w0 + v1*w1 with max = 255*128 = 32640 (fits int16!)
        - V-pass: (v0*w0 + v1*w1) >> 14 gives final uint8
        """
        # Fixed-point scale (7 fractional bits)
        comptime FRAC_BITS: Int = 7
        comptime SCALE: Int = 1 << FRAC_BITS  # 128
        
        # Allocate intermediate buffer (int16 - half the size of float32!)
        var tmp_h = src_h
        var tmp_w = dst_w
        var tmp_size = tmp_h * tmp_w * channels
        var tmp_ptr = alloc[Int16](tmp_size)
        
        # Precompute X coefficients as Q7.7 fixed-point
        var x_offsets = alloc[Int32](dst_w)
        var x_coeffs = alloc[Int16](dst_w * 2)  # [w0, w1] pairs
        var scale_x = Float32(src_w) / Float32(dst_w)
        var src_w_1 = src_w - 1
        
        for i in range(dst_w):
            var src_f = (Float32(i) + 0.5) * scale_x - 0.5
            var src_i = Int(floor(src_f))
            var frac = src_f - Float32(src_i)
            src_i = max(0, min(src_i, src_w - 2))
            x_offsets[i] = Int32(src_i)
            # Convert weights to Q7.7: w * 128
            x_coeffs[i * 2] = Int16(Int((1.0 - frac) * Float32(SCALE)))
            x_coeffs[i * 2 + 1] = Int16(Int(frac * Float32(SCALE)))
        
        # Precompute Y coefficients as Q7.7 fixed-point
        var y_offsets = alloc[Int32](dst_h)
        var y_coeffs = alloc[Int16](dst_h * 2)
        var scale_y = Float32(src_h) / Float32(dst_h)
        var tmp_h_1 = tmp_h - 1
        
        for i in range(dst_h):
            var src_f = (Float32(i) + 0.5) * scale_y - 0.5
            var src_i = Int(floor(src_f))
            var frac = src_f - Float32(src_i)
            src_i = max(0, min(src_i, src_h - 2))
            y_offsets[i] = Int32(src_i)
            y_coeffs[i * 2] = Int16(Int((1.0 - frac) * Float32(SCALE)))
            y_coeffs[i * 2 + 1] = Int16(Int(frac * Float32(SCALE)))
        
        var src_stride = src_w * channels
        var tmp_stride = tmp_w * channels
        var dst_stride = dst_w * channels
        
        # =====================================================================
        # PASS 1: Horizontal resize (uint8 input → int16 intermediate)
        # Result = (pixel0 * w0 + pixel1 * w1) with Q7.7 weights
        # Max value: 255 * 128 = 32640, fits in int16!
        # =====================================================================
        @parameter
        fn h_pass_row_fixed(y: Int):
            var src_row = src_ptr + y * src_stride
            var tmp_row = tmp_ptr + y * tmp_stride
            
            for x in range(dst_w):
                var x0 = Int(x_offsets[x])
                var x1 = min(x0 + 1, src_w_1)
                var w0 = Int(x_coeffs[x * 2])
                var w1 = Int(x_coeffs[x * 2 + 1])
                
                var off0 = x0 * channels
                var off1 = x1 * channels
                var dst_off = x * channels
                
                # Process RGB channels - compiler can unroll and vectorize
                @parameter
                for c in range(3):
                    var v0 = Int(src_row[off0 + c])
                    var v1 = Int(src_row[off1 + c])
                    tmp_row[dst_off + c] = Int16(v0 * w0 + v1 * w1)
        
        parallelize[h_pass_row_fixed](src_h)
        
        # =====================================================================
        # PASS 2: Vertical resize (int16 intermediate → uint8 output)
        # Input is Q7.7 (value * 128), weights are Q7.7
        # Multiply: (v*128) * (w_sum=128) = v*16384 = Q14.14
        # Need to shift right by 14 to get final uint8
        #
        # SIMD Strategy: All pixels in a row share same y0, y1, w0, w1!
        # Process 8 int16 values at once, widen to int32 for multiply,
        # shift right by 14, clamp, and narrow back to uint8.
        # =====================================================================
        @parameter
        fn v_pass_row_fixed(y: Int):
            var y0 = Int(y_offsets[y])
            var y1 = min(y0 + 1, tmp_h_1)
            var w0 = Int(y_coeffs[y * 2])
            var w1 = Int(y_coeffs[y * 2 + 1])
            
            var tmp_row0 = tmp_ptr + y0 * tmp_stride
            var tmp_row1 = tmp_ptr + y1 * tmp_stride
            var dst_row = dst_ptr + y * dst_stride
            
            # Total number of int16 values to process (pixels * channels)
            var total_channels = dst_w * channels
            
            # Process 8 int16 values at a time using SIMD
            comptime VEC_WIDTH: Int = 8
            var i = 0
            
            # Broadcast weights for SIMD
            var w0_vec = SIMD[DType.int32, VEC_WIDTH](w0)
            var w1_vec = SIMD[DType.int32, VEC_WIDTH](w1)
            
            # Main SIMD loop
            while i + VEC_WIDTH <= total_channels:
                # Load 8 int16 values from each row
                var v0_i16 = (tmp_row0 + i).load[width=VEC_WIDTH]()
                var v1_i16 = (tmp_row1 + i).load[width=VEC_WIDTH]()
                
                # Widen to int32 for multiplication to avoid overflow
                var v0 = v0_i16.cast[DType.int32]()
                var v1 = v1_i16.cast[DType.int32]()
                
                # Weighted sum and shift by 14 (7+7 fractional bits)
                var result_i32 = (v0 * w0_vec + v1 * w1_vec) >> 14
                
                # Clamp to [0, 255]
                var clamped = result_i32.clamp(0, 255)
                
                # Narrow to uint8 and store
                var result_u8 = clamped.cast[DType.uint8]()
                (dst_row + i).store[width=VEC_WIDTH](result_u8)
                
                i += VEC_WIDTH
            
            # Handle remaining values
            while i < total_channels:
                var v0 = Int(tmp_row0[i])
                var v1 = Int(tmp_row1[i])
                var val = (v0 * w0 + v1 * w1) >> 14
                dst_row[i] = UInt8(max(0, min(255, val)))
                i += 1
        
        parallelize[v_pass_row_fixed](dst_h)
        
        # Cleanup
        tmp_ptr.free()
        x_offsets.free()
        x_coeffs.free()
        y_offsets.free()
        y_coeffs.free()

    @staticmethod
    fn resize_bilinear_direct(
        src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        src_h: Int, src_w: Int,
        dst_h: Int, dst_w: Int,
        channels: Int,
    ):
        """Direct bilinear resize with vectorized x-loop."""
        var scale_y = Float32(src_h) / Float32(dst_h)
        var scale_x = Float32(src_w) / Float32(dst_w)
        var src_stride = src_w * channels
        var dst_stride = dst_w * channels
        var src_h_2 = src_h - 2
        var src_w_2 = src_w - 2
        
        @parameter
        fn process_row(y: Int):
            # Y interpolation (hoisted - computed once per row)
            var src_yf = (Float32(y) + 0.5) * scale_y - 0.5
            var y0 = max(0, min(Int(src_yf), src_h_2))
            var y1 = y0 + 1
            var wy1 = src_yf - Float32(y0)
            var wy0 = 1.0 - wy1
            
            var src_row0 = src_ptr + y0 * src_stride
            var src_row1 = src_ptr + y1 * src_stride
            var dst_row = dst_ptr + y * dst_stride
            
            @parameter
            fn vec_pixels[width: Int](x_base: Int) unified {mut}:
                @parameter
                for i in range(width):
                    var xi = x_base + i
                    var src_xf = (Float32(xi) + 0.5) * scale_x - 0.5
                    var x0 = max(0, min(Int(src_xf), src_w_2))
                    var x1 = x0 + 1
                    var wx1 = src_xf - Float32(x0)
                    var wx0 = 1.0 - wx1
                    
                    var w00 = wy0 * wx0
                    var w01 = wy0 * wx1
                    var w10 = wy1 * wx0
                    var w11 = wy1 * wx1
                    
                    var off0 = x0 * channels
                    var off1 = x1 * channels
                    var dst_off = xi * channels
                    
                    # Unrolled RGB interpolation
                    @parameter
                    for c in range(3):
                        var v00 = Float32(Int(src_row0[off0 + c]))
                        var v01 = Float32(Int(src_row0[off1 + c]))
                        var v10 = Float32(Int(src_row1[off0 + c]))
                        var v11 = Float32(Int(src_row1[off1 + c]))
                        var val = v00 * w00 + v01 * w01 + v10 * w10 + v11 * w11
                        dst_row[dst_off + c] = UInt8(Int(val))
            
            vectorize[SIMD_WIDTH](dst_w, vec_pixels)
        
        parallelize[process_row](dst_h)

    @staticmethod
    fn resize_bilinear_simd(
        src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        src_h: Int, src_w: Int,
        dst_h: Int, dst_w: Int,
        channels: Int,
    ):
        """True SIMD bilinear resize using gather/scatter (optimized port)."""
        var scale_x = Float32(src_w) / Float32(dst_w)
        var scale_y = Float32(src_h) / Float32(dst_h)
        var src_stride = src_w * channels
        var dst_stride = dst_w * channels
        var src_h_2 = src_h - 2
        var src_w_2 = src_w - 2
        
        comptime sw = SIMD_WIDTH
        
        # Precompute width indices ONCE
        var width_idx = alloc[Int32](dst_w)
        for wi in range(dst_w):
            width_idx[wi] = Int32(wi)
        
        @parameter
        fn parallel_row(i: Int):
            # Y coordinate (constant for this row)
            var y_f = (Float32(i) + 0.5) * scale_y - 0.5
            var y_int = max(0, min(Int(y_f), src_h_2))
            var y_diff = y_f - Float32(y_int)
            var one_minus_yd = 1.0 - y_diff
            
            var y_off0 = y_int * src_stride
            var y_off1 = (y_int + 1) * src_stride
            var dst_row_off = i * dst_stride
            
            @parameter
            fn vec_width[simd_w: Int](j: Int) unified {mut}:
                # Load width indices for SIMD_WIDTH pixels
                var j_idx = width_idx.load[width=simd_w](j)
                
                # Compute x coordinates
                var x_f = (j_idx.cast[DType.float32]() + 0.5) * scale_x - 0.5
                var x_int = max(min(x_f.cast[DType.int32](), src_w_2), 0)
                var x_diff = x_f - x_int.cast[DType.float32]()
                var one_minus_xd = 1.0 - x_diff
                
                # Precompute offsets
                var x_off0 = x_int * channels
                var x_off1 = (x_int + 1) * channels
                var out_base = dst_row_off + j_idx * channels
                
                # Process each channel (unrolled)
                @parameter
                for k in range(3):
                    # Gather indices for 4 corners
                    var base0 = y_off0 + k
                    var base1 = y_off1 + k
                    
                    # Gather 4 corners
                    var a = src_ptr.gather[width=simd_w](base0 + x_off0).cast[DType.float32]()
                    var b = src_ptr.gather[width=simd_w](base0 + x_off1).cast[DType.float32]()
                    var c = src_ptr.gather[width=simd_w](base1 + x_off0).cast[DType.float32]()
                    var d = src_ptr.gather[width=simd_w](base1 + x_off1).cast[DType.float32]()
                    
                    # Bilinear interpolation
                    var pixel = (
                        a * one_minus_xd * one_minus_yd +
                        b * x_diff * one_minus_yd +
                        c * one_minus_xd * y_diff +
                        d * x_diff * y_diff
                    )
                    
                    # Scatter
                    dst_ptr.scatter[width=simd_w](out_base + k, pixel.cast[DType.uint8]())
            
            vectorize[sw](dst_w, vec_width)
        
        parallelize[parallel_row](dst_h)
        
        # Cleanup
        width_idx.free()
    
    @staticmethod
    fn resize_bicubic_separable(
        src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        src_h: Int, src_w: Int,
        dst_h: Int, dst_w: Int,
        channels: Int,
    ):
        """Separable bicubic resize (H-pass with 4 taps → V-pass with 4 taps)."""
        # Allocate intermediate buffer
        var tmp_h = src_h
        var tmp_w = dst_w
        var tmp_size = tmp_h * tmp_w * channels
        var tmp_ptr = alloc[Float32](tmp_size)
        
        # Precompute X coefficients (4 weights per output pixel)
        var x_offsets = alloc[Int32](dst_w)
        var x_coeffs = alloc[Float32](dst_w * 4)
        var scale_x = Float32(src_w) / Float32(dst_w)
        
        for i in range(dst_w):
            var src_f = (Float32(i) + 0.5) * scale_x - 0.5
            var src_i = Int(floor(src_f))
            var frac = src_f - Float32(src_i)
            x_offsets[i] = Int32(src_i)
            
            # Compute 4 cubic weights using SIMD
            var distances = SIMD[F32, 4](-1.0, 0.0, 1.0, 2.0) - frac
            var weights = cubic_kernel_simd(distances)
            x_coeffs[i * 4] = weights[0]
            x_coeffs[i * 4 + 1] = weights[1]
            x_coeffs[i * 4 + 2] = weights[2]
            x_coeffs[i * 4 + 3] = weights[3]
        
        # Precompute Y coefficients
        var y_offsets = alloc[Int32](dst_h)
        var y_coeffs = alloc[Float32](dst_h * 4)
        var scale_y = Float32(src_h) / Float32(dst_h)
        
        for i in range(dst_h):
            var src_f = (Float32(i) + 0.5) * scale_y - 0.5
            var src_i = Int(floor(src_f))
            var frac = src_f - Float32(src_i)
            y_offsets[i] = Int32(src_i)
            
            var distances = SIMD[F32, 4](-1.0, 0.0, 1.0, 2.0) - frac
            var weights = cubic_kernel_simd(distances)
            y_coeffs[i * 4] = weights[0]
            y_coeffs[i * 4 + 1] = weights[1]
            y_coeffs[i * 4 + 2] = weights[2]
            y_coeffs[i * 4 + 3] = weights[3]
        
        var src_stride = src_w * channels
        var tmp_stride = tmp_w * channels
        var dst_stride = dst_w * channels
        var src_w_1 = src_w - 1
        var tmp_h_1 = tmp_h - 1
        
        # =====================================================================
        # PASS 1: Horizontal bicubic (src_h x src_w) → (src_h x dst_w)
        # =====================================================================
        @parameter
        fn h_pass_row(y: Int):
            var src_row = src_ptr + y * src_stride
            var tmp_row = tmp_ptr + y * tmp_stride
            
            @parameter
            fn h_interp[width: Int](x_base: Int) unified {mut}:
                @parameter
                for i in range(width):
                    var x = x_base + i
                    var base_x = Int(x_offsets[x])
                    var dst_off = x * channels
                    
                    @parameter
                    for c in range(3):
                        var sum: Float32 = 0.0
                        @parameter
                        for k in range(4):
                            var sx = clamp(base_x + k - 1, 0, src_w_1)
                            sum += Float32(Int(src_row[sx * channels + c])) * x_coeffs[x * 4 + k]
                        tmp_row[dst_off + c] = sum
            
            vectorize[4](dst_w, h_interp)
        
        parallelize[h_pass_row](src_h)
        
        # =====================================================================
        # PASS 2: Vertical bicubic (src_h x dst_w) → (dst_h x dst_w)
        # =====================================================================
        @parameter
        fn v_pass_row(y: Int):
            var base_y = Int(y_offsets[y])
            var dst_row = dst_ptr + y * dst_stride
            
            @parameter
            fn v_interp[width: Int](x_base: Int) unified {mut}:
                @parameter
                for i in range(width):
                    var x = x_base + i
                    var off = x * channels
                    
                    @parameter
                    for c in range(3):
                        var sum: Float32 = 0.0
                        @parameter
                        for k in range(4):
                            var sy = clamp(base_y + k - 1, 0, tmp_h_1)
                            var tmp_row = tmp_ptr + sy * tmp_stride
                            sum += tmp_row[off + c] * y_coeffs[y * 4 + k]
                        dst_row[off + c] = UInt8(Int(clamp(sum, 0.0, 255.0)))
            
            vectorize[4](dst_w, v_interp)
        
        parallelize[v_pass_row](dst_h)
        
        # Cleanup
        tmp_ptr.free()
        x_offsets.free()
        x_coeffs.free()
        y_offsets.free()
        y_coeffs.free()
    
    @staticmethod
    fn resize_bicubic_direct(
        src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        src_h: Int, src_w: Int,
        dst_h: Int, dst_w: Int,
        channels: Int,
    ):
        """Direct bicubic resize with inline weight computation (matches original pattern)."""
        var scale_y = Float32(src_h) / Float32(dst_h)
        var scale_x = Float32(src_w) / Float32(dst_w)
        var src_stride = src_w * channels
        var dst_stride = dst_w * channels
        var src_h_1 = src_h - 1
        var src_w_1 = src_w - 1
        
        @parameter
        fn process_row(y: Int):
            # Precompute y interpolation (hoisted - computed once per row)
            var src_yf = (Float32(y) + 0.5) * scale_y - 0.5
            var y0 = Int(src_yf)
            var ty = src_yf - Float32(y0)
            
            # Inline cubic weights for Y (using Catmull-Rom a=-0.5 to match original)
            var ty2 = ty * ty
            var ty3 = ty2 * ty
            var wy = SIMD[F32, 4](
                -0.5 * ty3 + ty2 - 0.5 * ty,
                1.5 * ty3 - 2.5 * ty2 + 1.0,
                -1.5 * ty3 + 2.0 * ty2 + 0.5 * ty,
                0.5 * ty3 - 0.5 * ty2
            )
            
            # Precompute y row offsets
            var row0 = max(0, min(y0 - 1, src_h_1)) * src_stride
            var row1 = max(0, min(y0, src_h_1)) * src_stride
            var row2 = max(0, min(y0 + 1, src_h_1)) * src_stride
            var row3 = max(0, min(y0 + 2, src_h_1)) * src_stride
            
            var dst_row = dst_ptr + y * dst_stride
            
            @parameter
            fn interp_pixel[width: Int](x_base: Int) unified {mut}:
                @parameter
                for i in range(width):
                    var xi = x_base + i
                    var src_xf = (Float32(xi) + 0.5) * scale_x - 0.5
                    var x0 = Int(src_xf)
                    var tx = src_xf - Float32(x0)
                    
                    # Inline cubic weights for X
                    var tx2 = tx * tx
                    var tx3 = tx2 * tx
                    var wx = SIMD[F32, 4](
                        -0.5 * tx3 + tx2 - 0.5 * tx,
                        1.5 * tx3 - 2.5 * tx2 + 1.0,
                        -1.5 * tx3 + 2.0 * tx2 + 0.5 * tx,
                        0.5 * tx3 - 0.5 * tx2
                    )
                    
                    # Precompute x column offsets
                    var col0 = max(0, min(x0 - 1, src_w_1)) * channels
                    var col1 = max(0, min(x0, src_w_1)) * channels
                    var col2 = max(0, min(x0 + 1, src_w_1)) * channels
                    var col3 = max(0, min(x0 + 2, src_w_1)) * channels
                    
                    var dst_off = xi * channels
                    
                    # Unrolled RGB bicubic (4x4 kernel)
                    @parameter
                    for c in range(3):
                        var r0 = (Float32(Int(src_ptr[row0 + col0 + c])) * wx[0] +
                                  Float32(Int(src_ptr[row0 + col1 + c])) * wx[1] +
                                  Float32(Int(src_ptr[row0 + col2 + c])) * wx[2] +
                                  Float32(Int(src_ptr[row0 + col3 + c])) * wx[3])
                        var r1 = (Float32(Int(src_ptr[row1 + col0 + c])) * wx[0] +
                                  Float32(Int(src_ptr[row1 + col1 + c])) * wx[1] +
                                  Float32(Int(src_ptr[row1 + col2 + c])) * wx[2] +
                                  Float32(Int(src_ptr[row1 + col3 + c])) * wx[3])
                        var r2 = (Float32(Int(src_ptr[row2 + col0 + c])) * wx[0] +
                                  Float32(Int(src_ptr[row2 + col1 + c])) * wx[1] +
                                  Float32(Int(src_ptr[row2 + col2 + c])) * wx[2] +
                                  Float32(Int(src_ptr[row2 + col3 + c])) * wx[3])
                        var r3 = (Float32(Int(src_ptr[row3 + col0 + c])) * wx[0] +
                                  Float32(Int(src_ptr[row3 + col1 + c])) * wx[1] +
                                  Float32(Int(src_ptr[row3 + col2 + c])) * wx[2] +
                                  Float32(Int(src_ptr[row3 + col3 + c])) * wx[3])
                        
                        var val = r0 * wy[0] + r1 * wy[1] + r2 * wy[2] + r3 * wy[3]
                        dst_row[dst_off + c] = UInt8(Int(max(Float32(0), min(Float32(255), val))))
            
            vectorize[4](dst_w, interp_pixel)
        
        parallelize[process_row](dst_h)


# =============================================================================
# High-Level API (ImageTensor compatible)
# =============================================================================
fn resize_fast(
    ref src: ImageTensor[UI8],
    out_h: Int,
    out_w: Int,
    mode: Int = InterpolationMode.BILINEAR,
    separable: Bool = True,
) -> ImageTensor[UI8]:
    """
    High-performance image resize with all optimizations enabled.
    
    Args:
        src: Source image in HWC format with uint8 values.
        out_h: Target height.
        out_w: Target width.
        mode: Interpolation mode `NEAREST`, `BILINEAR`, or `BICUBIC`.
        separable: Use separable processing. For best performance, use `resize_fast_auto`.
    
    Returns:
        Resized image tensor.
    """
    var dst = ImageTensor[UI8](out_h, out_w, src.channels)
    
    if mode == InterpolationMode.NEAREST:
        ImageResizer.resize_nearest(
            src.data, dst.data,
            src.height, src.width,
            out_h, out_w,
            src.channels,
        )
    elif mode == InterpolationMode.BILINEAR:
        if separable:
            ImageResizer.resize_bilinear_separable(
                src.data, dst.data,
                src.height, src.width,
                out_h, out_w,
                src.channels,
            )
        else:
            ImageResizer.resize_bilinear_direct(
                src.data, dst.data,
                src.height, src.width,
                out_h, out_w,
                src.channels,
            )
    else:  # BICUBIC
        if separable:
            ImageResizer.resize_bicubic_separable(
                src.data, dst.data,
                src.height, src.width,
                out_h, out_w,
                src.channels,
            )
        else:
            ImageResizer.resize_bicubic_direct(
                src.data, dst.data,
                src.height, src.width,
                out_h, out_w,
                src.channels,
            )
    
    return dst^


fn resize_fast_auto(
    ref src: ImageTensor[UI8],
    out_h: Int,
    out_w: Int,
    mode: Int = InterpolationMode.BILINEAR,
) -> ImageTensor[UI8]:
    """
    High-performance image resize with auto-selection of best algorithm.
    
    Based on benchmarks:
    - Nearest: Always uses direct (no interpolation overhead).
    - Bilinear: Always uses direct (coefficient precomputation overhead > benefit).
    - Bicubic: Always uses direct with inline weights (matches original pattern).
    
    Args:
        src: Source image in HWC format with uint8 values.
        out_h: Target height.
        out_w: Target width.
        mode: Interpolation mode `NEAREST`, `BILINEAR`, or `BICUBIC`.
    
    Returns:
        Resized image tensor.
    """
    var dst = ImageTensor[UI8](out_h, out_w, src.channels)
    
    if mode == InterpolationMode.NEAREST:
        ImageResizer.resize_nearest(
            src.data, dst.data,
            src.height, src.width,
            out_h, out_w,
            src.channels,
        )
    elif mode == InterpolationMode.BILINEAR:
        # Use SIMD for medium sizes (200K-2M output pixels) where it shows benefit
        var total_pixels = out_h * out_w
        if total_pixels >= 50000 and total_pixels < 2100000:
            ImageResizer.resize_bilinear_simd(
                src.data, dst.data,
                src.height, src.width,
                out_h, out_w,
                src.channels,
            )
        else:
            ImageResizer.resize_bilinear_direct(
                src.data, dst.data,
                src.height, src.width,
                out_h, out_w,
                src.channels,
            )
    else:  # BICUBIC
        ImageResizer.resize_bicubic_direct(
            src.data, dst.data,
            src.height, src.width,
            out_h, out_w,
            src.channels,
        )
    
    return dst^


# =============================================================================
# Direct pointer API (for maximum flexibility)
# =============================================================================
fn resize_ptr(
    src_ptr: UnsafePointer[UInt8, MutExternalOrigin],
    dst_ptr: UnsafePointer[UInt8, MutExternalOrigin],
    src_h: Int, src_w: Int,
    dst_h: Int, dst_w: Int,
    channels: Int,
    mode: Int = InterpolationMode.BILINEAR,
    separable: Bool = True,
):
    """
    Direct pointer resize API - zero-copy, maximum performance.
    Assumes HWC layout, uint8 data.
    """
    if mode == InterpolationMode.NEAREST:
        ImageResizer.resize_nearest(src_ptr, dst_ptr, src_h, src_w, dst_h, dst_w, channels)
    elif mode == InterpolationMode.BILINEAR:
        if separable:
            ImageResizer.resize_bilinear_separable(src_ptr, dst_ptr, src_h, src_w, dst_h, dst_w, channels)
        else:
            ImageResizer.resize_bilinear_direct(src_ptr, dst_ptr, src_h, src_w, dst_h, dst_w, channels)
    else:
        if separable:
            ImageResizer.resize_bicubic_separable(src_ptr, dst_ptr, src_h, src_w, dst_h, dst_w, channels)
        else:
            ImageResizer.resize_bicubic_direct(src_ptr, dst_ptr, src_h, src_w, dst_h, dst_w, channels)
