# Controller Tester & DualSense 5 Emulation Suite (macOS)

A native macOS controller diagnostic and emulation suite written in **Swift 6** and **SwiftUI**. 

It includes:
1. **`EightBitDoKit`**: A modular, userspace driver library for the **8BitDo Ultimate 2 Wireless Controller** (2.4G D-Input mode, VID `0x2DC8`, PID `0x6012`). Unlocks full 500 Hz input, 6-axis IMU gyro/accel attitude, physical back paddles (M1/M2), and force-feedback motor rumble.
2. **`DualSenseEmulationKit`**: A high-performance DualSense 5 (DS5) emulator (VID `0x054C`, PID `0x0CE6`) converting 8BitDo D-Input inputs into virtual PlayStation DualSense controllers for 100% macOS game compatibility (Steam, Valheim, RPCS3, Ryujinx, Apple Arcade, Crossover).
3. **Controller Tester & Remapper Application**: Unified macOS application with live gamepad visualizers, 72-bin circularity drift analysis, trigger health, button remapping (including mapping back paddles to the PS5 Touchpad Click), and background menu bar operation.

---

## Architecture & Modular Libraries

```
                                          ┌────────────────────────────────────────┐
                                          │      8BitDo Ultimate 2 Controller      │
                                          │     (2.4G D-Input Mode: 0x2DC8/0x6012) │
                                          └───────────────────┬────────────────────┘
                                                              │ 34-byte Report ID 1 (500 Hz)
                                                              ▼
                                          ┌────────────────────────────────────────┐
                                          │             EightBitDoKit              │
                                          │ • IOHIDManager userspace driver        │
                                          │ • 6-axis IMU complementary fusion      │
                                          │ • Report ID 5 rumble motor sender      │
                                          └───────────────────┬────────────────────┘
                                                              │ EightBitDoState
                                                              ▼
                                          ┌────────────────────────────────────────┐
                                          │         DualSenseEmulationKit          │
                                          │ • Button Remapper & Deadzone Tuner     │
                                          │ • Paddle M1 → PS5 Touchpad Click       │
                                          │ • 64-byte USB DualSense Report Packer  │
                                          │ • Virtual Device (CoreHID / IOKit)     │
                                          │ • Rumble loopback to 8BitDo motors     │
                                          └───────────────────┬────────────────────┘
                                                              │ Virtual Sony DualSense (0x054C/0x0CE6)
                                                              ▼
                                          ┌────────────────────────────────────────┐
                                          │       macOS Games & Applications       │
                                          │   Steam • Valheim • RPCS3 • Ryujinx    │
                                          │   Apple Arcade • macOS GameController  │
                                          └────────────────────────────────────────┘
```

### 1. `EightBitDoKit` (Swift Library Target)
- Modular standalone Swift package target.
- Directly opens the 8BitDo Ultimate 2 controller in 2.4G D-Input mode via `IOHIDManager`.
- **IMU Sensor Fusion**: Decodes 16-bit gyroscope (deg/s) and accelerometer ($g$), running a real-time complementary orientation filter ($\alpha = 0.98$) for roll, pitch, and yaw.
- **Back Paddles**: Decodes physical paddles M1 and M2 from Byte 10.
- **Rumble Feedback**: Dispatches 4-byte Output Report ID 5 directly to the physical rumble motors with variable intensity and duration.

### 2. `DualSenseEmulationKit` (Swift Library Target)
- Translates `EightBitDoState` to standard 64-byte Sony DualSense USB Input Reports (Report ID `0x01`).
- **CoreHID / IOKit Virtual HID Device**: Presents an authentic Sony DualSense (VID `0x054C`, PID `0x0CE6`) to the macOS kernel without requiring third-party kexts or disabling SIP.
- **Rumble Loopback**: Captures game force-feedback from DualSense Output Report ID `0x02` (Bytes 3 & 4) and feeds it back to the 8BitDo physical vibration motors.
- **System Permissions**: Built-in helper checking and requesting macOS Accessibility (`AXIsProcessTrusted`) and Input Monitoring permissions.

---

## App Features

### 1. 🎮 DualSense 5 (DS5) Emulation Tab
- One-click Start / Stop Emulation toggle.
- Real-time pipeline monitor showing packet frequency ($\sim 500\text{ Hz}$), total packets sent, and latency ($< 2.0\text{ ms}$).
- System permission onboarding card with direct shortcuts to System Settings.
- Quick presets: *Standard (M1=Touchpad)*, *Nintendo A/B Swap*, *Soulsborne*, and *FPS Pro (Hair Triggers)*.

### 2. 🎛️ Interactive Button & Paddle Remapping Tab
- **Featured M1 & M2 Back Paddle Mapping**:
  - Map Left Paddle (M1) to **PS5 Touchpad Click** to open maps/inventories in PlayStation-ported games (e.g. Valheim, Ghost of Tsushima, Elden Ring, Death Stranding).
  - Map Right Paddle (M2) to **L3 (Sprint)** or any face/shoulder button.
- **Button Remapping Matrix**: Remap any physical 8BitDo button (A, B, X, Y, LB, RB, LT, RT, L3, R3, Select, Start) to any DualSense target.
- **Hair Trigger Mode**: Instant 100% digital trigger registration upon 5% pull for competitive shooters.
- **Analog Deadzones**: Configurable deadzone sliders for Left Stick, Right Stick, and Triggers.
- **6-Axis Gyro Aiming**: Sensitivity slider ($0.5\times$ to $3.0\times$), Yaw/Roll inversion, and Pitch inversion.
- **Motor Scaling**: Slider for rumble intensity ($0\%$ to $200\%$).

### 3. 🖥️ Background Mode & Menu Bar Controls
- An `NSStatusItem` in the macOS menu bar gives instant access to:
  - Controller connection status (`8BitDo Ultimate 2: Connected / Disconnected`).
  - Emulation status (`DS5 Emulation: Active (500 Hz)`).
  - Quick profile switcher.
  - "Keep Running in Background on Close" toggle: Emulation continues smoothly in the background while you play your games.

### 4. 🕹️ Comprehensive Controller Diagnostics
- **Real-time Vector Visualizer**: Sub-millisecond interactive feedback for all buttons, triggers, sticks, and paddles.
- **Circularity Benchmark**: 72-bin circular perimeter radar profiling outer gate deviation and stick drift.
- **Switch Actuation Matrix**: Hit counter and hold-duration timer (ms) for every button switch.
- **Motion Horizon**: 3D attitude horizon ball visualizing 6-axis gyro/accel orientation.
- **Haptics Suite**: Multi-frequency vibration pattern generator.
- **Virtual Demo Mode**: 60 Hz automated controller simulation when no physical hardware is plugged in.

---

## System Requirements

- **Operating System**: macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or macOS 26+.
- **Permissions**: macOS Accessibility permission (required by macOS to register userspace virtual HID devices).
- **Controller**: 8BitDo Ultimate 2 Wireless Controller in 2.4G D-Input mode (switch on back set to `D`).

---

## Building & Running

### Run the App in Development Mode
```bash
swift run
```

### Run the Unit Test Suite
```bash
swift test
```

### Package the Native `.app` Bundle
Run the packaging script to generate `ControllerTester.app`:
```bash
./scripts/build_app.sh
```

Launch the bundled application:
```bash
open ControllerTester.app
```

---

## License

MIT License. Designed for macOS gaming enthusiasts.
