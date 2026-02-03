# MojoVision: Hardware-Agnostic Vision Pre/Post Processing Library

## Project Roadmap & Timeline

**Vision**: Build a production-grade, vendor-neutral vision preprocessing library in Mojo that delivers DALI-class performance on any hardware (NVIDIA, AMD, Apple Silicon, x86/ARM CPUs).

**Strategic Value**: Eliminate the current fragmentation where optimal performance requires mixing 4-5 frameworks (torchvision, Albumentations, DALI, OpenCV, PIL) while being locked to specific hardware vendors.

---

## Phase 0: Foundation & Proof of Concept
**Duration**: 4-6 weeks | **Goal**: Validate Mojo viability for vision ops

### 0.1 Environment & Tooling Setup (Week 1-2)
- [ ] Set up Mojo/MAX development environment with GPU support
- [ ] Create benchmarking harness comparing against:
  - Python/PIL baseline
  - OpenCV (CPU)
  - torchvision (CPU/GPU)
  - NVIDIA DALI (GPU)
- [ ] Establish CI/CD pipeline with performance regression tests
- [ ] Define standard test image corpus (ImageNet subset, varying resolutions)

### 0.2 SIMD Primitives Library (Week 2-4)
- [ ] Implement core SIMD operations for image data:
  ```
  - simd_load_rgb / simd_store_rgb
  - simd_clamp / simd_normalize
  - simd_interpolate_bilinear
  - simd_dot_product (for convolutions)
  ```
- [ ] Benchmark against NumPy/OpenCV equivalents
- [ ] Target: **5-10x speedup** over naive Python loops

### 0.3 Memory Layout Abstractions (Week 4-6)
- [ ] Design zero-copy `ImageTensor` struct supporting:
  - NCHW / NHWC / HWC layouts
  - Automatic layout conversion
  - Pinned memory allocation for GPU transfer
- [ ] Implement memory pool for batch processing
- [ ] Validate with simple grayscale conversion benchmark

**Phase 0 Exit Criteria**:
- SIMD primitives showing 5x+ speedup over Python
- Memory abstractions working on CPU
- Benchmark infrastructure operational

---

## Phase 1: CPU-Optimized Core Operations
**Duration**: 8-10 weeks | **Goal**: Match/exceed Albumentations CPU performance

### 1.1 Image Resizing Suite (Week 1-3)
| Operation | Target Performance | Baseline Comparison |
|-----------|-------------------|---------------------|
| Nearest-neighbor | 50x vs PIL | PIL: ~10 MP/s |
| Bilinear | 20x vs PIL | PIL: ~45 MP/s |
| Bicubic | 15x vs PIL | PIL: ~31 MP/s |
| Lanczos | 10x vs PIL | PIL: ~25 MP/s |

- [ ] Implement SIMD-vectorized resize kernels
- [ ] Add `@parallel` multicore support
- [ ] Ensure consistent antialiasing behavior (fix PIL vs PyTorch discrepancy)
- [ ] Area-based downsampling for quality preservation

### 1.2 Color Space Operations (Week 3-5)
- [ ] RGB ↔ BGR conversion (trivial but frequent)
- [ ] RGB ↔ Grayscale (weighted sum)
- [ ] RGB ↔ HSV/HSL (for augmentation)
- [ ] Normalization (ImageNet mean/std, custom)
- [ ] Dtype conversion (uint8 ↔ float32 ↔ float16)

**Target**: 10-20x speedup over OpenCV CPU for batched operations

### 1.3 Geometric Transforms (Week 5-7)
- [ ] Crop (center, random, five-crop)
- [ ] Pad (constant, reflect, replicate, circular)
- [ ] Flip (horizontal, vertical)
- [ ] Rotate (90° multiples: fast path, arbitrary: interpolated)
- [ ] Affine transforms (unified matrix-based)
- [ ] Perspective transforms

### 1.4 JPEG/PNG Decoding (Week 7-10)
**Highest impact, highest complexity**

