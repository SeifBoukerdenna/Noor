# Noor — Hands-Free Computer Control for macOS

> “Control your Mac with nothing but your eyes, hands, and intent.”

Noor is an experimental macOS system that lets you control your computer without touching the keyboard or mouse. It combines **gaze tracking**, **hand gestures**, and **local intelligence** to create a seamless, intent-driven interface — all running entirely on-device, with Apple-native performance.

---

## 🌌 Vision

Modern computers still depend on manual input devices designed decades ago. Noor explores a different path — one where the computer understands *what you look at* and *what you mean*, not just what you click.

The goal:  
> A fully local, privacy-first control system for macOS, built on top of Apple’s hardware acceleration stack.

---

## 🧠 Architecture Overview

Noor is built on **three core pillars**:

### 1. Perception (Sensing)
Converts raw camera data into structured signals (eye, iris, and hand landmarks).

| Component | Role | Stack |
|------------|------|-------|
| **AVFoundation** | Captures raw `CVPixelBuffer` frames | Swift |
| **MediaPipe (macOS SDK)** | Detects facial and hand landmarks | C++ / Swift bridge |
| **Core ML Model** | Estimates gaze vector & intent confidence | Neural Engine (ANE) |

---

### 2. Interpretation (Intent)
Translates perception data into meaningful system intents.

| Component | Role |
|------------|------|
| **CalibrationService** | Maps gaze vectors → precise screen coordinates |
| **StateManager** | Tracks user context (`.PASSIVE`, `.TARGETING`, `.ACTION`) |
| **LLMIntentService** | On specific gestures, sends context to a **local LLM** (via Ollama) to infer abstract commands |

Example:  
> “User gazing at Finder icon + open-hand gesture → `open Finder`”

---

### 3. Action (Execution)
Executes system-wide actions based on interpreted intent.

| Component | Role | Stack |
|------------|------|-------|
| **InputController** | Sends synthetic cursor and click events | CoreGraphics + Accessibility API |
| **ScriptingController** | Runs structured commands (e.g. via `NSAppleScript`) | Swift |
| **HUD Overlay** | Visual feedback (gaze reticle, active state, etc.) | SwiftUI + AppKit |

---

## 🧩 Performance Strategy

Noor is designed to be *purely native*:
- 100% Swift runtime  
- Zero Python or Rust interpreters  
- All inference handled by **Core ML** on the **Apple Neural Engine**  
- GPU + ANE utilization keeps latency under 100 ms  
- Minimal CPU overhead, power-efficient even on MacBook Airs  

**Python** is used *only* during model conversion (via `coremltools`).  
The shipped app is self-contained — one `.app`, no external runtimes.

---

## 🧰 App Structure

| Layer | Description |
|-------|--------------|
| **Menubar Agent** | Always-running background app (`LSUIElement=1`) |
| **Popover UI** | Quick toggle, calibration, preferences |
| **Preferences Window** | Advanced configuration: smoothing, dwell time, gesture mapping, LLM endpoint |
| **Login Helper** | Optional auto-launch service |
| **Overlay HUD** | Screen-level transparent window for gaze visualization |

---

## 🔒 Privacy & Security

Noor processes everything **locally**:
- Camera frames never leave your machine.  
- No cloud inference, no telemetry.  
- Optional LLM runs via **Ollama** (local, offline).  
- Uses only Apple-approved APIs and entitlements (Camera, Accessibility, Automation).

---

## 🚀 Roadmap

| Phase | Goal |
|-------|------|
| **Alpha** | Gaze tracking + dwell click prototype |
| **Beta** | Hand gestures + HUD overlay |
| **v1.0** | Local LLM integration + Preferences UI |
| **v1.1** | Multi-display calibration, contextual snap-to-UI |
| **v2.0** | Full spatial input layer for VisionOS & macOS hybrid |

---

## 💡 Why “Noor”?

> “Noor” (نُور) means *light* in Arabic.  
It’s about illuminating intent — letting the computer *see* what you mean without a single keystroke.

---

## 🧑‍💻 Author

**Seif Boukerdenna**  
Software Engineer @ Polytechnique Montréal  
[GitHub](https://github.com/SeifBoukerdenna)

---

## 🛠️ License

MIT License — see [LICENSE](LICENSE) for details.


