from time import now
import random
from random import rand
from algorithm import vectorize, parallelize
from tensor import Tensor, TensorSpec, TensorShape
from utils.index import Index
from testing import assert_true
from benchmark import run

alias DF64 = DType.float32
alias TF64 = Tensor[DF64]
alias simd_width = 4*simdwidthof[DF64]()
alias type = DType.float32


fn matmul_mojo_loops(A:TF64, B:TF64, inout C:TF64):
    var M = A.dim(0)
    var N = A.dim(1)
    var K = B.dim(1)
    
    # C row += A element * B row
    for m in range(M):
        for n in range(N):
            for k in range(K):
                C[Index(m,k)] +=  A[Index(m,n)]*B[Index(n,k)]

    # or C Element = Sum( A row * B Coloumn)
    # for m in range(M):
    #     for k in range(K):
    #         for n in range(N):
    #             C[Index(m,k)] +=  A[Index(m,n)]*B[Index(n,k)]

fn matmul_mojo_v1_vec(A:TF64, B:TF64, inout C:TF64):
    var M = A.dim(0)
    var N = A.dim(1)
    var K = B.dim(1)
    # C row += A element * B row
    for m in range(M):
        for n in range(N):
            @parameter
            fn vec_in_k[simd_width: Int](k:Int):
                C.store[width=simd_width](
                    Index(m,k),
                    C.load[width=simd_width](m,k) +  A[Index(m,n)] * B.load[width=simd_width](n,k)
                )
            vectorize[vec_in_k, simd_width](K)

fn matmul_mojo_v1_vec_parallel(A:TF64, B:TF64, inout C:TF64):
    var M = A.dim(0)
    var N = A.dim(1)
    var K = B.dim(1)
    var num_workers = 20
    # C row += A element * B row
    @parameter
    fn parallel_in_m(m:Int):
        for n in range(N):
            @parameter
            fn vec_in_k[simd_width: Int](k:Int):
                C.store[width=simd_width](
                    Index(m,k),
                    C.load[width=simd_width](m,k) +  A[Index(m,n)] * B.load[width=simd_width](n,k)
                )
            vectorize[vec_in_k, simd_width](K)
    parallelize[parallel_in_m](M)

struct Matrix[rows: Int, cols: Int]:
    var data: DTypePointer[type]

    # Initialize zeroeing all values
    fn __init__(inout self):
        self.data = DTypePointer[type].alloc(rows * cols)
        memset_zero(self.data, rows * cols)

    # Initialize taking a pointer, don't set any elements
    fn __init__(inout self, data: DTypePointer[type]):
        self.data = data

    ## Initialize with random values
    @staticmethod
    fn rand() -> Self:
        var data = DTypePointer[type].alloc(rows * cols)
        rand(data, rows * cols)
        return Self(data)

    fn __getitem__(self, y: Int, x: Int) -> Scalar[type]:
        return self.load[1](y, x)

    fn __setitem__(inout self, y: Int, x: Int, val: Scalar[type]):
        self.store[1](y, x, val)

    fn load[width: Int](self, y: Int, x: Int) -> SIMD[type, width]:
        return self.data.load[width=width](y * self.cols + x)

    fn store[width: Int](self, y: Int, x: Int, val: SIMD[type, width]):
        return self.data.store[width=width](y * self.cols + x, val)
    
    fn shape(self) -> String:
        return String(self.rows)+'x'+String(self.cols)
    
    fn __del__(owned self):
        self.data.free()

fn matmul_mojo_v1_vec_parallel_matrix(A: Matrix, B: Matrix, inout C:Matrix):
    var M = A.rows
    var N = A.cols
    var K = B.cols
    # C row += A element * B row
    @parameter
    fn parallel_in_m(m:Int):
        for n in range(N):
            @parameter
            fn vec_in_k[simd_width: Int](k:Int):
                C.store[width=simd_width](
                    m,k,
                    C.load[width=simd_width](m,k) +  A[m,n] * B.load[width=simd_width](n,k)
                )
            vectorize[vec_in_k, simd_width](K)
    parallelize[parallel_in_m](M)


fn matmul_mojo_v2_vec(A:TF64, B:TF64, inout C:TF64):
    var M = A.dim(0)
    var N = A.dim(1)
    var K = B.dim(1)
    # C Element = Sum( A row * B Coloumn)
    var B_ptr = B.unsafe_ptr()
    for m in range(M):
        for k in range(K):
            @parameter
            fn vec_in_n[simd_width: Int](n:Int):
                C[Index(m,k)] +=  (
                    A.load[width=simd_width](n,k) *\
                    B_ptr.offset(n+k).simd_strided_load[width=simd_width](K)
                ).reduce_add()
            vectorize[vec_in_n, simd_width](N)

