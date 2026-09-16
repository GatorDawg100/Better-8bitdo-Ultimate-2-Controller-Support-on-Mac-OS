# Controller Tester (macOS)

A high-performance, native macOS game controller diagnostic and testing application built entirely in **Swift**, **SwiftUI**, and Apple's **GameController** and **CoreHaptics** frameworks.

Supports 8BitDo Ultimate / Pro controllers, Xbox Wireless Controllers, Nintendo Switch Pro Controllers, MFi controllers, and generic USB/Bluetooth HID gamepads.

---

## Features

### 1. 🎮 Real-Time Interactive Gamepad Visualizer
- High-fidelity vector gamepad layout with sub-millisecond visual feedback.
- Real-time highlights for:
  - **Action Buttons**: A / B / X / Y (Cross, Circle, Square, Triangle).
  - **Shoulder Buttons**: LB / L1, RB / R1.
  - **Triggers**: LT / L2, RT / R2 with smooth analog percentage bars.
  - **D-Pad**: Up, Down, Left, Right directional vectors.
  - **Thumbsticks**: Left and Right sticks showing deflection coordinates and L3 / R3 stick-click states.
  - **System Buttons**: Menu / Start, Options / Share / Select, Home / Guide.
  - **Vibration Shake**: Visual tactile animation synchronized with active haptics.

### 2. 🎯 Thumbstick Precision & Drift Diagnostics
- **Dual Precision Radars**: Polar coordinate plots with concentric range rings (25%, 50%, 75%, 100%) and vector line pointers.
- **Configurable Deadzone**: Interactive slider (1% to 25%) with real-time deadzone ring visualization.
- **Center Drift Detection**: Real-time resting position drift tracker with min/max offset recording and drift alerts.
- **Circularity 360° Benchmark**:
  - 72-bin circular perimeter profiling (5° resolution).
  - Measures outer gate boundary distortion.
  - Calculates **Average Circularity Error %** and **Max Deviation %**.
  - Provides hardware quality score: *Exceptional (< 5%)*, *Good (5–10%)*, *Acceptable (10–16%)*, or *High Deviation (> 16%)*.

### 3. ⚡ Triggers & Button Switch Health
- **Analog Trigger Precision Gauges**:
  - Accurate float readouts (0.000 to 1.000) and percentages.
  - Hair-trigger actuation threshold markers.
  - Individual activation counters to detect faulty or sticking triggers.
- **Switch Actuation Matrix**:
  - Independent hit counters for every digital button on the controller.
  - Actuation hold duration timers (in milliseconds) to diagnose switch bounce or chattering.
  - One-click "Reset Counters" button.

### 4. 🧭 Motion & Sensor Telemetry (IMU)
- **3D Attitude Horizon**: Pitch, Roll, and Yaw visualization with an artificial horizon ball.
- **Gyroscope**: Real-time angular velocity ($rad/s$) along X, Y, and Z axes.
- **Accelerometer & Gravity Vector**: Instantaneous gravity vectors and user linear acceleration meters in $g$.

### 5. 📳 Unified Haptics & Vibration Suite
- **Whole-Controller Rumble**: Synchronous vibration across all controller rumble motors (via direct macOS HID force-feedback and Apple CoreHaptics).
- **Variable Controls**: Sliders for vibration Intensity (0–100%) and Sharpness / Frequency (0–100%).
- **Preset Waveform Patterns**:
  - *Single Tap* (Transient click)
  - *Double Tap* (Double pulse)
  - *Heartbeat* (Low-frequency thud rhythm)
  - *Heavy Impact* (Intense rumble pulse)
  - *Weapon Burst* (Rapid multi-strike vibration)
  - *Continuous Buzz* (Sustained test)
- Emergency Stop safety button.

### 7. 📊 Input Event Stream & Polling Rate (Hz)
- Real-time polling rate calculator measuring controller report frequency in Hertz (Hz).
- Rolling stream of raw controller events with millisecond timestamps (`HH:mm:ss.SSS`).
- Filter by category (*Buttons*, *Sticks*, *Triggers*, *D-Pad*, *Motion*, *System*).
- Live substring search query filter.
- Pause/Resume and one-click copy to system clipboard.

### 8. 🕹️ Virtual Demo Mode (No Controller Required)
- Built-in controller simulation engine running at 60 Hz.
- Performs automated Lissajous & orbital stick routines, trigger sweeps, and button presses.
- Allows immediate verification of UI components, diagnostics, and metrics without requiring physical hardware.
- Seamlessly transitions to physical controllers as soon as one is connected via USB or Bluetooth.

---

## System Requirements

- **macOS**: macOS 14.0 (Sonoma) or newer.
- **Frameworks**: `GameController.framework`, `CoreHaptics.framework`, `SwiftUI`, `AppKit`.
- **Architecture**: Apple Silicon (arm64) & Intel (x86_64).

---

## How to Run & Build

### Running directly from Terminal (Developer Mode)
```bash
swift run
```

### Running Automated Test Suite
```bash
swift test
```

### Packaging into a Standalone `.app` Bundle
To build a release binary and package it into `ControllerTester.app`:
```bash
./scripts/build_app.sh
```

Then launch the app:
```bash
open ControllerTester.app
```

---

## Project Structure

```
controller/
├── Package.swift                             # SPM Manifest (Swift 6 / macOS 14+)
├── ControllerTester.app                      # Packaged native macOS App Bundle
├── scripts/
│   └── build_app.sh                          # App bundle packaging script
├── Sources/
│   └── ControllerTester/
│       ├── ControllerTesterApp.swift         # @main App entry point & AppKit activation
│       ├── Models/
│       │   ├── ControllerManager.swift       # Apple GCController observer & lifecycle
│       │   ├── GamepadState.swift            # Real-time state model & telemetry
│       │   ├── DriftDiagnosticManager.swift  # Deadzone & 72-bin circularity diagnostics
│       │   ├── HapticsManager.swift          # CoreHaptics engine & rumble patterns
│       │   ├── LightManager.swift            # GCDeviceLight RGB lightbar controller
│       │   ├── InputLogManager.swift         # Rolling event logger & category filters
│       │   └── SimulatedController.swift     # 60Hz virtual controller demo engine
│       └── Views/
│           ├── MainView.swift                # NavigationSplitView shell & toolbar
│           ├── GamepadOverviewView.swift     # Canvas visualizer & summary cards
│           ├── DriftDiagnosticView.swift     # Stick radars & circularity test
│           ├── TriggerButtonHealthView.swift # Analog triggers & switch hit counters
│           ├── MotionSensorDetailView.swift  # 3D attitude horizon & gyro meters
│           ├── HapticsLightbarView.swift     # Rumble vibration & RGB light controls
│           └── Components/
│               ├── GamepadCanvasView.swift   # Vector controller illustration
│               ├── ThumbstickRadarView.swift # Polar coordinate radar
│               ├── TriggerBarView.swift      # Gradient analog trigger meter
│               ├── ButtonMatrixView.swift    # Button switch counters & durations
│               ├── Motion3DView.swift        # Artificial horizon attitude sphere
│               ├── HapticsTesterView.swift   # Motor locality & pattern triggers
│               ├── LightbarControlView.swift # RGB presets & breathing mode
│               └── InputLogView.swift        # Live stream table & polling gauge
└── Tests/
    └── ControllerTesterTests/
        └── ControllerTesterTests.swift       # Unit tests for coordinates, math, & drift
```
