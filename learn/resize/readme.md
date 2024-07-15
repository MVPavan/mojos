# Resize

## Bilinear

1. Python
```
Bilinear resize from (640, 640, 3) to (256, 256):
Error rate: 0.4068756103515625
Opencv: 0.0003149523865431547 s
Python: 1.7087329153902828 s
cv2 resize is 5425.369003057714 times faster than python

Bilinear resize from (2160, 3840, 3) to (480, 854):
Error rate: 0.37463000910746813
Opencv: 0.001601435523480177 s
Python: 10.476222490519286 s
cv2 resize is 6541.769766510967 times faster than python
```
2. Mojo

```
resize:  640x640x3 -> 256x256x3 :  0.019101836000000001 s
speedup over python:  89.453857492561596
speedup over opencv:  0.016488068819309028
speedup in opencv:  60.649916673619714
---------------------
Benchmark Report (s)
---------------------
Mean: 0.0077036627206623466
Total: 10.700387519
Iters: 1389
Warmup Mean: 0.0138682115
Warmup Total: 0.027736423
Warmup Iters: 2
Fastest Mean: 0.0077036627206623466
Slowest Mean: 0.0077036627206623466

resize:  640x640x3 -> 256x256x3 :  0.0077036627206623466 s
speedup over python:  221.80785651573402
speedup over opencv:  0.040883459980459225
speedup in opencv:  24.459769316930679
worst speedup in opencv:  24.459769316930679
```
