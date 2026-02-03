**Goal**
Rebuild RF-DETR in MAX/Mojo with inference-only RFDETR-S as the first parity target. Start with DINOv2 (no register tokens) using a two-phase build: shape-parity first, then weight-loading and numeric parity.

**Scope Lock**
1. Inference-only.
2. Detection-only.
3. RFDETR-S target.
4. DINOv2 windowed small backbone.
5. No register tokens.
6. DRY and concise Mojo.
7. Configs passed via Mojo structs, populated from JSON via Python.

**Directory Conventions**
1. Source: `src/rf-detr-max/`
2. Tests: `scratchpad/`
3. Mojo package: `src/rf-detr-max/__init__.mojo` and symlink `src/rf_detr_max`

**Phase 0: Config Automation**
1. Implement `DinoV2Config` Mojo struct.
2. Load config from JSON using Python `json` module.
3. Test: `scratchpad/test_dinov2_config.mojo` asserts key values from `dinov2_small.json`.

**Phase 1: DINOv2 Shape-Parity (Random Weights)**
1. Patch embedding.
2. Positional embedding resize (512x512 target).
3. Window partition / unpartition.
4. Windowed self-attention block.
5. MLP block.
6. Transformer block (LN → MHA → LN → MLP).
7. Stack `num_hidden_layers`.
8. Extract outputs at `out_feature_indexes` `[3,6,9,12]`.
9. Test: one scratchpad test per block.

**Phase 2: DINOv2 Weight Loading + Parity**
1. Map PyTorch DINOv2 small weights to MAX tensors.
2. Load weights into MAX DINOv2.
3. Test: compare outputs vs PyTorch on fixed input, tolerance gate.
4. Test: positional embedding interpolation parity at 512x512.

**Phase 3: Projector + Positional Encoding**
1. Implement `MultiScaleProjector` (P-levels).
2. Implement sine positional encoding.
3. Test: projector output shapes.
4. Test: positional encoding shape and determinism.

**Phase 4: Transformer + MSDeformAttn**
1. Flatten features, masks, spatial shapes, level start index.
2. Two-stage proposals (if enabled).
3. Implement MSDeformAttn in Mojo and wrap as MAX op.
4. Build decoder layer (self-attn + deformable cross-attn + FFN).
5. Test: MSDeformAttn parity on synthetic data.
6. Test: single-layer decoder parity vs PyTorch.

**Phase 5: Heads + Postprocess**
1. Class head.
2. BBox head with refinement.
3. Postprocess top-K selection and scaling.
4. Test: output shapes and basic sanity checks.

**Phase 6: End-to-End Inference Parity**
1. Run full RFDETR-S inference on fixed inputs.
2. Compare logits and boxes to PyTorch outputs within tolerance.
3. Track latency baseline.

**Acceptance Gates**
1. Each phase must pass its scratchpad tests before moving on.
2. Every new module gets a minimal test in `scratchpad/`.
3. If a test passes and is stable, move it into `src/rf-detr-max/` as a reusable module test.
