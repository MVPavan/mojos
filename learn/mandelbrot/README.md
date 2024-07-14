# mandelbrot
[Mbot Part1](https://www.modular.com/blog/how-mojo-gets-a-35-000x-speedup-over-python-part-1)

[Mbot Part2](https://www.modular.com/blog/how-mojo-gets-a-35-000x-speedup-over-python-part-2)

[Mbot Part3](https://www.modular.com/blog/mojo-a-journey-to-68-000x-speedup-over-python-part-3)


### Params
```
xmin, xmax, ymin, ymax = -2.0, 0.6, -1.5, 1.5
width, height = 960, 960
max_iter = 200
```

#### mandlbrot.py
```
time:  7.176582172978669
- Hyperfine:
    Time (mean ± σ):      8.100 s ±  0.226 s    [User: 8.607 s, System: 3.802 s]
    Range (min … max):    7.697 s …  8.398 s    10 runs
```
#### mandlebrot_0.mojo
```
Total time: 1.8795693259999999
- Hyperfine:
    Time (mean ± σ):      1.954 s ±  0.034 s    [User: 2.462 s, System: 3.771 s]
    Range (min … max):    1.915 s …  2.014 s    10 runs
```

##### Optimizations:
1. squared norm and squared add:
   `Total time:  1.8817006860000001`
2. Move from python numpy np.linespace to pure mojo
   `Total time:  0.024893037999999999 -> 288x over python`

3. Move from mojo lists to Tensor object
   `Total time:  7.3664000000000005e-05 -> 68300x over python`
   1. interestingly if I dont have any return, its crazy fast:
        ```
        Total time:  2.7599999999999998e-07
        speedup over python:  26002109.322386485
        ---------------------
        Benchmark Report (s)
        ---------------------
        Mean: 5.0634116813911098e-09
        Total: 1.9553508639999999
        Iters: 386172602
        Warmup Mean: 1.35e-07
        Warmup Total: 2.7000000000000001e-07
        Warmup Iters: 2
        Fastest Mean: 5.0634116813911098e-09
        Slowest Mean: 5.0634116813911098e-09
        ```
    2. If I return tensor:
        ```
        Total time:  0.023294514999999998
        speedup over python:  308.08034307555533
        ---------------------
        Benchmark Report (s)
        ---------------------
        Mean: 0.0047023332451456307
        Total: 1.937361297
        Iters: 412
        Warmup Mean: 0.012280595
        Warmup Total: 0.02456119
        Warmup Iters: 2
        Fastest Mean: 0.0047023332451456307
        Slowest Mean: 0.0047023332451456307
        ```
4. Vectorize 
   1. If I return tensor with smid width of int64:
        ```
        Total time:  0.010292099000000001
        speedup over python:  697.29043346538629
        ---------------------
        Benchmark Report (s)
        ---------------------
        Mean: 4.7557165841930925e-09
        Total: 1.955331516
        Iters: 411153920
        Warmup Mean: 0.0039929140000000002
        Warmup Total: 0.0079858280000000004
        Warmup Iters: 2
        Fastest Mean: 4.7557165841930925e-09
        Slowest Mean: 4.7557165841930925e-09
        ```
    2. moved from tensor to buffer and no return, with smid width of int64
        ```
        Total time:  2.7399999999999999e-07
        speedup over python:  26191905.740798064
        ---------------------
        Benchmark Report (s)
        ---------------------
        Mean: 5.0925092556541984e-09
        Total: 1.9718983699999999
        Iters: 387215471
        Warmup Mean: 1.325e-07
        Warmup Total: 2.65e-07
        Warmup Iters: 2
        Fastest Mean: 5.0925092556541993e-09
        Slowest Mean: 5.0925092556541993e-09
        ```
    3. With smid width of int64
        ```
        Total time:  1.05e-07
        speedup over python:  68348401.647415906
        ---------------------
        Benchmark Report (s)
        ---------------------
        Mean: 7.0000000000000003e-17
        Total: 7.0000000000000005e-08
        Iters: 1000000000
        Warmup Mean: 5.0500000000000002e-08
        Warmup Total: 1.01e-07
        Warmup Iters: 2
        Fastest Mean: 7.0000000000000003e-17
        Slowest Mean: 7.0000000000000003e-17
        ```

### Params
```
changing params for more compute intensive work
xmin, xmax, ymin, ymax = -2.0, 0.47, -1.12, 1.12
width, height = 4096, 4096
max_iter = 1000
```
#### python
`time:  770.2003130670637`

#### mojo
1. Vectorize with smidwidth of int64 
   1. no return
        ```
        Total time:  1.85e-07
        speedup over python:  4163244935.4976416
        ---------------------
        Benchmark Report (s)
        ---------------------
        Mean: 6.9e-17
        Total: 6.8999999999999996e-08
        Iters: 1000000000
        Warmup Mean: 5.2999999999999998e-08
        Warmup Total: 1.06e-07
        Warmup Iters: 2
        Fastest Mean: 6.9e-17
        Slowest Mean: 6.9e-17
        ```

    2. Return dtype ptr
        ```
        Total time:  0.15752624900000001
        speedup over python:  4889.3458579532589
        ---------------------
        Benchmark Report (s)
        ---------------------
        Mean: 3.2000000000000002e-17
        Total: 3.2000000000000002e-08
        Iters: 1000000000
        Warmup Mean: 0.1410013745
        Warmup Total: 0.282002749
        Warmup Iters: 2
        Fastest Mean: 3.2000000000000002e-17
        Slowest Mean: 3.2000000000000002e-17
        ```

2. Parallelize over height
   1. `Parallelize(num_work_items=height)`
    ```
    Total time:  0.033214595999999999
    speedup over python:  23188.610003477497
    ---------------------
    Benchmark Report (s)
    ---------------------
    Mean: 0.030365351049382715
    Total: 2.4595934349999999
    Iters: 81
    Warmup Mean: 0.030479218499999999
    Warmup Total: 0.060958436999999997
    Warmup Iters: 2
    Fastest Mean: 0.030365351049382715
    Slowest Mean: 0.030365351049382715
    ```
   2. Hyper threading - there is another argument num of threads `Parallelize(num_work_items=height, num_workers = 100)` creates ppol of workers and each takes and completes independent tasks, but if >100  its decreasing performance. And observed its occupying only half cores of cpu.
    ```
    Total time:  0.026441558
    speedup over python:  29128.401324425122
    ---------------------
    Benchmark Report (s)
    ---------------------
    Mean: 0.021536543646017699
    Total: 2.433629432
    Iters: 113
    Warmup Mean: 0.023173681500000001
    Warmup Total: 0.046347363000000003
    Warmup Iters: 2
    Fastest Mean: 0.021536543646017699
    Slowest Mean: 0.021536543646017699

    speedup over python:  35762.484720220215 -> 36000
    ```