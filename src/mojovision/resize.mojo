# Resize kernels - SIMD vectorize + parallelize optimizations
from algorithm import parallelize, vectorize
from memory import memcpy, UnsafePointer
from sys import simd_width_of
from .image import ImageTensor, UI8, F32


struct ResizeMode:
    """Interpolation modes for resize."""
    comptime NEAREST = 0
    comptime BILINEAR = 1
    comptime BICUBIC = 2


# =============================================================================
# Core resize dispatcher
# =============================================================================
fn resize(
    ref src: ImageTensor[UI8],
    out_h: Int,
    out_w: Int,
    mode: Int = ResizeMode.BILINEAR,
) -> ImageTensor[UI8]:
    """Resize image to target dimensions. Uses ref to avoid copy."""
    var dst = ImageTensor[UI8](out_h, out_w, src.channels)
    
    if mode == ResizeMode.NEAREST:
        _resize_nearest_fast(src, dst)
    elif mode == ResizeMode.BILINEAR:
        _resize_bilinear_fast(src, dst)
    else:
        _resize_bicubic_fast(src, dst)
    
    return dst^


# =============================================================================
# NEAREST NEIGHBOR - Vectorized inner loop with unified closure
# =============================================================================
fn _resize_nearest_fast(ref src: ImageTensor[UI8], mut dst: ImageTensor[UI8]):
    """Nearest neighbor with parallel rows and vectorized x-loop."""
    var scale_y = Float32(src.height) / Float32(dst.height)
    var scale_x = Float32(src.width) / Float32(dst.width)
    var channels = src.channels
    var dst_w = dst.width
    var src_stride = src.stride_y()
    var dst_stride = dst.stride_y()
    var src_ptr = src.data
    var dst_ptr = dst.data
    var src_h_1 = src.height - 1
    var src_w_1 = src.width - 1

    @parameter
    fn process_row(y: Int):
        var src_y = min(Int(Float32(y) * scale_y), src_h_1)
        var src_row = src_ptr + src_y * src_stride
        var dst_row = dst_ptr + y * dst_stride

        # Vectorized x-loop with unified {mut} closure
        @parameter
        fn copy_pixel[width: Int](x: Int) unified {mut}:
            @parameter
            for i in range(width):
                var src_x = min(Int(Float32(x + i) * scale_x), src_w_1)
                var src_off = src_x * channels
                var dst_off = (x + i) * channels
                # RGB copy (unrolled for common case)
                dst_row[dst_off] = src_row[src_off]
                dst_row[dst_off + 1] = src_row[src_off + 1]
                dst_row[dst_off + 2] = src_row[src_off + 2]

        vectorize[8](dst_w, copy_pixel)

    parallelize[process_row](dst.height)


# =============================================================================
# BILINEAR - Vectorized with unified closure
# =============================================================================
fn _resize_bilinear_fast(ref src: ImageTensor[UI8], mut dst: ImageTensor[UI8]):
    """Bilinear with parallel rows and vectorized x-loop."""
    var scale_y = Float32(src.height) / Float32(dst.height)
    var scale_x = Float32(src.width) / Float32(dst.width)
    var channels = src.channels
    var src_h = src.height
    var src_w = src.width
    var dst_w = dst.width
    var src_stride = src.stride_y()
    var dst_stride = dst.stride_y()
    var src_ptr = src.data
    var dst_ptr = dst.data
    var src_h_2 = src_h - 2
    var src_w_2 = src_w - 2

    @parameter
    fn process_row(y: Int):
        # Compute y interpolation once per row (hoisted)
        var src_yf = (Float32(y) + 0.5) * scale_y - 0.5
        var y0 = max(0, min(Int(src_yf), src_h_2))
        var y1 = y0 + 1
        var wy1 = src_yf - Float32(y0)
        var wy0 = 1.0 - wy1

        var src_row0 = src_ptr + y0 * src_stride
        var src_row1 = src_ptr + y1 * src_stride
        var dst_row = dst_ptr + y * dst_stride

        @parameter
        fn interp_pixel[width: Int](x_base: Int) unified {mut}:
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

        vectorize[8](dst_w, interp_pixel)

    parallelize[process_row](dst.height)


# =============================================================================
# BICUBIC - Vectorized with unified closure
# =============================================================================
@always_inline
fn _cubic_weights(t: Float32) -> SIMD[F32, 4]:
    """Compute 4 cubic weights for offset t in [0, 1]. Keys' cubic (a=-0.5)."""
    var t2 = t * t
    var t3 = t2 * t
    return SIMD[F32, 4](
        -0.5 * t3 + t2 - 0.5 * t,
        1.5 * t3 - 2.5 * t2 + 1.0,
        -1.5 * t3 + 2.0 * t2 + 0.5 * t,
        0.5 * t3 - 0.5 * t2
    )


@always_inline
fn _clamp(val: Int, max_val: Int) -> Int:
    return max(0, min(val, max_val))


fn _resize_bicubic_fast(ref src: ImageTensor[UI8], mut dst: ImageTensor[UI8]):
    """Bicubic with parallel rows and vectorized x-loop."""
    var scale_y = Float32(src.height) / Float32(dst.height)
    var scale_x = Float32(src.width) / Float32(dst.width)
    var channels = src.channels
    var src_h = src.height
    var src_w = src.width
    var dst_w = dst.width
    var src_stride = src.stride_y()
    var dst_stride = dst.stride_y()
    var src_ptr = src.data
    var dst_ptr = dst.data
    var src_h_1 = src_h - 1
    var src_w_1 = src_w - 1

    @parameter
    fn process_row(y: Int):
        # Precompute y interpolation (hoisted)
        var src_yf = (Float32(y) + 0.5) * scale_y - 0.5
        var y0 = Int(src_yf)
        var ty = src_yf - Float32(y0)
        var wy = _cubic_weights(ty)

        # Precompute y row offsets
        var row0 = _clamp(y0 - 1, src_h_1) * src_stride
        var row1 = _clamp(y0, src_h_1) * src_stride
        var row2 = _clamp(y0 + 1, src_h_1) * src_stride
        var row3 = _clamp(y0 + 2, src_h_1) * src_stride

        var dst_row = dst_ptr + y * dst_stride

        @parameter
        fn interp_bicubic[width: Int](x_base: Int) unified {mut}:
            @parameter
            for i in range(width):
                var xi = x_base + i
                var src_xf = (Float32(xi) + 0.5) * scale_x - 0.5
                var x0 = Int(src_xf)
                var tx = src_xf - Float32(x0)
                var wx = _cubic_weights(tx)

                # Precompute x column offsets
                var col0 = _clamp(x0 - 1, src_w_1) * channels
                var col1 = _clamp(x0, src_w_1) * channels
                var col2 = _clamp(x0 + 1, src_w_1) * channels
                var col3 = _clamp(x0 + 2, src_w_1) * channels

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

        vectorize[4](dst_w, interp_bicubic)

    parallelize[process_row](dst.height)
