from time import now
from algorithm import vectorize, parallelize
from tensor import Tensor, TensorSpec, TensorShape
from utils.index import Index
import random
from random import rand
from testing import assert_true
from benchmark import run
from python import Python


alias UI8 = DType.uint8
alias type = DType.uint8
alias TUI8 = Tensor[UI8]
alias simd_width = 1*simdwidthof[DType.float64]()
alias F32_SW = SIMD[DType.float32, simd_width]
alias I32_SW = SIMD[DType.uint8, simd_width]
alias TI = Tensor[DType.int32]

struct MyArray[nelts: Int, type:DType]:
    var data: DTypePointer[type]

    # Initialize zeroeing all values
    fn __init__(inout self):
        self.data = DTypePointer[type].alloc(nelts)
        memset_zero(self.data, nelts)

    # Initialize taking a pointer, don't set any elements
    fn __init__(inout self, data: DTypePointer[type]):
        self.data = data

    ## Initialize with random values
    @staticmethod
    fn rand() -> Self:
        var data = DTypePointer[type].alloc(nelts)
        rand(data, nelts)
        return Self(data)

    fn __getitem__(self, x: Int) -> Scalar[type]:
        return self.load[1](x)
    
    fn __str__(self) -> String:
        var res = String("[")
        for _i in range(nelts):
            res += str(self.load[1](_i)) + ", "
        res += "]"
        return res
    
    fn __repr__(self) -> String:
        return self.__str__()

    fn __setitem__(inout self, x: Int, val: Scalar[type]):
        self.store[1](x, val)
    
    fn __del__(owned self):
        self.data.free()

    fn load[simd_width: Int](self, x: Int) -> SIMD[type, simd_width]:
        return self.data.load[width=simd_width](x)

    fn store[simd_width: Int](self, x: Int, val: SIMD[type, simd_width]):
        return self.data.store[width=simd_width](x, val)

struct Matrix[rows: Int, cols: Int, channels: Int]:
    var data: DTypePointer[type]

    # Initialize zeroeing all values
    fn __init__(inout self):
        self.data = DTypePointer[type].alloc(rows * cols * channels)
        memset_zero(self.data, rows * cols * channels)

    # Initialize taking a pointer, don't set any elements
    fn __init__(inout self, data: DTypePointer[type]):
        self.data = data

    ## Initialize with random values
    @staticmethod
    fn rand() -> Self:
        var data = DTypePointer[type].alloc(rows * cols * channels)
        rand(data, rows * cols * channels)
        return Self(data)

    fn __getitem__(self, y: Int, x: Int, c: Int) -> Scalar[type]:
        return self.load[1](y, x, c)
    
    fn __getitem__(self, idx:Int) -> Scalar[type]:
        return self.data.load[width=1](idx)

    fn __setitem__(inout self, y: Int, x: Int, c: Int,  val: Scalar[type]):
        self.store[1](y, x, c, val)

    #y-row-height-i, x-col-width-j, c-channel-channel-k 
    # i*height*channels + j*channels + k
    fn load[width: Int](self, y: Int, x: Int, c: Int) -> SIMD[type, width]:
        print("load: ", y * self.cols*self.channels + x*self.channels + c)
        return self.data.load[width=width](y * self.cols*self.channels + x*self.channels + c)

    fn store[width: Int](self, y: Int, x: Int, c: Int, val: SIMD[type, width]):
        return self.data.store[width=width](y * self.cols*self.channels + x*self.channels + c, val)

    fn shape(self) -> String:
        return String(self.rows)+'x'+String(self.cols)+'x'+String(self.channels)
    
    fn __del__(owned self):
        self.data.free()

