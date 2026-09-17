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
│ • Hardware Back Paddles (M1 & M2) decoded from Byte 8        │
│ • Extra Top Bumpers (L4 & R4) decoded from Byte 10           │
│ • 6-Axis IMU sensor fusion (α = 0.94) + auto-zero drift bias │
│ • Modern Swift 6 Concurrency (AsyncStream / async rumble)    │
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
* **Full 6-Axis IMU Sensor Fusion**: Decodes real-time angular velocity (deg/s), acceleration ($g$), gravity vector, and filtered attitude (pitch, roll, yaw) with stationary zero-rate drift cancellation.
* **Hardware Back Paddles (M1 & M2)**: Decodes the physical rear grip paddles directly from byte 8.
* **Extra Top Bumpers (L4 & R4)**: Decodes the physical extra bumper buttons directly from byte 10.
* **Full Linear Analog Triggers**: True 8-bit analog resolution ($0.0$ to $1.0$).
* **Direct Rumble Motor Output**: Sends raw Output Report ID 5 packets to drive the heavy and light rumble motors.
* **Swift Concurrency First**: Native `device.states` and `device.connections` `AsyncStream` support alongside Combine and callbacks.

---

## Hardware HID Protocol Specification

The 8BitDo Ultimate 2 Wireless Controller exchanges 34-byte input reports (Report ID `0x01`) and 4-byte vibration output reports (Report ID `0x05`) over USB HID:

### Input Report 1 (34 Bytes)

| Byte Offset | Payload Field | Data Type / Bits | Description |
|:---|:---|:---|:---|
| **0** | Report ID | `UInt8` | Constant `0x01` |
| **1** | D-Pad Hat Switch | `4-bit nibble` | `0` = Up, `1` = Up-Right, `2` = Right, `3` = Down-Right, `4` = Down, `5` = Down-Left, `6` = Left, `7` = Up-Left, `15` = Neutral |
| **2** | Left Stick X | `UInt8` | $0$ (Full Left) ... $128$ (Center) ... $255$ (Full Right) |
| **3** | Left Stick Y | `UInt8` | $0$ (Full Up, inverted) ... $128$ (Center) ... $255$ (Full Down) |
| **4** | Right Stick X | `UInt8` | $0$ (Full Left) ... $128$ (Center) ... $255$ (Full Right) |
| **5** | Right Stick Y | `UInt8` | $0$ (Full Up, inverted) ... $128$ (Center) ... $255$ (Full Down) |
| **6** | Left Trigger (LT) | `UInt8` | $0$ (Released) to $255$ (Fully Pressed) Linear Analog |
| **7** | Right Trigger (RT) | `UInt8` | $0$ (Released) to $255$ (Fully Pressed) Linear Analog |
| **8** | Buttons, Bumpers & Paddles | Bitmask | **Bit 0**: `A`<br>**Bit 1**: `B`<br>**Bit 2**: **Paddle M2** (Right Rear)<br>**Bit 3**: `X`<br>**Bit 4**: `Y`<br>**Bit 5**: **Paddle M1** (Left Rear)<br>**Bit 6**: `LB`<br>**Bit 7**: `RB` |
| **9** | System Navigation & Clicks | Bitmask | **Bit 2**: `Select` / Back<br>**Bit 3**: `Start`<br>**Bit 4**: `Home` / Guide (unintercepted by macOS)<br>**Bit 5**: `L3` (Left Thumbstick Click)<br>**Bit 6**: `R3` (Right Thumbstick Click) |
| **10** | Extra Bumpers | Bitmask | **Bit 0**: **Bumper L4** (Left Extra)<br>**Bit 1**: **Bumper R4** (Right Extra) |
| **15..16** | Accelerometer X | `Int16` (LE) | Signed 16-bit linear acceleration (~4096 LSB per 1.0g) |
| **17..18** | Accelerometer Y | `Int16` (LE) | Signed 16-bit linear acceleration (~4096 LSB per 1.0g) |
| **19..20** | Accelerometer Z | `Int16` (LE) | Signed 16-bit linear acceleration (~4096 LSB per 1.0g) |
| **21..22** | Gyroscope X | `Int16` (LE) | Signed 16-bit angular velocity (~16.384 LSB per deg/s) |
| **23..24** | Gyroscope Y | `Int16` (LE) | Signed 16-bit angular velocity (~16.384 LSB per deg/s) |
| **25..26** | Gyroscope Z | `Int16` (LE) | Signed 16-bit angular velocity (~16.384 LSB per deg/s) |

