# Matrix Multiplication

Test computation: `Dim: (512, 256, 512)`

## Python
```
0.134217728 GFLOPS
79.75228386605158 s
0.00168293271983817 GFLOP/s
```

## Numpy
```
0.134217728 GFLOPS
0.000825096859 s
162.66905701552307 GFLOP/s
```

## Mojo

### Using for loops, same as python
```
0.13421772800000001 GFLOPS
0.85494461899999996 s
0.15698996755718514 GFLOP/s
speedup over python:  93.283567255309649
speedup over numpy:  0.00096508807782788098
---------------------
Benchmark Report (s)
---------------------
Mean: 0.677032453875
Total: 10.832519262
Iters: 16
Warmup Mean: 0.72565643349999998
Warmup Total: 1.451312867
Warmup Iters: 2
Fastest Mean: 0.677032453875
Slowest Mean: 0.677032453875

speedup over python:  117.7968403280948
speedup over numpy:  0.0012186961707338435
```

### Using SMID vectorization for inner loop
1. C row += A element * B row
```
0.13421772800000001 GFLOPS
0.022948112999999999 s
5.8487479123011124 GFLOP/s
speedup over python:  3475.3307980508721
speedup over numpy:  0.03595488914491575
---------------------
Benchmark Report (s)
---------------------
Mean: 0.021005832629173989
Total: 11.952318765999999
Iters: 569
Warmup Mean: 0.0239829285
Warmup Total: 0.047965857000000001
Warmup Iters: 2
Fastest Mean: 0.021005832629173989
Slowest Mean: 0.021005832629173989

speedup over python:  3796.6732989811353
speedup over numpy:  0.039279416986978309
```

2. C Element = Sum( A row * B Coloumn)
```
0.13421772800000001 GFLOPS
0.029753023 s
4.5110618843671784 GFLOP/s
speedup over python:  2680.4766650451479
speedup over numpy:  0.02773153030534074
---------------------
Benchmark Report (s)
---------------------
Mean: 0.024867913021367521
Total: 11.638183293999999
Iters: 468
Warmup Mean: 0.030599864000000001
Warmup Total: 0.061199728000000002
Warmup Iters: 2
Fastest Mean: 0.024867913021367521
Slowest Mean: 0.024867913021367521

speedup over python:  3207.0356606734622
speedup over numpy:  0.033179175843628027
```