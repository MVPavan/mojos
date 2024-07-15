from timeit import timeit
import numpy as np
from time import perf_counter_ns

class Matrix:
    def __init__(self, value, rows, cols):
        self.value = value
        self.rows = rows
        self.cols = cols

    def __getitem__(self, idxs):
        return self.value[idxs[0]][idxs[1]]

    def __setitem__(self, idxs, value):
        self.value[idxs[0]][idxs[1]] = value


def matmul_python(C, A, B):
    for m in range(C.rows):
        for k in range(C.cols):
            for n in range(A.cols):
                C[m, k] += A[m, n] * B[n, k]


def benchmark_matmul_python(M, N, K):
    A = Matrix(list(np.random.rand(M, N)), M, N)
    B = Matrix(list(np.random.rand(N, K)), N, K)
    C = Matrix(list(np.zeros((M, K))), M, K)
    # print(A.value,B.value,C.value)
    # matmul_python(C, A, B)
    # print(C.value)
    dt = timeit(lambda: matmul_python(C, A, B), number=2)/2
    gflops = (2*M*N*K)/ 1e9
    gflops_per_sec = (gflops/dt)
    print(gflops, "GFLOPS")
    print(dt, "s")
    print(gflops_per_sec, "GFLOP/s")
    return gflops

def benchmark_matmul_numpy(M, N, K):
    A = np.random.rand(M, N)
    B = np.random.rand(N, K)
    # dt = timeit(lambda: np.matmul(A,B), number=2)/2

    # counter = int(2*1e4)
    # dt = 0
    # for _ in range(counter):
    #     t1 = perf_counter_ns()
    #     C = np.matmul(A,B)
    #     t2 = perf_counter_ns()
    #     dt += (t2-t1)
    
    # print(dt/1e9)
    # dt = (dt/counter)/1e9

    # gflops = (2*M*N*K)/ 1e9
    # gflops_per_sec = (gflops/dt)
    # print(gflops, "GFLOPS")
    # print(dt, "s")
    # print(gflops_per_sec, "GFLOP/s")

    A = A.astype(np.float32)
    B = B.astype(np.float32)
    counter = int(1e4)
    dt = timeit(lambda: np.matmul(A,B), number=counter) / counter

    gflops = (2*M*N*K)/ 1e9
    gflops_per_sec = (gflops/dt)
    print(gflops, "GFLOPS")
    print(dt, "s")
    print(gflops_per_sec, "GFLOP/s")
    return gflops

if __name__ == "__main__":
    # benchmark_matmul_python(512, 256, 512)
    benchmark_matmul_numpy(512, 256, 512)
    # benchmark_matmul_numpy(2048, 1024, 2048)