from time import now
from collections import List
from benchmark import run, keep
from python import Python
from complex import ComplexFloat64, abs as cabs
from tensor import Tensor, TensorSpec, TensorShape
from utils.index import Index

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

fn mandelbrot_set(vars:Vars) raises -> List[List[Int]]:
    var final_set=List[List[Int]]()
    var scalex = (vars.xmax-vars.xmin)/vars.width
    var scaley = (vars.ymax-vars.ymax)/vars.height
    var spec = TensorSpec(DType.float64, vars.height, vars.width)
    var mbot_image = Tensor[DType.float64](spec)

    for h in range(vars.height):
        var cy = vars.ymin + h * scaley
        for w in range(vars.width):
            var cx = vars.xmin + w * scalex
            mbot_image[Index(h,w)] = mandelbrot(ComplexFloat64(cx,cy), vars.max_iter)

    print(mbot_image.shape())
    return final_set


def main():
    var vars = Vars(
        xmin = -2.0, 
        xmax = 0.6, 
        ymin = -1.5, 
        ymax = 1.5,
        width = 960,
        height = 960,
        max_iter = 200
    )
    t1 = now()
    mandelbrot_set(vars)
    t2 = now()
    dt = (t2-t1)/1_000_000_000
    print("Total time: ", dt)
    print("speedup over python: ", 7.176582172978669/dt)
    # @parameter
    # fn bench() raises:
    #     mandelbrot_set(vars)
    
    # run[bench]().print()

    # plot_mandelbrot(vars)