# Vision — Personal Gaze Model: **Final Implementation Guide**

This is the consolidated, production-ready guide for building a **single-user**, macOS-native gaze tracker with Apple-tier smoothness. It merges the base pipeline with critical refinements: **blink gating**, **confidence scoring**, **online polynomial adaptation**, and **temporal fusion**—all while keeping latency under **10 ms/frame**.

---

## 0) System Goals & Constraints
- **Hardware:** Built-in RGB webcam (no IR/depth).
- **Platform:** macOS (Swift, AVFoundation, Vision.framework, CoreML).
- **Scope:** Personalized model for one user (you). No cloud.
- **Targets:**
  - Median error **< 25 px**; P90 **< 40 px** (native resolution)
  - **≥ 60 FPS** end-to-end; **< 10 ms** model+postproc latency
  - CPU average **< 10%**; model size **< 1 MB**

---

## 1) Data Collection — Calibration App (30–60 min)
**App:** Swift + AVFoundation + Vision.framework

**Protocol:**
1. Show dot targets at **~120–160** positions (10×12 grid + random jitter).
2. For each target: capture a **burst of 8–12 frames** over **300–500 ms** (timer-based; **no keypress** to avoid reaction lag).
3. Run **`VNDetectFaceLandmarksRequest`** once per burst; interpolate between frames.
4. From landmarks, crop **left** and **right** eyes separately (expand ROI by **20%**).
5. Save per sample:
   - `left_eye.jpg`, `right_eye.jpg` (grayscale or RGB → grayscale later)
   - `screen_x, screen_y` normalized to **[0,1]** in **window bounds**
   - **Pose features:** 6–8 landmark deltas (normalized by inter-pupil distance)
   - **Distance proxy:** `z = inter_pupil_px / frame_height`
   - Metadata: session id, timestamp, lighting bucket
6. Deliberately vary **distance**, **tilt**, **lighting**. Target **8k–15k** crops.
7. **Lock exposure/white balance** after the face is first detected to reduce drift.

---

## 2) Preprocessing
- Convert crops → **grayscale**.
- **Resize:** **60×36** (keep aspect). Start at **48×32** if you need more speed.
- **Normalize:** per-image mean/std. Optionally apply **CLAHE** if low light.
- **Augment:** ±5 px shift, ±3° rotation, ±5% brightness/contrast. **No flips.**

---

## 3) Model — Tiny CNN + Pose + Distance (PyTorch)
```python
import torch, torch.nn as nn

class EyeRegressor(nn.Module):
    def __init__(self, pose_dim=9):  # 8 pose deltas + 1 distance scalar
        super().__init__()
        self.fe = nn.Sequential(
            nn.Conv2d(2, 32, 3, padding=1), nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(64, 96, 3, padding=1), nn.ReLU(),
            nn.AdaptiveAvgPool2d((1,1)),
            nn.Flatten()
        )
        self.head = nn.Sequential(
            nn.Linear(96 + pose_dim, 128), nn.ReLU(),
            nn.Linear(128, 64), nn.ReLU(),
            nn.Linear(64, 2), nn.Sigmoid()   # (u,v) in [0,1]
        )
        self.conf_head = nn.Sequential(      # optional confidence head
            nn.Linear(96 + pose_dim, 32), nn.ReLU(),
            nn.Linear(32, 1), nn.Sigmoid()
        )
    def forward(self, eyes_2ch, pose_feat):
        z = self.fe(eyes_2ch)
        feats = torch.cat([z, pose_feat], dim=1)
        uv = self.head(feats)
        conf = self.conf_head(feats)
        return uv, conf
```
**Inputs**
- `eyes_2ch`: stacked L/R crops `[B,2,36,60]`
- `pose_feat`: 9-D vector (landmark deltas + distance proxy)

**Loss**
- Regression: **Huber (Smooth L1)** on `(u,v)` with **edge weighting** to prioritize corners: `L_reg = huber * (1 + 0.5*edge_weight)`
- Confidence: `L_conf = BCE(conf, 1_{|e| < 30px})` on held-out calib points
  - Compute labels during training by running inference on validation set and marking samples with `error < 30px` as positive (conf=1).
- **Total:** `L = L_reg + 0.2 * L_conf`

**Training**
- Optimizer: `AdamW(lr=1e-3)`; batch `128`; **10–20 epochs**
- Early stop on **median L2** error over a 15% held-out grid

---

