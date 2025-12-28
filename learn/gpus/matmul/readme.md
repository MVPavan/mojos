# MatMul

**Table of Contents**
- [MatMul](#matmul)
  - [CPU](#cpu)
  - [Python (Using Lists) 😀](#python-using-lists-)
  - [Numpy](#numpy)
  - [Mojo](#mojo)
    - [Just for loops](#just-for-loops)
    - [SIMD Vectorization](#simd-vectorization)
    - [SIMD Vectorization and Parallelization](#simd-vectorization-and-parallelization)
    - [SIMD Vectorize, Parallel using DTypePointer](#simd-vectorize-parallel-using-dtypepointer)


## CPU

- Physical cores: 20
- Physical + Logical cores: 40
```
Architecture:                    x86_64
CPU op-mode(s):                  32-bit, 64-bit
Byte Order:                      Little Endian
Address sizes:                   46 bits physical, 48 bits virtual
CPU(s):                          40
On-line CPU(s) list:             0-39
Thread(s) per core:              2
Core(s) per socket:              10
Socket(s):                       2
NUMA node(s):                    2
Vendor ID:                       GenuineIntel
CPU family:                      6
Model:                           85
Model name:                      Intel(R) Xeon(R) Silver 4210R CPU @ 2.40GHz
Stepping:                        7
CPU MHz:                         2400.000
CPU max MHz:                     3200.0000
CPU min MHz:                     1000.0000
```

> Mojo is using only physical cores where as numpy utilizing all 40 cores
## Python (Using Lists) 😀
- `512x256 @ 256x512`
```
Matmul : 512x256 @ 256x512
Iterations :  2
Total GFLOPS :  0.134217728
Total time in sec :  77.04722635447979
GFLOP/sec :  0.001742018945399663
```

- `2048x1024 @ 1024x2048` - My system got tired!

> All the operations from here are in FP32
## Numpy

- `512x256 @ 256x512`
```
Matmul : 512x256 @ 256x512
Iterations : 10000
Total GFLOPS :  0.134217728
Total time in sec :  0.0010287985601928084
GFLOP/sec :  130.46064914286632
speedup over python: 74890
```

- `2048x1024 @ 1024x2048`
```
Matmul : 2048x1024 @ 1024x2048
Iterations : 10000
Total GFLOPS :  8.589934592
Total time in sec :  0.019497849141806363
GFLOP/sec :  440.55805999554434

Matmul : 2048x1024 @ 1024x2048
Iterations :  200
Total GFLOPS :  8.589934592
Total time in sec :  0.018091672335285695
GFLOP/sec :  474.80047354419173
```


## Mojo

### Just for loops

- `512x256 @ 256x512`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 0.64016959076470581
Total: 10.882883043
Iters: 17
Warmup Mean: 0.69197315560000006
Warmup Total: 3.4598657780000002
Warmup Iters: 5
Fastest Mean: 0.64016959076470592
Slowest Mean: 0.64016959076470592

Matmul :  512x256 @ 256x512
Total GFLOPS:  0.13421772800000001
GFLOP/sec:  0.20965964321996622
speedup over python:  120.35439899987139
speedup over numpy:  0.0016070718994381961
speedup in numpy:  622.24969545518297
worst speedup in numpy:  622.24969545518309
```
- `2048x1024 @ 1024x2048`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 40.9093318165
Total: 245.455990899
Iters: 6
Warmup Mean: 40.8972278066
Warmup Total: 204.486139033
Warmup Iters: 5
Fastest Mean: 40.9093318165
Slowest Mean: 40.9093318165

Matmul :  2048x1024 @ 1024x2048

GFLOP/sec:  0.2099749424050826
speedup over python:  1.8833655533675633
speedup over numpy:  0.00047661128344174706
speedup in numpy:  2098.1458785002164
worst speedup in numpy:  2098.1458785002164
```



### SIMD Vectorization

- `512x256 @ 256x512`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 0.012332463752118645
Total: 11.641845782000001
Iters: 944
Warmup Mean: 0.0146965052
Warmup Total: 0.073482526000000006
Warmup Iters: 5
Fastest Mean: 0.012332463752118644
Slowest Mean: 0.012332463752118644

Matmul :  512x256 @ 256x512
Total GFLOPS:  0.13421772800000001
GFLOP/sec:  10.883285829803651
speedup over python:  6247.5128979190004
speedup over numpy:  0.083421981274104037
speedup in numpy:  11.987248261513317
worst speedup in numpy:  11.987248261513315
```
- `2048x1024 @ 1024x2048`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 1.04279860254
Total: 52.139930127
Iters: 50
Warmup Mean: 1.1388049650000001
Warmup Total: 5.6940248249999996
Warmup Iters: 5
Fastest Mean: 1.04279860254
Slowest Mean: 1.04279860254

Matmul :  2048x1024 @ 1024x2048
Total GFLOPS:  8.5899345920000005
GFLOP/sec:  8.2373859833308565
speedup over python:  0.0
speedup over numpy:  0.018697617252568632
speedup in numpy:  53.482750582169636
worst speedup in numpy:  53.482750582169636
```


### SIMD Vectorization and Parallelization

- `512x256 @ 256x512`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 0.0016582828104565537
Total: 11.259740282999999
Iters: 6790
Warmup Mean: 0.0045278230000000003
Warmup Total: 0.022639115000000001
Warmup Iters: 5
Fastest Mean: 0.0016582828104565537
Slowest Mean: 0.0016582828104565537

Matmul :  512x256 @ 256x512
Total GFLOPS:  0.13421772800000001
GFLOP/sec:  80.937779221776751
speedup over python:  46462.054523297731
speedup over numpy:  0.62039994246190278
speedup in numpy:  1.6118634634809101
worst speedup in numpy:  1.6118634634809101
```
- `2048x1024 @ 1024x2048`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 0.12600896040860216
Total: 11.718833318
Iters: 93
Warmup Mean: 0.1245288464
Warmup Total: 0.62264423199999996
Warmup Iters: 5
Fastest Mean: 0.12600896040860216
Slowest Mean: 0.12600896040860216

Matmul :  2048x1024 @ 1024x2048
Total GFLOPS:  8.5899345920000005
GFLOP/sec:  68.169236252294311
speedup over python:  0.0
speedup over numpy:  0.15473383066237342
speedup in numpy:  6.4627108093897254
worst speedup in numpy:  6.4627108093897254
```


### SIMD Vectorize, Parallel using DTypePointer
Earlier used Tensor

- `512x256 @ 256x512`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 0.00063344754129086812
Total: 13.484831259
Iters: 21288
Warmup Mean: 0.0057730554000000002
Warmup Total: 0.028865277000000002
Warmup Iters: 5
Fastest Mean: 0.00063344754129086812
Slowest Mean: 0.00063344754129086812

Matmul :  512x256 @ 256x512
Total GFLOPS:  0.13421772800000001
GFLOP/sec:  211.8845196343884
speedup over python:  121631.58167362913
speedup over numpy:  1.6241259033009681
speedup in numpy:  0.61571581240564033
worst speedup in numpy:  0.61571581240564033
```
- `2048x1024 @ 1024x2048`
```
---------------------
Benchmark Report (s)
---------------------
Mean: 0.054670777668181819
Total: 12.027571087
Iters: 220
Warmup Mean: 0.057961355399999998
Warmup Total: 0.28980677700000002
Warmup Iters: 5
Fastest Mean: 0.054670777668181819
Slowest Mean: 0.054670777668181819

Matmul :  2048x1024 @ 1024x2048
Total GFLOPS:  8.5899345920000005
GFLOP/sec:  157.12113414840465
speedup over python:  0.0
speedup over numpy:  0.35664115224675202
speedup in numpy:  2.8039388996481325
worst speedup in numpy:  2.8039388996481325
```