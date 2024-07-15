from time import now
from algorithm import vectorize, parallelize
from tensor import Tensor, TensorSpec, TensorShape
from utils.index import Index
from testing import assert_true
from benchmark import run

alias UI8 = DType.uint8
alias TUI8 = Tensor[UI8]
alias smid_width = 4*simdwidthof[DType.float32]()

def test_images(A:TUI8):
    # check range of matrix
    var max_value = 0
    var min_value = 1e3
    for i in range(A.num_elements()):
        if A[i]>max_value:
            max_value = int(A[i])
        if A[i]<min_value:
            min_value = int(A[i])

    print("Max: ",max_value)
    print("Min: ",min_value)

fn bilinear(org:TUI8, inout res:TUI8):
    var height = org.dim(0)
    var width = org.dim(1)
    var channel = org.dim(2)

    var new_height = res.dim(0)
    var new_width = res.dim(1)

    var scale_x = width/new_width
    var scale_y = height/new_height
    var x:Float32
    var y:Float32
    var x_int:Int
    var y_int:Int
    var x_diff:Float32
    var y_diff:Float32
    var a:Int
    var b:Int
    var c:Int
    var d:Int
    var pixel:Float32

    for k in range(channel):
        for i in range(new_height):
            for j in range(new_width):
                x = (j+0.5) * (scale_x) - 0.5
                y = (i+0.5) * (scale_y) - 0.5
                x_int = int(x)
                y_int = int(y)

                # Prevent crossing
                x_int = min(x_int, width-2)
                y_int = min(y_int, height-2)

                x_diff = x - x_int
                y_diff = y - y_int

                a = int(org[y_int, x_int, k])
                b = int(org[y_int, x_int+1, k])
                c = int(org[y_int+1, x_int, k])
                d = int(org[y_int+1, x_int+1, k])

                pixel = a*(1-x_diff)*(1-y_diff) + b*(x_diff) * \
                    (1-y_diff) + c*(1-x_diff) * (y_diff) + d*x_diff*y_diff
    
                res[Index(i,j,k)] = int(pixel)


def main():
    var orig_shape = TensorShape(640,640,3)
    var resize_shape = TensorShape(256,256,3)
    var org_spec = TensorSpec(UI8, orig_shape)
    var resize_spec = TensorSpec(UI8, resize_shape)
    
    # var org = TUI8.rand(org_spec.shape)
    var org = TUI8(org_spec).__rmul__(0).__radd__(1)
    var res = TUI8(resize_spec).__rmul__(0)
    
    

    t1 = now()
    bilinear(org, res)
    t2 = now()
    dt = (t2-t1)/1e9

    print("resize: ",orig_shape, "->", resize_shape, ": ", dt, "s")
    print("speedup over python: ", 1.7087329153902828/dt)
    print("speedup over opencv: ", 0.0003149523865431547/dt)
    print("speedup in opencv: ", dt/0.0003149523865431547)

    @parameter
    fn bench():
        bilinear(org, res)
    
    bench_result = run[bench](min_runtime_secs=10)
    bench_result.print()
    print("resize: ",orig_shape, "->", resize_shape, ": ", bench_result.mean(), "s")
    print("speedup over python: ", 1.7087329153902828/bench_result.mean())
    print("speedup over opencv: ", 0.0003149523865431547/bench_result.mean())
    print("speedup in opencv: ", bench_result.mean()/0.0003149523865431547)
    print("worst speedup in opencv: ", bench_result.min()/0.0003149523865431547)
        