JPEG Decoder:
- [ ] Huffman table parsing
- [ ] SIMD-optimized IDCT (8x8 blocks)
- [ ] YCbCr → RGB conversion
- [ ] Progressive JPEG support
- [ ] **Target**: Match libjpeg-turbo (~1000 img/s on M4 Max)

PNG Decoder:
- [ ] DEFLATE decompression
- [ ] Filter reconstruction (Sub, Up, Average, Paeth)
- [ ] Interlaced PNG support
- [ ] **Target**: Match libpng performance

### 1.5 Batch Collation & DataLoader Integration (Week 9-10)
- [ ] Zero-copy batch assembly
- [ ] Dynamic padding for variable-size images
- [ ] PyTorch tensor export (via DLPack)
- [ ] Async prefetching with Mojo parallelism

**Phase 1 Exit Criteria**:
- Full preprocessing pipeline: decode → resize → normalize → batch
- **Benchmark**: 2-3x faster than torchvision CPU pipeline
- **Benchmark**: Match or exceed Albumentations throughput
- Python bindings functional

---

## Phase 2: Post-Processing & Detection Pipeline
**Duration**: 6-8 weeks | **Goal**: Eliminate NMS bottleneck

### 2.1 Bounding Box Operations (Week 1-2)
- [ ] Box format conversions (xyxy, xywh, cxcywh)
- [ ] IoU calculation (vectorized, batched)
- [ ] Box clipping to image boundaries
- [ ] Coordinate scaling (for letterbox/resize)

### 2.2 Non-Maximum Suppression (Week 2-5)
**Critical bottleneck: 54x inference time in YOLOv8**

Standard NMS:
- [ ] SIMD-optimized IoU matrix computation
- [ ] Score-sorted processing
- [ ] **Target**: 5x speedup over torchvision.ops.nms

Advanced NMS Variants:
- [ ] Soft-NMS (Gaussian, linear decay)
- [ ] Batched NMS (class-aware)
- [ ] Distance-NMS (for crowd detection)
- [ ] QSI-NMS / eQSI-NMS (6-10x faster algorithms)

### 2.3 Mask Processing (SAM-style) (Week 5-7)
- [ ] RLE encoding/decoding
- [ ] Mask resizing (nearest-neighbor for binary masks)
- [ ] Polygon ↔ mask conversion
- [ ] Connected component analysis
- [ ] Mask composition (union, intersection)

### 2.4 Anchor Generation & Decoding (Week 7-8)
- [ ] Anchor box generation (SSD, RetinaNet, YOLO styles)
- [ ] Delta decoding (center/corner formats)
- [ ] Multi-scale feature map handling

**Phase 2 Exit Criteria**:
- End-to-end detection post-processing: raw_output → NMS → final_boxes
- **Benchmark**: NMS under 5ms for 8400 boxes (YOLOv8 output)
- **Benchmark**: Full post-processing < inference time

---

## Phase 2.5: Multi-Object Tracking (MOT)
**Duration**: 8-10 weeks | **Goal**: Eliminate tracking overhead bottleneck

### Research-Backed Analysis: Why Tracking Matters

Current tracking adds **25-120ms per frame** on top of detection:
- Pure motion tracking (ByteTrack): 5-20ms
- ReID feature extraction: **20-100ms** (primary bottleneck)
- Kalman filter + Hungarian algorithm: <5ms (CPU-bound)

| Component | Current Latency | Bottleneck Type | Mojo Opportunity |
|-----------|-----------------|-----------------|------------------|
| ReID embedding | 20-100ms | GPU inference + Python overhead | Fused extraction, batched inference |
| IoU matrix | 1-5ms | O(n²) computation | SIMD vectorization |
| Hungarian algorithm | 1-3ms | O(n³) sequential | Optimized C/auction algorithm |
| Kalman filter | <1ms per track | Small matrix ops | Batched SIMD operations |
| Feature gallery | 2-10ms | Cosine similarity | Vectorized distance computation |

### 2.5.1 Motion Prediction (Kalman Filter) (Week 1-2)
**Challenge**: Small matrices (7x7 state, 4x4 measurement) not parallelizable with threading

