# MojoVision: Hardware-Agnostic Vision Pre/Post Processing Library

**Vision**: Production-grade, vendor-neutral vision preprocessing in Mojo — DALI-class performance on any hardware.

**Total Duration**: ~16 months | **Phases**: 7

---

## Phase 0: Foundation (4 weeks)

### 0.1 Setup
- [ ] Mojo/MAX environment with GPU support
- [ ] Benchmarking harness (PIL, OpenCV, torchvision, DALI)
- [ ] CI/CD with performance regression tests

### 0.2 SIMD Primitives
- [ ] `simd_load_rgb`, `simd_normalize`, `simd_interpolate_bilinear`
- [ ] **Target**: 5-10x over Python loops

### 0.3 Memory Abstractions
- [ ] `ImageTensor` struct: NCHW/NHWC layouts, zero-copy, pinned memory
- [ ] Memory pool for batch processing

**Exit**: SIMD 5x+ validated, benchmarks operational

---

## Phase 1: CPU Core Operations (8 weeks)

### 1.1 Resize
| Op | Target | Baseline |
|----|--------|----------|
| Nearest | 50x vs PIL | 10 MP/s |
| Bilinear | 20x vs PIL | 45 MP/s |
| Bicubic | 15x vs PIL | 31 MP/s |

- [ ] SIMD kernels + `@parallel` multicore
- [ ] Consistent antialiasing (fix PIL/PyTorch discrepancy)

### 1.2 Color & Geometric
- [ ] RGB↔BGR, Grayscale, HSV, Normalize, dtype conversion
- [ ] Crop, Pad, Flip, Rotate, Affine, Perspective

### 1.3 Image Decoding
- [ ] JPEG: SIMD IDCT, Huffman, YCbCr→RGB — **Target**: 1000 img/s
- [ ] PNG: DEFLATE, filters — **Target**: Match libpng

### 1.4 DataLoader Integration
- [ ] Zero-copy batch assembly, DLPack export, async prefetch

**Exit**: 2-3x faster than torchvision CPU, Python bindings working

---

## Phase 2: Post-Processing (6 weeks)

### 2.1 Bounding Boxes
- [ ] Format conversions (xyxy, xywh, cxcywh)
- [ ] Vectorized IoU, box clipping, coordinate scaling

### 2.2 NMS
- [ ] SIMD IoU matrix — **Target**: 5x over torchvision.ops.nms
- [ ] Soft-NMS, Batched NMS, QSI-NMS/eQSI-NMS

### 2.3 Mask Processing
- [ ] RLE encode/decode, mask resize, polygon↔mask, connected components

### 2.4 Anchors
- [ ] Generation (SSD, RetinaNet, YOLO), delta decoding

**Exit**: NMS <5ms for 8400 boxes, post-processing < inference time

---

## Phase 2.5: Multi-Object Tracking (8 weeks)

### 2.5.1 Kalman Filter
```mojo
struct KalmanTracker:
    var state: SIMD[DType.float32, 8]  # x,y,w,h,vx,vy,vw,vh
    fn predict() -> BoundingBox
    fn update(measurement: BoundingBox)
```
- [ ] Batched operations, SIMD Cholesky — **Target**: 100 tracks <1ms

### 2.5.2 Data Association
- [ ] SIMD IoU matrix — **Target**: 1000×1000 in <2ms
- [ ] Jonker-Volgenant algorithm — **Target**: 100×100 in <1ms

### 2.5.3 ReID Features
- [ ] Lightweight embedder (MobileNetV2, 128-D)
- [ ] Batch crop extraction, EMA feature bank
- [ ] SIMD cosine similarity — **Target**: 50 crops in <10ms

### 2.5.4 Tracker Implementations
| Tracker | Target Latency | Features |
|---------|---------------|----------|
| ByteTrack | <5ms | Motion-only, BYTE cascade |
| DeepSORT | <15ms | +ReID, matching cascade |
| BoT-SORT | <20ms | +GMC, IoU-ReID fusion |
| OC-SORT | <10ms | Occlusion-aware momentum |

### 2.5.5 Integration
- [ ] Track lifecycle management, interpolation
- [ ] Drop-in `sv.ByteTrack` replacement (Roboflow compatibility)

**Exit**: ByteTrack <5ms, DeepSORT <15ms, YOLO+tracking 30+ FPS CPU

---

## Phase 3: NVIDIA GPU (8 weeks)

### 3.1 Infrastructure
- [ ] CUDA allocator, pinned memory, stream management

