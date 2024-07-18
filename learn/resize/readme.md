# Resize
## Bilinear

### 1. Python

```
Bilinear resize from (640, 640, 3) to (256, 256):
Error rate: 0.4068756103515625
Opencv: 0.0003149523865431547 s
Python: 1.7087329153902828 s
cv2 resize is 5425.369003057714 times faster than python

Bilinear resize from (2160, 3840, 3) to (480, 854):
Error rate: 0.37517483086130626
Opencv: 0.00047873249957337973 s
Python: 10.476222490519286 s
cv2 resize is 21883.248995744227 times faster than python
```

### 2. **Mojo**
#### Error
Mojo numpy Error checking:
```
Mojo Org Tensor shape:  640x640x3
Mojo Result Tensor shape:  256x256x3
Numpy Org Tensor shape:  (640, 640, 3)
Numpy Result Tensor shape:  (256, 256, 3)
Average error:  0.4065704345703125

Mojo Org Tensor shape:  2160x3840x3
Mojo Result Tensor shape:  480x854x3
Numpy Org Tensor shape:  (2160, 3840, 3)
Numpy Result Tensor shape:  (480, 854, 3
Average error:  0.3744877049180328
```

> Conclusion: Algorithm implementation looks goods, error rates similar to python

#### Latency
using the best latencies from python:
- for `640x640x3 -> 256x256x3`:
```
    Opencv: 0.0003149523865431547 s
    Python: 1.7087329153902828 s
```
- for `2160x3840x3 -> 480x854x3`:
```
    Opencv: 0.00047873249957337973 s
    Python: 10.476222490519286 s
```

1. Pure For loops: 
- `640x640x3 -> 256x256x3`:
```
    ---------------------
    Benchmark Report (s)
    ---------------------
    Mean: 0.0077014453141175223
    Total: 145.21845284299999
    Iters: 18856
    Warmup Mean: 0.0112494864
    Warmup Total: 0.056247432
    Warmup Iters: 5
    Fastest Mean: 0.0077014453141175223
    Slowest Mean: 0.0077014453141175223
  
    resize:  640x640x3 -> 256x256x3 :  0.0077014453141175223 s
    speedup over python:  221.87171961839474
    speedup over opencv:  0.040895231180284479
    speedup in opencv:  24.452728866883096
    worst speedup in opencv:  24.452728866883096
```
    
- `2160x3840x3 -> 480x854x3`:
```
	---------------------
	Benchmark Report (s)
	---------------------
	Mean: 0.049159172993067587
	Total: 113.459371268
	Iters: 2308
	Warmup Mean: 0.062143362000000001
	Warmup Total: 0.31071681000000001
	Warmup Iters: 5
	Fastest Mean: 0.049159172993067594
	Slowest Mean: 0.049159172993067594
	
	resize:  2160x3840x3 -> 480x854x3 :  0.049159172993067587 s
	speedup over python:  217.83793874849002
	speedup over opencv:  0.0097384164628011635
	speedup in opencv:  102.68609930780876
	worst speedup in opencv:  102.68609930780877
```

2. SIMD Vectorization
- `640x640x3 -> 256x256x3`:
```
	Mojo Org Tensor shape:  640x640x3
	Mojo Result Tensor shape:  256x256x3
	Numpy Org Tensor shape:  (640, 640, 3)
	Numpy Result Tensor shape:  (256, 256, 3)
	Average error:  0.906005859375
	---------------------
	Benchmark Report (s)
	---------------------
	Mean: 0.00097360333796067309
	Total: 120.06963165400001
	Iters: 123325
	Warmup Mean: 0.0011944061999999999
	Warmup Total: 0.005972031
	Warmup Iters: 5
	Fastest Mean: 0.00097360333796067298
	Slowest Mean: 0.00097360333796067298
	
	resize:  640x640x3 -> 256x256x3 :  0.00097360333796067309 s
	speedup over python:  1755.0606584499035
	speedup over opencv:  0.32349148186247961
	speedup in opencv:  3.0912715050256341
	worst speedup in opencv:  3.0912715050256336
```
- `2160x3840x3 -> 480x854x3`
```
	Mojo Org Tensor shape:  2160x3840x3
	Mojo Result Tensor shape:  480x854x3
	Numpy Org Tensor shape:  (2160, 3840, 3)
	Numpy Result Tensor shape:  (480, 854, 3)
	Average error:  0.3744877049180328
	---------------------
	Benchmark Report (s)
	---------------------
	Mean: 0.0060707756540178568
	Total: 5.4394149860000001
	Iters: 896
	Warmup Mean: 0.0075168404000000005
	Warmup Total: 0.037584201999999997
	Warmup Iters: 5
	Fastest Mean: 0.0060707756540178577
	Slowest Mean: 0.0060707756540178577
	
	resize:  2160x3840x3 -> 480x854x3 :  0.0060707756540178568 s
	speedup over python:  1763.9810010608544
	speedup over opencv:  0.078858539148376761
	speedup in opencv:  12.680934884153052
	worst speedup in opencv:  12.680934884153054
```

3. SIMD Vectorization + Parallelization
- `640x640x3 -> 256x256x3`:
```
	Mojo Org Tensor shape:  640x640x3
	Mojo Result Tensor shape:  256x256x3
	Numpy Org Tensor shape:  (640, 640, 3)
	Numpy Result Tensor shape:  (256, 256, 3)
	Average error:  0.906005859375
	---------------------
	Benchmark Report (s)
	---------------------
	Mean: 0.00012330201849217637
	Total: 5.6342857349999997
	Iters: 45695
	Warmup Mean: 0.00029481879999999997
	Warmup Total: 0.001474094
	Warmup Iters: 5
	Fastest Mean: 0.0001233020184921764
	Slowest Mean: 0.0001233020184921764
	
	resize:  640x640x3 -> 256x256x3 :  0.00012330201849217637 s
	speedup over python:  13858.10983701539
	speedup over opencv:  2.5543165504880907
	speedup in opencv:  0.39149415518171204
	worst speedup in opencv:  0.39149415518171216
```
- `2160x3840x3 -> 480x854x3`
```
	Mojo Org Tensor shape:  2160x3840x3
	Mojo Result Tensor shape:  480x854x3
	Numpy Org Tensor shape:  (2160, 3840, 3)
	Numpy Result Tensor shape:  (480, 854, 3)
	Average error:  0.5209252211813687
	---------------------
	Benchmark Report (s)
	---------------------
	Mean: 0.00056374303959517047
	Total: 6.3500015980000004
	Iters: 11264
	Warmup Mean: 0.0017351432
	Warmup Total: 0.008675716
	Warmup Iters: 5
	Fastest Mean: 0.00056374303959517036
	Slowest Mean: 0.00056374303959517036
	
	resize:  2160x3840x3 -> 480x854x3 :  0.00056374303959517047 s
	speedup over python:  18995.769638380512
	speedup over opencv:  0.84920338868780065
	speedup in opencv:  1.1775741987384343
	worst speedup in opencv:  1.1775741987384341
```