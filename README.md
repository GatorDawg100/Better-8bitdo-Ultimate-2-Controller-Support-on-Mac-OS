# ControllerTester & EightBitDoKit

A native macOS application and Swift library designed for deep controller diagnostics, and for unlocking the complete hardware capabilities of the **8BitDo Ultimate 2 Wireless Controller** by communicating directly via macOS IOKit—completely bypassing Apple's GameController framework limitations.

Written in **Swift 6** and **SwiftUI**.

---

## The Problem: Apple's GameController Limitations

When connecting the **8BitDo Ultimate 2 Wireless Controller** to a Mac in 2.4G D-Input mode (`VID 0x2DC8, PID 0x6012`), Apple's native `GameController.framework`:

1. **Ignores the 6-Axis Gyroscope**: Apple classifies the device as a generic `HID` controller. Because generic HID descriptors lack a standardized schema for 6-axis IMU sensors, Apple sets `controller.motion = nil`. Gyro aiming and motion telemetry are completely disabled.
2. **Hides the Back Grip Paddles (M1 & M2)**: Apple's standard gamepad profiles do not expose the physical back paddles.
3. **Disables Force-Feedback Vibration**: Generic HID profiles do not provide bidirectional actuator rumble dispatch.
4. **The Switch Mode Compromise**: Switching the controller to Nintendo Switch mode enables the gyro through Apple's Switch Pro driver, but it converts analog triggers into digital on/off switches, scrambles face button mappings (swapping A/B and X/Y), and adds input latency.

---

## The Solution: EightBitDoKit

`EightBitDoKit` communicates directly with the controller at the IOKit kernel/userspace boundary via `IOHIDManager`:

```
┌──────────────────────────────────────────────────────────────┐
│         8BitDo Ultimate 2 Wireless Controller                │
│             Mode Switch: "D" (2.4G D-Input)                  │
│                VID 0x2DC8 • PID 0x6012                       │
└──────────────────────────────┬───────────────────────────────┘
                               │ 34-byte Raw HID Reports (500 Hz)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                        EightBitDoKit                         │
│ • IOHIDManager userspace driver (dedicated high-priority Q)  │
│ • Sub-millisecond thumbstick & linear analog trigger parsing │
│ • Physical Back Paddles (M1 & M2) decoded from Byte 10       │
│ • 6-Axis IMU complementary orientation filter (α = 0.98)     │
│ • Direct Output Report ID 5 force-feedback rumble dispatcher │
└──────────────────────────────┬───────────────────────────────┘
                               │ EightBitDoState
                               ▼
┌──────────────────────────────────────────────────────────────┐
│               ControllerTester App / Your App                │
│    Sticks & Drift • Triggers • Motion • Haptics • Logging    │
└──────────────────────────────────────────────────────────────┘
```

* **500 Hz High-Speed Polling**: Reads sub-millisecond state updates without driver overhead.
* **Full 6-Axis IMU Sensor Fusion**: Decodes real-time angular velocity (deg/s), acceleration ($g$), gravity vector, and filtered attitude (pitch, roll, yaw).
* **Hardware Back Paddles (M1 & M2)**: Decodes the physical grip paddles directly from byte 10.
* **Full Linear Analog Triggers**: True 8-bit analog resolution ($0.0$ to $1.0$).
* **Direct Rumble Motor Output**: Sends raw Output Report ID 5 packets to drive the heavy and light rumble motors.

---

## Controller Tester Diagnostic Suite

`ControllerTester` is a modular diagnostic app for macOS:

* **🎮 Gamepad Overview**: Live vector gamepad canvas displaying real-time button actuations, analog sticks, D-pad, bumpers, triggers, back paddles, and tactile vibration shake.
* **🕹️ Sticks & Drift**:
  * Polar coordinate radar with concentric deadzone rings.
  * Resting drift offset calculation and maximum rest deviation tracking.
  * **360° Circularity Error Benchmark (72-bin gate profiling)** with completion percentage and average error calculation.
* **⚡ Triggers & Buttons**:
  * Analog trigger depth gauges ($0.000$ to $1.000$) with actuation visualizers.
  * Switch health matrix tracking total press counters and hold duration timers (ms) to detect contact bounce or sticky switches.
* **🧭 Motion & Sensors**:
  * 3D Artificial Horizon ball reflecting real-time pitch, roll, and yaw.
  * Angular velocity dials (deg/s) and gravity acceleration meters.
  * One-click orientation recalibration.
* **📳 Haptics**:
  * Dual-motor rumble testing (low-frequency heavy motor and high-frequency light motor).
  * Preset waveform patterns (Heartbeat, Pulse, Rumble Wave) and emergency stop.
* **📋 Event Log**:
  * High-speed chronological input log with category filtering (Buttons, Sticks, Triggers, D-Pad).
  * Search filtering and one-click JSON/text clipboard export.
* **🖥️ Menu Bar & Virtual Simulator**:
  * Runs quietly in the macOS menu bar (`NSStatusItem`) with live connection status.
  * 60 Hz Virtual Demo Controller mode for exploring diagnostics without physical hardware.

---

## Using EightBitDoKit in Your Own Swift Project

Add `EightBitDoKit` to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../controller") // or git repository URL
],
targets: [
    .target(
        name: "MyGameOrApp",
        dependencies: ["EightBitDoKit"]
    )
]
```

### Swift Usage Example

```swift
import EightBitDoKit
import Combine

// 1. Initialize and start the driver
let device = EightBitDoDevice.shared
device.start()

// 2. Observe connection lifecycle
device.onConnectionChanged = { isConnected in
    print("8BitDo Controller Connected: \(isConnected)")
}

