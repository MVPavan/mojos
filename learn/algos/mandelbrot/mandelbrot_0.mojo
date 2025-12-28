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
        if cabs(z) > 2:
            return n
        z = z*z + c
    return max_iter

fn mandelbrot_set(vars:Vars) raises -> List[List[Int]]:
    var np = Python.import_module('numpy')
    var final_set=List[List[Int]]()
    var r1 = np.linspace(vars.xmin, vars.xmax, vars.width)
    var r2 = np.linspace(vars.ymin, vars.ymax, vars.height)
    
    for i in r2:
        var inner_set=List[Int]()
        for r in r1:
            inner_set.append(
                mandelbrot(
                    ComplexFloat64(r.to_float64(),i.to_float64()), vars.max_iter
                )
            )
        final_set.append(inner_set)
    
    # var final_size = 0
    # for in_set in final_set:
    #     final_size += in_set[].size

    # print("final size: ", final_size)
    return final_set


def plot_mandelbrot(vars:Vars):
    plt = Python.import_module('matplotlib.pyplot')
    np = Python.import_module('numpy')
    mandelbrot_set_data_mojo = mandelbrot_set(vars)

    mandelbrot_set_data_np = np.zeros((960, 960), dtype=np.float64)    
    for row in range(960):
        for col in range(960):
            mandelbrot_set_data_np.itemset((col,row),mandelbrot_set_data_mojo[col][row] )
            
    print(mandelbrot_set_data_np.shape)
    # np.save("output/mojo_dump.npy", mandelbrot_set_data_np)

    plt.imshow(mandelbrot_set_data_np.T, extent=[vars.xmin, vars.xmax, vars.ymin, vars.ymax], cmap='hot', interpolation='bilinear')
    plt.colorbar()
    plt.title("Mandelbrot Set")
    plt.xlabel("Re(c)")
    plt.ylabel("Im(c)")
    # plt.show()
    plt.savefig("output/dummy_name_2.png")


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
    print("Total time: ", (now()-t1)/1_000_000_000)

    # @parameter
    # fn bench() raises:
    #     mandelbrot_set(vars)
    
    # run[bench]().print()

    # plot_mandelbrot(vars)