### Output Report 5 (4 Bytes Force-Feedback Rumble)

| Byte Offset | Target Motor | Value Range |
|:---|:---|:---|
| **0** | Heavy Low-Frequency Actuator | `0` (Off) to `100` (100% Intensity) |
| **1** | Light High-Frequency Actuator | `0` (Off) to `100` (100% Intensity) |
| **2** | Heavy Motor Duplicate | `0` to `100` |
| **3** | Light Motor Duplicate | `0` to `100` |

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
  * One-click orientation recalibration and stationary zero-rate drift compensation.
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

### 1. Modern Swift Concurrency (`AsyncStream` & `async`)

```swift
import EightBitDoKit

let device = EightBitDoDevice.shared
device.start()

// Stream incoming controller state updates asynchronously (500 Hz)
Task {
    for await state in device.states {
        // Stick deflections and polar calculations
        let mag = state.leftStickMagnitude       // 0.0 ... 1.0
        let deg = state.leftStickAngleDegrees     // 0° ... 360°
        let stick = state.leftStickWithDeadzone(0.08) // radial deadzone remapped
        
        // Analog linear triggers (0.0 ... 1.0)
        let lt = state.leftTrigger
        let rt = state.rightTrigger
        
        // Active buttons
        if state.paddleM1 { print("Paddle M1 active") }
        if state.paddleM2 { print("Paddle M2 active") }
        if state.buttonL4 { print("Extra bumper L4 active") }
        if state.buttonR4 { print("Extra bumper R4 active") }
        if state.buttonHome { print("Home button pressed (unintercepted!)") }
        
        // List of all buttons currently actuated
        let pressed = state.pressedButtons
        
        // 6-Axis IMU sensor fusion
        let pitch = state.pitch
        let roll = state.roll
        let yaw = state.yaw
    }
}

// Stream connection state lifecycle
Task {
    for await isConnected in device.connections {
        print("Controller connection status: \(isConnected)")
    }
}

// Trigger dual-motor rumble asynchronously for 0.4 seconds
Task {
    await device.sendRumble(lowFrequency: 0.8, highFrequency: 0.4, duration: 0.4)
}
```

### 2. Callback Closures

```swift
import EightBitDoKit

let device = EightBitDoDevice.shared
device.start()

device.onConnectionChanged = { isConnected in
    print("8BitDo Controller Connected: \(isConnected)")
}

device.onStateChanged = { state in
    // Real-time callback triggered on high-priority IOKit driver queue
    if state.isPressed(.a) {
        // Jump action
    }
}
```

### 3. SwiftUI & Combine Publisher

```swift
import SwiftUI
import EightBitDoKit

struct ContentView: View {
    @ObservedObject var device = EightBitDoDevice.shared
    
    var body: some View {
        VStack {
            Text(device.isConnected ? "Connected" : "Disconnected")
            Text("Left Stick: \(device.state.leftStick.x, specifier: "%.2f"), \(device.state.leftStick.y, specifier: "%.2f")")
            Text("Attitude: Pitch \(device.state.pitch, specifier: "%.1f")°, Roll \(device.state.roll, specifier: "%.1f")°")
        }
    }
}
```

### 4. Custom Filter Configuration & Gyro Drift Calibration

```swift
// Fine-tune complementary filter alpha or invert axes if desired
device.configuration = EightBitDoPacketDecoder.Configuration(
    complementaryFilterAlpha: 0.94, // gyro weighting
    invertPitch: false,
    invertRoll: false,
    invertYaw: false,
    autoZeroGyroBias: true // automatically cancel stationary zero-rate gyro drift
)

// One-click orientation and drift zeroing
device.resetOrientation()
device.resetGyroBias()
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