- [ ] Implement `KalmanTracker` struct with SIMD-optimized operations:
  ```mojo
  struct KalmanTracker:
      var state: SIMD[DType.float32, 8]  # [x, y, w, h, vx, vy, vw, vh]
      var covariance: StaticTuple[SIMD[DType.float32, 8], 8]
      fn predict(self) -> BoundingBox
      fn update(self, measurement: BoundingBox)
  ```
- [ ] Batched Kalman operations for multiple tracks simultaneously
- [ ] Cholesky decomposition with SIMD intrinsics
- [ ] **Target**: Process 100+ tracks in <1ms total

### 2.5.2 Data Association (Week 2-4)
**Critical: Hungarian algorithm is inherently sequential**

IoU-based Association:
- [ ] SIMD-vectorized IoU matrix computation (N detections × M tracks)
- [ ] Fused cost matrix construction
- [ ] **Target**: 1000×1000 IoU matrix in <2ms

Hungarian Algorithm Optimization:
- [ ] Implement Jonker-Volgenant algorithm (faster than classic Hungarian)
- [ ] Auction algorithm alternative (more parallelizable)
- [ ] Early termination for sparse cost matrices
- [ ] **Target**: 100×100 assignment in <1ms

Alternative: Greedy Matching with Fallback
- [ ] SIMD-optimized greedy matcher for simple scenes
- [ ] Hungarian fallback for complex occlusion scenarios

### 2.5.3 Appearance Features (ReID) (Week 4-7)
**Highest impact: ReID adds 20-100ms latency, reduces throughput by 50%**

Lightweight ReID Embedder:
- [ ] MobileNetV2-based feature extractor in Mojo
- [ ] 128-D or 256-D embedding output
- [ ] Batch crop extraction (zero-copy from detection crops)
- [ ] **Target**: 50 detections embedded in <10ms

Feature Gallery Management:
- [ ] Exponential Moving Average (EMA) feature bank
- [ ] SIMD-optimized cosine similarity computation
- [ ] Efficient gallery pruning (sliding window)
- [ ] **Target**: 100 tracks × 50 gallery entries compared in <2ms

Joint Detection-Embedding (JDE) Support:
- [ ] Extract features from YOLO intermediate layers (LITE paradigm)
- [ ] Zero additional inference cost for appearance features
- [ ] Support BoT-SORT/DeepSORT-style fusion

### 2.5.4 Tracker Implementations (Week 7-9)

**ByteTrack** (Motion-only, fastest):
- [ ] Two-stage association (high/low confidence)
- [ ] BYTE matching cascade
- [ ] **Target**: <5ms total tracking overhead

**DeepSORT** (Motion + Appearance):
- [ ] Mahalanobis distance + cosine similarity fusion
- [ ] Matching cascade by track age
- [ ] **Target**: <15ms with lightweight ReID

**BoT-SORT** (State-of-the-art):
- [ ] Camera motion compensation (GMC)
- [ ] IoU-ReID fusion scoring
- [ ] Enhanced Kalman with width/height state
- [ ] **Target**: <20ms with full features

**OC-SORT** (Occlusion-aware):
- [ ] Observation-centric momentum
- [ ] Virtual trajectory generation
- [ ] **Target**: <10ms (motion-only variant)

### 2.5.5 Track Management (Week 9-10)
- [ ] Track lifecycle (tentative → confirmed → lost → deleted)
- [ ] Configurable hit/miss thresholds
- [ ] Track interpolation for missing frames
- [ ] Re-identification after long occlusions

### 2.5.6 Roboflow/Supervision Compatibility (Week 10)
- [ ] Drop-in replacement for `sv.ByteTrack`
- [ ] Compatible `Detections` ↔ `Tracks` conversion
- [ ] Annotation support (track trails, IDs)
- [ ] **Target**: Identical API, 3-5x faster execution

**Phase 2.5 Exit Criteria**:
- Full tracking pipeline: detections → association → tracks
- **Benchmark**: ByteTrack <5ms for 50 detections, 100 tracks
- **Benchmark**: DeepSORT <15ms with ReID (vs 40-60ms Python)
- **Benchmark**: Full YOLO+tracking pipeline at 30+ FPS on CPU
- Roboflow supervision API compatibility

