from time import now
from collections import List
from benchmark import run, keep
from python import Python
from complex import ComplexFloat64, ComplexSIMD
from tensor import Tensor, TensorSpec, TensorShape
from utils.index import Index
from math import iota
from algorithm import vectorize, parallelize
from autotune import cost_of


alias simd_width = simdwidthof[DType.int64]()

@value
struct Vars:
    var xmin:Float64
    var xmax:Float64
    var ymin:Float64
    var ymax:Float64
    var width:Int
    var height:Int
    var max_iter:Int


fn mandelbrot(c: ComplexFloat64, max_iter:Int) -> Int:
    var z = ComplexFloat64(0,0)
    for n in range(max_iter):
        if z.squared_norm() > 4:
            return n
        z = z.squared_add(c)
    return max_iter

fn mandelbrot_tensor(vars:Vars) -> Tensor[DType.float64]:
    var scalex = (vars.xmax-vars.xmin)/vars.width
    var scaley = (vars.ymax-vars.ymax)/vars.height
    var spec = TensorSpec(DType.float64, vars.height, vars.width)
    var mbot_image = Tensor[DType.float64](spec)

    for h in range(vars.height):
        var cy = vars.ymin + h * scaley
        for w in range(vars.width):
            var cx = vars.xmin + w * scalex
            mbot_image[Index(h,w)] = mandelbrot(ComplexFloat64(cx,cy), vars.max_iter)

    # print(mbot_image.shape())
    return mbot_image


fn mandelbrot_kernel[simd_width: Int](
    c: ComplexSIMD[DType.float64, simd_width], max_iter:Int
    ) -> SIMD[DType.index, simd_width]:

    var z = c
    var iters = SIMD[DType.index, simd_width](0)
    var in_set_mask = SIMD[DType.bool, simd_width](True)

    for n in range(max_iter):
        if not in_set_mask.reduce_or():
            break
        in_set_mask = z.squared_norm() <= 4
        iters = in_set_mask.select(iters + 1, iters)
        z = z.squared_add(c)
    return iters

fn mandelbrot_vec(vars:Vars) -> DTypePointer[DType.index]:
    var scalex = (vars.xmax-vars.xmin)/vars.width
    var scaley = (vars.ymax-vars.ymax)/vars.height
    var output = DTypePointer[DType.index].alloc(vars.height* vars.width)
    
    for h in range(vars.height):
        var cy = vars.ymin + h * scaley

        @parameter
        fn computer_vector[simd_width:Int](w:Int):
            var cx = vars.xmin + (w + iota[DType.float64, simd_width]()) * scalex
            output.store[width=simd_width](
                h * w + w,
                mandelbrot_kernel(
                    ComplexSIMD[DType.float64, simd_width](cx,cy), vars.max_iter
                )
            )
        
        vectorize[computer_vector, simd_width](vars.width)
    return output

fn mandelbrot_parallel(vars:Vars) -> DTypePointer[DType.index]:
    var scalex = (vars.xmax-vars.xmin)/vars.width
    var scaley = (vars.ymax-vars.ymax)/vars.height
    var output = DTypePointer[DType.index].alloc(vars.height* vars.width)
    
    @parameter
    fn compute_row(row:Int):
    # for h in range(vars.height):
        var cy = vars.ymin + row * scaley

        @parameter
        fn computer_vector[simd_width:Int](w:Int):
            var cx = vars.xmin + (w + iota[DType.float64, simd_width]()) * scalex
            output.store[width=simd_width](
                row * w + w,
                mandelbrot_kernel(
                    ComplexSIMD[DType.float64, simd_width](cx,cy), vars.max_iter
                )
            )
        
        vectorize[computer_vector, simd_width](vars.width)
    
    parallelize[compute_row](vars.height, 80)
    return output

def main():
    # var vars = Vars(
    #     xmin = -2.0, 
    #     xmax = 0.6, 
    #     ymin = -1.5, 
    #     ymax = 1.5,
    #     width = 960,
    #     height = 960,
    #     max_iter = 200
    # )

    var vars = Vars(
        xmin = -2.0, 
        xmax = 0.47, 
        ymin = -1.12, 
        ymax = 1.12,
        width = 4096,
        height = 4096,
        max_iter = 1000
    )

    t1 = now()
    mandelbrot_parallel(vars)
    t2 = now()
    dt = (t2-t1)/1_000_000_000
    print("Total time: ", dt)
    print("speedup over python: ", 770.2003130670637/dt)

    @parameter
    fn bench():
        mandelbrot_parallel(vars)
    
    bench_result = run[bench]()
    bench_result.print()
    print("speedup over python: ", 770.2003130670637/bench_result.mean())

    # plot_mandelbrot(vars)