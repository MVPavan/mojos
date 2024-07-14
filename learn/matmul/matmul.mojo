from tensor import Tensor, TensorSpec, TensorShape
from utils.index import Index
from testing import assert_true
from benchmark import run
from time import now
from algorithm import vectorize

alias TF64 = Tensor[DType.float64]
alias smid_width = 4*simdwidthof[DType.int32]()

fn matmul_mojo_v1(A:TF64, B:TF64, inout C:TF64):
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

fn matmul_mojo_v2(A:TF64, B:TF64, inout C:TF64):
    var M = A.dim(0)
    var N = A.dim(1)
    var K = B.dim(1)

    # C row += A element * B row
    for m in range(M):
        for n in range(N):
            @parameter
            fn vec_in_k[smid_width: Int](k:Int):
                C.store[width=smid_width](
                    Index(m,k), 
                    C.load[width=smid_width](m,k) +  A[Index(m,n)] * B.load[width=smid_width](n,k)
                )
            vectorize[vec_in_k, smid_width](K)

fn matmul_mojo_v3(A:TF64, B:TF64, inout C:TF64):
    var M = A.dim(0)
    var N = A.dim(1)
    var K = B.dim(1)

    # C Element = Sum( A row * B Coloumn)
    var B_ptr = B.unsafe_ptr()
    for m in range(M):
        for k in range(K):
            @parameter
            fn vec_in_n[smid_width: Int](n:Int):
                C[Index(m,k)] +=  (
                    A.load[width=smid_width](n,k) *\
                    B_ptr.offset(n+k).simd_strided_load[width=smid_width](K)
                ).reduce_add()
            vectorize[vec_in_n, smid_width](N)

def main():
    var M = 512
    var N = 256
    var K = 512
    var a_spec = TensorSpec(DType.float64, M, N)
    var b_spec = TensorSpec(DType.float64, N, K)
    var c_spec = TensorSpec(DType.float64, M, K)

    # var A = TF64(a_spec).__rmul__(0).__radd__(1)
    # var B = TF64(b_spec).__rmul__(0).__radd__(1)
    
    var A = TF64.rand(a_spec.shape)
    var B = TF64.rand(b_spec.shape)
    
    var C = TF64(c_spec).__rmul__(0)

    var D = TF64(c_spec).__rmul__(0)
    var E = TF64(c_spec).__rmul__(0)

    matmul_mojo_v1(A,B,C)
    matmul_mojo_v1(A,B,D)
    matmul_mojo_v1(A,B,E)
    print(C==D)
    print(C==E)


    # print(B.load[smid_width,width=smid_width]((0,0)))
    # print(B.load[width=smid_width](0,0))
    # print(B)
    # var B_ptr = B.unsafe_ptr()
    # print(B_ptr.offset(K-1).simd_strided_load[width=256](K))
    # print(B,'\n\n\n\n')
    # print(smid_width,'\n\n\n\n')
    # print(SIMD[DType.float16,4](1,2,3,4))
    # @parameter
    # fn vecprint[smid_width: Int](idx:Int):
    #     print(idx)
    #     var x = B.load[smid_width,width=smid_width](idx)
    #     print(x)
    # vectorize[vecprint, 4](512)
    
    t1 = now()
    matmul_mojo_v2(A,B,C)
    t2 = now()
    dt = (t2-t1)/1e9

    gflops = (2*M*N*K)/ 1e9
    gflops_per_sec = (gflops/dt)
    print(gflops, "GFLOPS")
    print(dt, "s")
    print(gflops_per_sec, "GFLOP/s")
    print("speedup over python: ", 79.75228386605158/dt)
    print("speedup over numpy: ", 0.000825096859/dt)
    # print(C)

    @parameter
    fn bench():
        matmul_mojo_v2(A,B,C)
    
    bench_result = run[bench](min_runtime_secs=10)
    bench_result.print()
    print("speedup over python: ", 79.75228386605158/bench_result.mean())
    print("speedup over numpy: ", 0.000825096859/bench_result.mean())
