---

## Phase 3: GPU Acceleration (NVIDIA First)
**Duration**: 8-10 weeks | **Goal**: GPU parity with NVIDIA DALI

### 3.1 GPU Memory Management (Week 1-2)
- [ ] CUDA memory allocator integration
- [ ] Pinned host memory for async transfers
- [ ] Memory pool for kernel scratch space
- [ ] Stream management for overlap

### 3.2 GPU Kernels - Transforms (Week 2-5)
Port Phase 1 operations to GPU:
- [ ] Resize (all interpolation modes)
- [ ] Color conversion
- [ ] Normalize
- [ ] Geometric transforms

**Architecture**: Single Mojo source → compile-time GPU target selection

### 3.3 GPU-Accelerated Decoding (Week 5-7)
- [ ] nvJPEG integration (hardware decoder on A100+)
- [ ] Fallback to Mojo JPEG kernel on older GPUs
- [ ] nvPNG for PNG files
- [ ] Unified API regardless of backend

### 3.4 GPU NMS Implementation (Week 7-9)
**Challenge**: O(n²) algorithm with sequential dependencies

Approach 1 - Parallel IoU + Sequential Suppress:
- [ ] Batched IoU matrix on GPU
- [ ] CPU suppression with GPU IoU results
- [ ] **Target**: 3-5x speedup over CPU-only

Approach 2 - NMS-Raster (Advanced):
- [ ] Z-buffer based suppression (O(n) algorithm)
- [ ] Full GPU execution
- [ ] **Target**: 10x+ speedup

### 3.5 End-to-End GPU Pipeline (Week 9-10)
- [ ] Fused decode-resize-normalize kernel
- [ ] Zero CPU involvement for standard preprocessing
- [ ] Direct output to PyTorch CUDA tensors

**Phase 3 Exit Criteria**:
- Full GPU preprocessing pipeline
- **Benchmark**: Match NVIDIA DALI throughput (±10%)
- **Benchmark**: GPU utilization >80% during preprocessing

---

## Phase 4: Multi-Vendor GPU Support
**Duration**: 10-12 weeks | **Goal**: AMD ROCm + Apple Metal parity

### 4.1 Hardware Abstraction Layer (Week 1-3)
- [ ] Define `GPUBackend` trait:
  ```mojo
  trait GPUBackend:
      fn allocate(size: Int) -> DevicePtr
      fn copy_h2d(host: Ptr, device: DevicePtr, size: Int)
      fn launch_kernel[K: Kernel](...)
      fn synchronize()
  ```
- [ ] CUDA backend implementation (wrap Phase 3)
- [ ] Backend selection at runtime or compile-time

### 4.2 AMD ROCm Backend (Week 3-6)
- [ ] HIP memory management
- [ ] Port GPU kernels to HIP (largely CUDA-compatible)
- [ ] rocJPEG integration for hardware decoding
- [ ] Validate on MI250/MI300 GPUs

**Target**: <5% performance gap vs NVIDIA equivalent

### 4.3 Apple Metal Backend (Week 6-10)
- [ ] Metal compute shader compilation from Mojo
- [ ] Metal Performance Shaders integration for primitives
- [ ] Unified memory handling (Apple Silicon specific)
- [ ] Neural Engine integration for supported ops

**Target**: Optimal performance on M1/M2/M3/M4 chips

### 4.4 Automatic Backend Selection (Week 10-12)
- [ ] Runtime hardware detection
- [ ] Capability-based kernel selection
- [ ] Fallback chains: GPU → CPU SIMD → Scalar
- [ ] User override options

**Phase 4 Exit Criteria**:
- Single API works on NVIDIA, AMD, Apple Silicon
- **Benchmark**: Within 15% of vendor-native performance
- **Benchmark**: Identical outputs across all backends

---

## Phase 5: VLM/MLLM Integration
**Duration**: 6-8 weeks | **Goal**: Production-ready VLM preprocessing