## 4) Calibration — Polynomial + **Online Adaptation**
Initial mapping (2nd-order) from raw network `(u,v)` → screen `(x,y)`:
```
x = a0 + a1*u + a2*v + a3*u*v + a4*u^2 + a5*v^2
y = b0 + b1*u + b2*v + b3*u*v + b4*u^2 + b5*v^2
```
**Online refit:**
1. Keep circular buffer of last **500–600** confirmed interactions: raw `(u,v) → (x_true,y_true)`.
2. Refit via **weighted least squares** every ~**500 interactions** with recency weights `w_i = exp(-(Δt)/τ)`, `τ ≈ 2 h`.
3. Guard with **RANSAC** (reject residuals > **35 px**); ridge if ill-conditioned (`λ=1e-6`).
4. Use **confidence** to weight samples: `w := w * conf`.

---

## 5) Temporal Fusion — EMA + Causal 1D Conv
- Maintain last **K=8** corrected predictions.
- Depthwise kernel `[1,2,3,2,1]/9` per axis, then blend with EMA:  
  `p̂_t = β * Conv1D(p) + (1-β) * EMA(p)` with `β≈0.6`, `α≈0.5`.
- **Saccade gate:** if `||p_t − p_{t-1}|| > 80 px`, bypass filter for 2–3 frames.

---

## 6) **Blink Detection (MUST-HAVE)** — Geometry-Based
Vision.framework does **not** provide eye-openness scores. Derive a normalized lid gap:
```swift
func normLidGap(_ eye: VNEyeLandmarks) -> CGFloat {
    let upper = midPoint(eye.upperLid)
    let lower = midPoint(eye.lowerLid)
    let inner = eye.innerCorner
    let outer = eye.outerCorner
    let gap = distance(upper, lower)
    let width = max(distance(inner, outer), 1e-6)
    return gap / width
}

// Per frame with 1–2 frame hysteresis
let left = normLidGap(leftEye)
let right = normLidGap(rightEye)
let openness = (left + right) / 2.0
if openness < 0.20 {           // tune 0.18–0.25
    pauseTrackingAndResetDwell()
} else {
    updateCursor()
}
```
Effect: kills blink-induced jitter and accidental clicks at ~zero cost.

---

## 7) CoreML Export (FP16, mlprogram)
```python
import coremltools as ct, torch
# ex_eyes: [1,2,36,60], ex_pose: [1,9]
traced = torch.jit.trace(model, (ex_eyes, ex_pose))
mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="eyes", shape=ex_eyes.shape),
            ct.TensorType(name="pose", shape=ex_pose.shape)],
    convert_to="mlprogram", compute_units=ct.ComputeUnit.ALL
)
mlmodel = ct.models.neural_network.quantization_utils.quantize_weights(mlmodel, nbits=16)
mlmodel.save("EyeRegressor.mlpackage")
```

---

## 8) Runtime Loop (Swift)
1. **Capture:** 60 FPS @ 720p (lock AE/AWB after detection)
2. **Landmarks:** 10–15 FPS; interpolate between frames
3. **Crops & Features:** L/R eye ROIs + pose + distance
4. **Inference:** CoreML → `(u,v)` and `conf`
5. **Calibration:** polynomial map `(u,v)` → `(x,y)`
6. **Filtering:** temporal fusion + EMA + saccade gate
7. **Blink gate:** pause updates when lid-gap < threshold
8. **Confidence gate:** suppress cursor when `conf < 0.4`
9. **Injection:** cursor events via `CGEvent`
10. **Adaptation:** refit polynomial every ~500 interactions

**Click logic:** dwell **~250 ms** within **25 px** radius; confirm via hand gesture.

---

## 9) Evaluation & A/B Harness
- **Heatmap sweep:** animate a target; log predicted vs true.
- Report **median** & **P90** error overall and by region (center vs corners).
- A/B toggles: blink gate, confidence gate, conv-fusion.
- Refit poly if corner error > **30 px**.

---

## 10) Performance & Power
- Adaptive FPS: drop model to **30 FPS** when gaze speed < **20 px/frame** for 1 s; ramp to 60 on motion.
- Suspend landmark calls when face is static; track ROIs.

---

## 11) Ship Checklist (Apple-Tier Feel)
- ✅ Median **<25 px**, P90 **<40 px** after online refits
- ✅ Smooth saccades; no float at steady gaze
- ✅ No accidental clicks; blink + confidence gates active
- ✅ ≥60 FPS end-to-end; <10 ms/frame; CPU <10%

---

## 12) Roadmap (Post-MVP)
- Light **3D head-pose** conditioning (PnP) if distance still shifts bias
- Eye-openness auxiliary branch (robust blink proxy)
- Per-display/ per-window polynomial surfaces
- Packaging: quick 4-point recalibration flow; brew installer

---

### TL;DR
Collect bursts → train tiny CNN (eyes + pose + distance) → fit polynomial → add **blink + confidence gates** → **EMA + 1D conv** → **online adaptation**. Ship at 60 FPS with <25 px median.