fn to_numpy[dtype:DType](tensor: Tensor[dtype]) -> PythonObject:
    # https://github.com/basalt-org/basalt
    try:
        var np = Python.import_module("numpy")

        np.set_printoptions(4)

        var rank = tensor.rank()
        var dims = PythonObject([])
        for i in range(rank):
            dims.append(tensor.dim(i))
        var pyarray: PythonObject = np.empty(dims, dtype=np.uint8)

        var pointer = int(pyarray.__array_interface__["data"][0].to_float64())
        var pointer_d = DTypePointer[dtype](address=pointer)
        var pointer_t = tensor.unsafe_ptr()
        memcpy(pointer_d, pointer_t, count=tensor.num_elements())
        _ = tensor
        return pyarray^
    except e:
        print("Error in to numpy", e)
        return PythonObject()


def test_images(A:TUI8, R:TUI8, func:fn(TUI8, inout TUI8)->None):
    var A_np = to_numpy[UI8](tensor=A)
    func(A, R)
    var cv2 = Python.import_module("cv2")
    var cv2_resize = cv2.resize(A_np, (R.dim(1), R.dim(0)), interpolation=cv2.INTER_LINEAR)
    var R_np = to_numpy[UI8](tensor=R)
    var np = Python.import_module("numpy")
    var err_rate = np.average(np.abs(cv2_resize-R_np))
    print("Mojo Org Tensor shape: ", A.shape())
    print("Mojo Result Tensor shape: ", R.shape())
    print("Numpy Org Tensor shape: ", A_np.shape)
    print("Numpy Result Tensor shape: ", R_np.shape)
    print("Average error: ", err_rate)


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


fn bilinear_vec(org:TUI8, inout res:TUI8):
    var height = org.dim(0)
    var width = org.dim(1)
    var channel = org.dim(2)

    var new_height = res.dim(0)
    var new_width = res.dim(1)

    var scale_x = width/new_width
    var scale_y = height/new_height

    var org_ptr = org.unsafe_ptr()
    var res_ptr = res.unsafe_ptr()

    var x = MyArray[simd_width, DType.float32]()
    var y:Float32 = 0
    var x_int = MyArray[simd_width, DType.int32]()
    var y_int:Int = 0
    var x_diff = MyArray[simd_width, DType.float32]()
    var y_diff:Float32 =0
    var a = MyArray[simd_width, DType.float32]()
    var b = MyArray[simd_width, DType.float32]()
    var c = MyArray[simd_width, DType.float32]()
    var d = MyArray[simd_width, DType.float32]()
    var pixel = MyArray[simd_width, DType.float32]()
    var idx = MyArray[simd_width, DType.int32]()
    # var width_index_shape = TensorShape(1, new_width)
    # var width_index = Tensor[DType.int32].rand(width_index_shape)
    var width_index = MyArray[4096, DType.int32]()
    for _i in range(4096):
        width_index[_i] = _i

    #######################################################################
    # print(org)
    # print(width_index)
    
    # for _i in range(org.num_elements()):
    #     print(_i, org[_i])
    
    # for h in range(height):
    #     for w in range(width):
    #         for c in range(channel):
    #             print(h*width*channel+w*channel+c, Index(h,w,c), org[h,w,c], org[Index(h,w,c)])
    ###################################################################################

    for i in range(new_height):
        @parameter
        fn vec_in_width[simd_width:Int](j:Int):
            for k in range(channel):

                """
                index = i*width*channel+j*channel+k
                """
                x.store[simd_width=simd_width](0,
                (width_index.load[simd_width=simd_width](j).cast[DType.float32]()+0.5) * (scale_x) - 0.5
                )
                y = (i+0.5) * (scale_y) - 0.5
                
                x_int.store[simd_width=simd_width](0, x.load[simd_width](0).cast[DType.int32]())
                y_int = int(y)
                # # Prevent crossing
                x_int.store[simd_width=simd_width](0, min(x_int.load[simd_width](0),width-2))
                y_int = min(y_int, height-2)

                x_diff.store[simd_width=simd_width](0,
                    x.load[simd_width](0) - x_int.load[simd_width](0).cast[DType.float32]()
                )
                y_diff = y - y_int

                a.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+x_int.load[simd_width](0)*channel+y_int*width*channel
                ).cast[DType.float32]())
                
                b.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+(x_int.load[simd_width](0)+1)*channel+y_int*width*channel
                ).cast[DType.float32]())

                c.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+x_int.load[simd_width](0)*channel+(y_int+1)*width*channel
                ).cast[DType.float32]())

                d.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+(x_int.load[simd_width](0)+1)*channel+(y_int+1)*width*channel
                ).cast[DType.float32]())
                
                pixel.store[simd_width=simd_width](0,
                    a.load[simd_width](0)*(1-x_diff.load[simd_width](0)) * (1-y_diff) + \
                    b.load[simd_width](0)*(x_diff.load[simd_width](0)) * (1-y_diff) + \
                    c.load[simd_width](0)*(1-x_diff.load[simd_width](0)) * (y_diff) + \
                    d.load[simd_width](0)*x_diff.load[simd_width](0) * y_diff
                )
                idx.store[simd_width=simd_width](0,
                k+width_index.load[simd_width=simd_width](j)*channel+i*new_width*channel
                )
                res_ptr.scatter[width=simd_width](
                    idx.load[simd_width](0), 
                    pixel.load[simd_width](0).cast[DType.uint8]()
                )
                # print(i,j,k, simd_width)
                # # print(width_index)
                # print(width_index.load[simd_width=simd_width](j),width_index.load[simd_width=simd_width](j).cast[DType.float32]())
                # print(x, y)
                # print(x_int, y_int)
                # print(x_diff, y_diff)
                # print(a,'\n',b,'\n',c,'\n',d)
                # print(pixel, idx)

        vectorize[vec_in_width, simd_width](new_width)