### 5.1 CLIP/SigLIP Preprocessing (Week 1-2)
Replace HuggingFace CLIPProcessor (single-core bottleneck):
- [ ] Exact resize/crop matching CLIP training
- [ ] Normalization with CLIP mean/std
- [ ] Batch processing with `@parallel`
- [ ] **Target**: 3x speedup over HuggingFace (match OpenAI CLIP)

### 5.2 Vision Transformer Patch Extraction (Week 2-4)
- [ ] Efficient patch extraction (no reshape overhead)
- [ ] Support for:
  - Fixed patch sizes (ViT-B/16, ViT-L/14)
  - Dynamic resolution (NaViT-style)
  - Multi-scale patches (Swin Transformer)
- [ ] Linear projection fusion (optional)

### 5.3 High-Resolution Processing (Week 4-6)
LLaVA-style multi-crop handling:
- [ ] Adaptive grid splitting
- [ ] Thumbnail generation
- [ ] Efficient tiling for 1024px+ images
- [ ] Memory-efficient streaming for 4K+ images

### 5.4 Video Frame Preprocessing (Week 6-8)
- [ ] Temporal sampling strategies
- [ ] Frame-level preprocessing (reuse image pipeline)
- [ ] Temporal batching
- [ ] Keyframe extraction

**Phase 5 Exit Criteria**:
- Drop-in replacement for HuggingFace image processors
- **Benchmark**: 3x+ speedup for CLIP/LLaVA preprocessing
- Validated output equivalence with reference implementations

---

## Phase 6: Production Hardening
**Duration**: 6-8 weeks | **Goal**: Enterprise-ready release

### 6.1 Python Packaging (Week 1-2)
- [ ] PyPI package (`pip install mojovision`)
- [ ] Conda package
- [ ] Pre-built wheels for:
  - Linux x86_64 (CPU, CUDA)
  - Linux ARM64 (CPU)
  - macOS ARM64 (Metal)
  - Windows x86_64 (CPU, CUDA)

### 6.2 Framework Integrations (Week 2-4)
- [ ] PyTorch DataLoader compatible `Dataset`
- [ ] TensorFlow `tf.data` integration
- [ ] JAX/Flax compatibility
- [ ] HuggingFace `datasets` integration
- [ ] MAX Engine native integration

### 6.3 Comprehensive Testing (Week 4-6)
- [ ] Unit tests for all operations
- [ ] Numerical equivalence tests vs reference implementations
- [ ] Fuzz testing for edge cases (corrupted images, extreme sizes)
- [ ] Memory leak detection
- [ ] Multi-GPU correctness tests

### 6.4 Documentation & Examples (Week 6-8)
- [ ] API reference documentation
- [ ] Migration guides from:
  - torchvision
  - Albumentations
  - NVIDIA DALI
  - Roboflow supervision (trackers)
  - Norfair
- [ ] Performance tuning guide
- [ ] Example notebooks:
  - ImageNet training pipeline
  - YOLO inference pipeline
  - VLM preprocessing pipeline
  - Multi-object tracking with ByteTrack
  - Person re-identification pipeline
  - Traffic monitoring (detection + tracking + counting)

**Phase 6 Exit Criteria**:
- Stable 1.0 release
- Comprehensive documentation
- <1% bug rate in production testing

---

## Timeline Summary

| Phase | Duration | Cumulative | Key Milestone |
|-------|----------|------------|---------------|
| **Phase 0** | 4-6 weeks | 6 weeks | SIMD primitives validated |
| **Phase 1** | 8-10 weeks | 16 weeks | CPU pipeline: 2-3x faster than torchvision |
| **Phase 2** | 6-8 weeks | 24 weeks | NMS: <5ms for 8400 boxes |
| **Phase 2.5** | 8-10 weeks | 34 weeks | MOT: ByteTrack <5ms, DeepSORT <15ms |
| **Phase 3** | 8-10 weeks | 44 weeks | NVIDIA GPU: DALI parity |
| **Phase 4** | 10-12 weeks | 56 weeks | Multi-vendor: NVIDIA + AMD + Apple |
| **Phase 5** | 6-8 weeks | 64 weeks | VLM integration: 3x HuggingFace speedup |
| **Phase 6** | 6-8 weeks | **72 weeks** | Production 1.0 release |