// 3. Listen to high-frequency state updates (500 Hz)
device.onStateChanged = { state in
    // Analog Thumbsticks (-1.0 ... 1.0)
    let lx = state.leftStick.x
    let ly = state.leftStick.y
    let rx = state.rightStick.x
    let ry = state.rightStick.y
    
    // Analog Triggers (0.0 ... 1.0 linear resolution)
    let lt = state.leftTrigger
    let rt = state.rightTrigger
    
    // Face Buttons & D-Pad
    let isAPressed = state.buttonA
    let isBPressed = state.isPressed(.b)
    let isUpPressed = state.dpadUp
    
    // System Buttons (Unintercepted Home / Guide button!)
    let isHomePressed = state.buttonHome
    let isSelectPressed = state.buttonSelect
    let isStartPressed = state.buttonStart
    
    // Hardware Back Paddles (M1 & M2)
    if state.paddleM1 {
        print("Left grip paddle M1 active")
    }
    if state.paddleM2 {
        print("Right grip paddle M2 active")
    }
    
    // Extra Bumper Buttons (L4 & R4)
    if state.buttonL4 {
        print("Extra bumper L4 active")
    }
    if state.buttonR4 {
        print("Extra bumper R4 active")
    }
    
    // 6-Axis Motion Sensor Fusion (IMU)
    let pitchDeg = state.pitch // filtered pitch in degrees
    let rollDeg  = state.roll  // filtered roll in degrees
    let yawDeg   = state.yaw   // accumulated yaw in degrees
    
    // Raw angular velocity (deg/s) and gravity acceleration (g)
    let rot = state.angularVelocityDeg // SIMD3<Float> (X, Y, Z) in °/s
    let acc = state.acceleration       // SIMD3<Float> in g (~1.0g resting)
}

// 4. Combine Publisher alternative (for SwiftUI or Reactive Pipelines)
var cancellables = Set<AnyCancellable>()
device.$state
    .receive(on: DispatchQueue.main)
    .sink { state in
        // Updates synchronized with view hierarchy
    }
    .store(in: &cancellables)

// 5. Trigger Dual-Motor Force-Feedback Rumble
// Heavy (low-frequency) motor at 80%, light (high-frequency) motor at 40% for 0.35s
device.sendRumble(lowFrequency: 0.8, highFrequency: 0.4, duration: 0.35)

// Continuous rumble until stopped
device.sendRumble(lowFrequency: 0.6, highFrequency: 0.6)
// Stop rumble
device.stopRumble()

// 6. Recalibrate IMU Orientation Neutral
device.resetOrientation()
```

---

## SDL2 / SDL3 Native Support

For games and emulators built with SDL2/SDL3 (such as *Hollow Knight*, *Dead Cells*, *Celeste*, and emulators like *RPCS3*, *Ryujinx*, and *Dolphin*), you can inject the hardware mapping into your environment:

```bash
./scripts/setup_sdl_controller.sh
```

This registers the 8BitDo Ultimate 2's hardware GUID into `SDL_GAMECONTROLLERCONFIG` in `~/.zshrc`.

---

## Building and Running

### Run the App in Development
```bash
swift run ControllerTester
```

### Run the Automated Unit Test Suite
```bash
swift test
```

### Build the Standalone macOS App (`.app`)
```bash
./scripts/build_app.sh
open ControllerTester.app
```

---

## Project Structure

```
controller/
├── Package.swift                             # Swift Package Manager manifest
├── ControllerTester.app                      # Packaged standalone macOS application
├── scripts/
│   ├── build_app.sh                          # App bundle packaging script
│   └── setup_sdl_controller.sh               # SDL2/SDL3 game controller mapping
├── Sources/
│   ├── EightBitDoKit/                        # Native IOKit driver library
│   │   ├── EightBitDoConstants.swift         # VID 0x2DC8, PID 0x6012, report IDs
│   │   ├── EightBitDoButton.swift            # Physical input enum (including M1 & M2)
│   │   ├── EightBitDoState.swift             # Snapshot model & IMU telemetry
│   │   ├── EightBitDoPacketDecoder.swift     # 500 Hz 34-byte decoder + orientation filter
│   │   └── EightBitDoDevice.swift            # IOHIDManager driver & rumble dispatcher
│   └── ControllerTester/                     # SwiftUI diagnostic application
│       ├── ControllerTesterApp.swift         # App entry point & background lifecycle
│       ├── Models/
│       │   ├── ControllerManager.swift       # Bridges EightBitDoKit and GCController
│       │   ├── DriftDiagnosticManager.swift  # Deadzone & 72-bin circularity diagnostics
│       │   ├── GamepadState.swift            # Live state model & telemetry
│       │   ├── HapticsManager.swift          # CoreHaptics engine & rumble waveforms
│       │   ├── InputLogManager.swift         # Event logger with filters & export
│       │   ├── MenuBarManager.swift          # macOS menu bar status icon
│       │   └── SimulatedController.swift     # 60 Hz virtual demo engine
│       └── Views/
│           ├── MainView.swift                # Sidebar navigation & tab routing
│           ├── GamepadOverviewView.swift     # Vector gamepad canvas visualizer
│           ├── DriftDiagnosticView.swift     # Thumbstick polar radars & circularity test
│           ├── TriggerButtonHealthView.swift # Analog trigger meters & button hit counters
│           ├── MotionSensorDetailView.swift  # 3D attitude horizon & gyro dials
│           ├── HapticsView.swift             # Rumble patterns & emergency stop
│           └── Components/                   # Reusable vector dials, radars, and canvas
└── Tests/
    └── ControllerTesterTests/
        └── ControllerTesterTests.swift       # Unit tests for decoder, drift, and state
```

---

## License

MIT License.