fn bilinear_vec_parallel(org:TUI8, inout res:TUI8):
    var height = org.dim(0)
    var width = org.dim(1)
    var channel = org.dim(2)

    var new_height = res.dim(0)
    var new_width = res.dim(1)

    var scale_x = width/new_width
    var scale_y = height/new_height

    var org_ptr = org.unsafe_ptr()
    var res_ptr = res.unsafe_ptr()

    @parameter
    fn parallel_in_height(i:Int):
        var x = MyArray[simd_width, DType.float32]()
        var y:Float32 = 0
        var x_int = MyArray[simd_width, DType.int32]()
        var y_int:Int = 0
        var x_diff = MyArray[simd_width, DType.float32]()
        var y_diff:Float32 =0
        var a = MyArray[simd_width, DType.float32]()
        var b = MyArray[simd_width, DType.float32]()
        var c = MyArray[simd_width, DType.float32]()
        var d = MyArray[simd_width, DType.float32]()
        var pixel = MyArray[simd_width, DType.float32]()
        var idx = MyArray[simd_width, DType.int32]()
        var width_index = MyArray[4096, DType.int32]()
        for _i in range(4096):
            width_index[_i] = _i
    
        @parameter
        fn vec_in_width[simd_width:Int](j:Int):
            for k in range(channel):

                """
                index = i*width*channel+j*channel+k
                """
                x.store[simd_width=simd_width](0,
                (width_index.load[simd_width=simd_width](j).cast[DType.float32]()+0.5) * (scale_x) - 0.5
                )
                y = (i+0.5) * (scale_y) - 0.5
                
                x_int.store[simd_width=simd_width](0, x.load[simd_width](0).cast[DType.int32]())
                y_int = int(y)
                # # Prevent crossing
                x_int.store[simd_width=simd_width](0, min(x_int.load[simd_width](0),width-2))
                y_int = min(y_int, height-2)

                x_diff.store[simd_width=simd_width](0,
                    x.load[simd_width](0) - x_int.load[simd_width](0).cast[DType.float32]()
                )
                y_diff = y - y_int

                a.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+x_int.load[simd_width](0)*channel+y_int*width*channel
                ).cast[DType.float32]())
                
                b.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+(x_int.load[simd_width](0)+1)*channel+y_int*width*channel
                ).cast[DType.float32]())

                c.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+x_int.load[simd_width](0)*channel+(y_int+1)*width*channel
                ).cast[DType.float32]())

                d.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+(x_int.load[simd_width](0)+1)*channel+(y_int+1)*width*channel
                ).cast[DType.float32]())
                
                pixel.store[simd_width=simd_width](0,
                    a.load[simd_width](0)*(1-x_diff.load[simd_width](0)) * (1-y_diff) + \
                    b.load[simd_width](0)*(x_diff.load[simd_width](0)) * (1-y_diff) + \
                    c.load[simd_width](0)*(1-x_diff.load[simd_width](0)) * (y_diff) + \
                    d.load[simd_width](0)*x_diff.load[simd_width](0) * y_diff
                )
                idx.store[simd_width=simd_width](0,
                k+width_index.load[simd_width=simd_width](j)*channel+i*new_width*channel
                )
                res_ptr.scatter[width=simd_width](
                    idx.load[simd_width](0), 
                    pixel.load[simd_width](0).cast[DType.uint8]()
                )
        vectorize[vec_in_width, simd_width](new_width)
    parallelize[parallel_in_height](new_height)