### 3.2 GPU Kernels
- [ ] Port all Phase 1 ops to GPU
- [ ] Single Mojo source → compile-time target selection

### 3.3 GPU Decoding
- [ ] nvJPEG integration (A100+ hardware decoder)
- [ ] Fallback to Mojo kernel on older GPUs

### 3.4 GPU NMS
- [ ] Parallel IoU + sequential suppress — **Target**: 3-5x CPU
- [ ] NMS-Raster (O(n) Z-buffer) — **Target**: 10x+

### 3.5 Fused Pipeline
- [ ] decode→resize→normalize kernel, zero CPU involvement

**Exit**: DALI parity (±10%), GPU utilization >80%

---

## Phase 4: Multi-Vendor GPU (10 weeks)

### 4.1 Abstraction Layer
```mojo
trait GPUBackend:
    fn allocate(size: Int) -> DevicePtr
    fn launch_kernel[K: Kernel](...)
    fn synchronize()
```

### 4.2 Backends
- [ ] AMD ROCm: HIP kernels, rocJPEG — **Target**: <5% gap vs NVIDIA
- [ ] Apple Metal: MPS integration, unified memory — **Target**: Optimal M1-M4

### 4.3 Auto-Selection
- [ ] Runtime detection, capability-based selection
- [ ] Fallback chain: GPU → CPU SIMD → Scalar

**Exit**: Single API on NVIDIA/AMD/Apple, within 15% of native

---

## Phase 5: VLM Integration (6 weeks)

### 5.1 CLIP/SigLIP
- [ ] Exact resize/crop, batch `@parallel` — **Target**: 3x HuggingFace

### 5.2 ViT Patches
- [ ] Efficient extraction: ViT-B/16, ViT-L/14, NaViT, Swin

### 5.3 High-Resolution
- [ ] LLaVA multi-crop, adaptive tiling, 4K streaming

### 5.4 Video
- [ ] Temporal sampling, frame batching, keyframe extraction

**Exit**: Drop-in HuggingFace replacement, 3x+ speedup

---

## Phase 6: Production (6 weeks)

### 6.1 Packaging
- [ ] PyPI (`pip install mojovision`), Conda
- [ ] Wheels: Linux x86/ARM, macOS ARM, Windows

### 6.2 Integrations
- [ ] PyTorch DataLoader, TensorFlow tf.data, JAX, HuggingFace datasets, MAX Engine

### 6.3 Testing
- [ ] Unit tests, numerical equivalence, fuzz testing, memory leak detection

### 6.4 Documentation
- [ ] API reference, migration guides (torchvision, DALI, supervision)
- [ ] Examples: ImageNet, YOLO, VLM, MOT pipelines

**Exit**: Stable 1.0 release

---

## Timeline

| Phase | Weeks | Cumulative | Milestone |
|-------|-------|------------|-----------|
| 0: Foundation | 4 | 4 | SIMD validated |
| 1: CPU Core | 8 | 12 | 2-3x torchvision |
| 2: Post-Processing | 6 | 18 | NMS <5ms |
| 2.5: Tracking | 8 | 26 | ByteTrack <5ms |
| 3: NVIDIA GPU | 8 | 34 | DALI parity |
| 4: Multi-Vendor | 10 | 44 | AMD + Apple |
| 5: VLM | 6 | 50 | 3x HuggingFace |
| 6: Production | 6 | **56** | 1.0 release |

**Total: ~14 months**

---

## Performance Targets

| Operation | vs Python | vs torchvision | vs DALI |
|-----------|-----------|----------------|---------|
| JPEG decode | 10x | 2x | 1x |
| Resize | 20x | 3x | 1x |
| NMS (8400 boxes) | 50x | 10x | 2x |
| ByteTrack | 5x | — | — |
| DeepSORT | 4x | — | — |
| IoU (1000×1000) | 20x | 2x | — |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Mojo GPU maturity | CPU fallback; monitor MAX releases |
| JPEG complexity | Start with libjpeg-turbo bindings |
| Cross-vendor parity | Accept 15-20% variance initially |
| ReID accuracy/speed | Pluggable models, configurable quality |

---

## Quick Validation Sprints

**Sprint 1 (Week 1-2)**: SIMD bilinear resize → If >5x PIL, proceed

**Sprint 2 (Week 3-4)**: Batched IoU + NMS → Validate post-processing gains

**Sprint 3 (Week 5-6)**: ByteTrack prototype → If >3x supervision, proceed with tracking phase