**Total Estimated Duration**: 16-18 months

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Mojo GPU support maturity | Medium | High | Phase 3 can fallback to CPU; monitor MAX releases |
| JPEG decoder complexity | Medium | Medium | Start with libjpeg-turbo bindings, native later |
| Cross-vendor parity | High | Medium | Accept 15-20% variance initially; optimize iteratively |
| API stability (Mojo evolution) | Medium | Low | Abstract internal APIs; version lock dependencies |
| Numerical precision differences | Low | Medium | Define tolerance thresholds; document known differences |
| ReID model performance | Medium | Medium | Start with MobileNetV2; support pluggable models |
| Hungarian algorithm edge cases | Low | Low | Comprehensive test suite from MOT benchmarks |
| Tracking accuracy vs speed tradeoff | Medium | Medium | Configurable quality levels; benchmark against MOT17/20 |

---

## Success Metrics

### Performance Targets

| Operation | vs Python/PIL | vs torchvision | vs DALI |
|-----------|---------------|----------------|---------|
| Decode JPEG | 10x | 2x | 1x (parity) |
| Resize (bilinear) | 20x | 3x | 1x |
| Normalize | 15x | 2x | 1x |
| NMS (8400 boxes) | 50x | 10x | 2x |
| Full pipeline | 15x | 3x | 1x |

### Tracking Performance Targets

| Tracker | vs Python (supervision) | vs C++ (reference) | Target Latency |
|---------|------------------------|-------------------|----------------|
| ByteTrack | 5x | 1.5x | <5ms (50 det, 100 tracks) |
| DeepSORT | 4x | 2x | <15ms (with ReID) |
| BoT-SORT | 3x | 1.5x | <20ms (full features) |
| OC-SORT | 4x | 1.5x | <10ms |
| IoU matrix (1000×1000) | 20x | 2x | <2ms |
| Hungarian (100×100) | 10x | 1.5x | <1ms |
| ReID (50 crops) | 5x | 2x | <10ms |

### Adoption Targets (Post-1.0)
- GitHub stars: 1,000 within 6 months
- PyPI downloads: 10,000/month within 1 year
- Production users: 3 major organizations within 18 months

---

## Resource Requirements

### Team Composition (Recommended)
- **Lead Engineer**: Mojo + systems programming expertise (1 FTE)
- **GPU Engineer**: CUDA/ROCm/Metal experience (1 FTE, Phase 3+)
- **ML Engineer**: VLM/vision model expertise (0.5 FTE, Phase 5)
- **DevOps**: Packaging, CI/CD, benchmarking (0.5 FTE)

### Compute Resources
- Development: 1x workstation with RTX 4090 or A100
- CI/CD: Multi-GPU runners (NVIDIA + AMD)
- Apple testing: M-series Mac (CI service or dedicated)

---

## Quick Wins for Early Validation

If you want to validate the approach before committing to the full roadmap:

**Week 1-2 Sprint**:
1. Implement SIMD bilinear resize in Mojo
2. Benchmark against PIL and OpenCV
3. If >5x speedup achieved → proceed with Phase 1
4. If <2x speedup → investigate Mojo optimization gaps

**Week 3-4 Sprint**:
1. Implement batched IoU calculation
2. Build basic NMS with SIMD IoU
3. Benchmark against torchvision.ops.nms
4. Validate YOLOv8 post-processing speedup potential

**Week 5-6 Sprint (Tracking Validation)**:
1. Implement SIMD-optimized IoU matrix computation
2. Build Jonker-Volgenant assignment algorithm
3. Implement basic ByteTrack (Kalman + IoU association)
4. Benchmark against `supervision.ByteTrack`
5. If >3x speedup achieved → proceed with full tracking phase
6. Validate on MOT17 subset for accuracy parity

These sprints derisk the core technical assumptions before full commitment.