fn matmul_mojo_v2_vec_parallel(A:TF64, B:TF64, inout C:TF64):
    var M = A.dim(0)
    var N = A.dim(1)
    var K = B.dim(1)
    # C Element = Sum( A row * B Coloumn)
    var B_ptr = B.unsafe_ptr()
    @parameter
    fn parallel_in_m(m:Int):
    # for m in range(M):
        for k in range(K):
            @parameter
            fn vec_in_n[simd_width: Int](n:Int):
                C[Index(m,k)] +=  (
                    A.load[width=simd_width](n,k) *\
                    B_ptr.offset(n+k).simd_strided_load[width=simd_width](K)
                ).reduce_add()
            vectorize[vec_in_n, simd_width](N)
    parallelize[parallel_in_m](M)

def test_matmul():
    var M = 512
    var N = 256
    var K = 512
    var a_spec = TensorSpec(DF64, M, N)
    var b_spec = TensorSpec(DF64, N, K)
    var c_spec = TensorSpec(DF64, M, K)

    var A = TF64(a_spec).__rmul__(0).__radd__(1)
    var B = TF64(b_spec).__rmul__(0).__radd__(1)
    var C = TF64(c_spec).__rmul__(0)

    ##### TESTING ######
    var D = TF64(c_spec).__rmul__(0)
    var E = TF64(c_spec).__rmul__(0)

    matmul_mojo_loops(A,B,C)
    matmul_mojo_loops(A,B,D)
    matmul_mojo_loops(A,B,E)
    print(C==D)
    print(C==E)

    # print(B.load[simd_width,width=simd_width]((0,0)))
    # print(B.load[width=simd_width](0,0))
    # print(B)
    # var B_ptr = B.unsafe_ptr()
    # print(B_ptr.offset(K-1).simd_strided_load[width=256](K))
    # print(B,'\n\n\n\n')
    # print(simd_width,'\n\n\n\n')
    # print(SIMD[DType.float16,4](1,2,3,4))
    # @parameter
    # fn vecprint[simd_width: Int](idx:Int):
    #     print(idx)
    #     var x = B.load[simd_width,width=simd_width](idx)
    #     print(x)
    # vectorize[vecprint, 4](512)

def main():
    random.seed(42)
    # var M = 512 
    # var N = 256 
    # var K = 512
    # var py_time = 77.04722635447979
    # var np_time = 0.0010287985601928084
    
    var M = 2048
    var N = 1024
    var K = 2048
    var py_time = 0
    var np_time = 0.019497849141806363
    
    var gflops = (2*M*N*K)/ 1e9

    # var a_spec = TensorSpec(DF64, M, N)
    # var b_spec = TensorSpec(DF64, N, K)
    # var c_spec = TensorSpec(DF64, M, K)

    # var A = TF64.rand(a_spec.shape)
    # var B = TF64.rand(b_spec.shape)
    
    # var C = TF64(c_spec).__rmul__(0)


    var A = Matrix[2048, 1024].rand()
    var B = Matrix[1024, 2048].rand()
    var C = Matrix[2048, 2048]()

    # counter = int(1e3)
    # t1 = now()
    # for _ in range(counter):
    #     matmul_mojo_v2_p(A,B,C)
    # t2 = now()
    # dt = (t2-t1)/counter/1e9

    # var gflops_per_sec = (gflops/dt)
    # print("Matmul : ", A.shape(), "@", B.shape())
    # print("Iterations : ", counter)
    # print("Total GFLOPS : ", gflops)
    # print("Total time in sec : ", dt)
    # print("GFLOP/sec : ",gflops_per_sec)
    # print("speedup over python: ", py_time/dt)
    # print("speedup over numpy: ", np_time/dt)
    # print("speedup in opencv: ", dt/np_time)

    @parameter
    fn bench():
        # matmul_mojo_loops(A,B,C)
        matmul_mojo_v1_vec_parallel_matrix(A,B,C)
    
    bench_result = run[bench](num_warmup=5, min_runtime_secs=10)
    bench_result.print()
    print("Matmul : ", A.shape(), "@", B.shape())
    print("Total GFLOPS: ", gflops)
    print("GFLOP/sec: ", gflops/bench_result.mean())
    print("speedup over python: ", py_time/bench_result.mean())
    print("speedup over numpy: ", np_time/bench_result.mean())
    print("speedup in numpy: ", bench_result.mean()/np_time)
    print("worst speedup in numpy: ", bench_result.min()/np_time)
