fn bilinear_vec_parallel_matrix(org:Matrix, inout res:Matrix):
    var height = org.rows
    var width = org.cols
    var channel = org.channels

    var new_height = res.rows
    var new_width = res.cols

    var scale_x = width/new_width
    var scale_y = height/new_height

    var org_ptr = org.data
    var res_ptr = res.data

    # for _i in range(width*height*channel):
    #     print(_i, org[_i])
    
    # for h in range(height):
    #     for w in range(width):
    #         for c in range(channel):
    #             print(Index(h,w,c), h*width*channel+w*channel+c, org[h,w,c])
    # ###################################################################################

    # @parameter
    # fn parallel_in_height(i:Int):
    var x = MyArray[simd_width, DType.float32]()
    var y:Float32 = 0
    var x_int = MyArray[simd_width, DType.int32]()
    var y_int:Int = 0
    var x_diff = MyArray[simd_width, DType.float32]()
    var y_diff:Float32 =0
    var a = MyArray[simd_width, DType.float32]()
    var b = MyArray[simd_width, DType.float32]()
    var c = MyArray[simd_width, DType.float32]()
    var d = MyArray[simd_width, DType.float32]()
    var pixel = MyArray[simd_width, DType.float32]()
    var idx = MyArray[simd_width, DType.int32]()
    var width_index = MyArray[4096, DType.int32]()
    for _i in range(4096):
        width_index[_i] = _i
    
    print("starting ...")
    for i in range(new_height):
        print("iere")
        @parameter
        fn vec_in_width[simd_width:Int](j:Int):
            print("jere")

            for k in range(channel):
                print(i,j,k, simd_width)

                """
                index = i*width*channel+j*channel+k
                """
                x.store[simd_width=simd_width](0,
                (width_index.load[simd_width=simd_width](j).cast[DType.float32]()+0.5) * (scale_x) - 0.5
                )
                y = (i+0.5) * (scale_y) - 0.5
                print(x, y)
                
                x_int.store[simd_width=simd_width](0, x.load[simd_width](0).cast[DType.int32]())
                y_int = int(y)
                # # Prevent crossing
                x_int.store[simd_width=simd_width](0, min(x_int.load[simd_width](0),width-2))
                y_int = min(y_int, height-2)
                print(x_int, y_int)

                x_diff.store[simd_width=simd_width](0,
                    x.load[simd_width](0) - x_int.load[simd_width](0).cast[DType.float32]()
                )
                y_diff = y - y_int
                print(x_diff, y_diff)

                a.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+x_int.load[simd_width](0)*channel+y_int*width*channel
                ).cast[DType.float32]())
                
                b.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+(x_int.load[simd_width](0)+1)*channel+y_int*width*channel
                ).cast[DType.float32]())

                c.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+x_int.load[simd_width](0)*channel+(y_int+1)*width*channel
                ).cast[DType.float32]())

                d.store[simd_width=simd_width](0, org_ptr.gather[width=simd_width](
                    k+(x_int.load[simd_width](0)+1)*channel+(y_int+1)*width*channel
                ).cast[DType.float32]())
                print(a,'\n',b,'\n',c,'\n',d)
                
                pixel.store[simd_width=simd_width](0,
                    a.load[simd_width](0)*(1-x_diff.load[simd_width](0)) * (1-y_diff) + \
                    b.load[simd_width](0)*(x_diff.load[simd_width](0)) * (1-y_diff) + \
                    c.load[simd_width](0)*(1-x_diff.load[simd_width](0)) * (y_diff) + \
                    d.load[simd_width](0)*x_diff.load[simd_width](0) * y_diff
                )
                idx.store[simd_width=simd_width](0,
                k+width_index.load[simd_width=simd_width](j)*channel+i*new_width*channel
                )
                print(pixel, idx)

                res_ptr.scatter[width=simd_width](
                    idx.load[simd_width](0), 
                    pixel.load[simd_width](0).cast[DType.uint8]()
                )
                # print(width_index)
                # print(width_index.load[simd_width=simd_width](j),width_index.load[simd_width=simd_width](j).cast[DType.float32]())
        vectorize[vec_in_width, simd_width](new_width)
    # parallelize[parallel_in_height](new_height)


def main():
    random.seed(42)
    # var orig_shape = TensorShape(2160,3840,3)
    # var resize_shape = TensorShape(480,854,3)
    # var py_time = 10.7087329153902828
    # var cv2_time = 0.00047873249957337973

    var orig_shape = TensorShape(640,640,3)
    var resize_shape = TensorShape(256,256,3)
    var py_time = 1.7087329153902828
    var cv2_time = 0.0003149523865431547

    var org_spec = TensorSpec(UI8, orig_shape)
    var resize_spec = TensorSpec(UI8, resize_shape)
    
    # var org = TUI8.rand(org_spec.shape)
    # # var org = TUI8(org_spec).__rmul__(0).__radd__(1)
    # var res = TUI8(resize_spec).__rmul__(0)

    var org = Matrix[640,640,3].rand()
    var res = Matrix[256,256,3].rand()
    # var org = Matrix[3,3,3].rand()
    # var res = Matrix[2,2,3].rand()
    bilinear_vec_parallel_matrix(org, res)
    # test_images(org, res, bilinear_vec_parallel)
    
    # counter = int(1e3)
    # t1 = now()
    # for _ in range(counter):
    #     bilinear_vec_parallel(org, res)
    # t2 = now()
    # dt = (t2-t1)/counter/1e9

    # print("resize: ",orig_shape, "->", resize_shape, ": ", dt, "s")
    # print("Iterations: ", counter)
    # print("speedup over python: ", py_time/dt)
    # print("speedup over opencv: ", cv2_time/dt)
    # print("speedup in opencv: ", dt/cv2_time)

    # @parameter
    # fn bench():
    #     bilinear_vec_parallel_matrix(org, res)
    
    # bench_result = run[bench](num_warmup=5, min_runtime_secs=5)
    # bench_result.print()
    # print("resize: ",orig_shape, "->", resize_shape, ": ", bench_result.mean(), "s")
    # print("speedup over python: ", py_time/bench_result.mean())
    # print("speedup over opencv: ", cv2_time/bench_result.mean())
    # print("speedup in opencv: ", bench_result.mean()/cv2_time)
    # print("worst speedup in opencv: ", bench_result.min()/cv2_time)


