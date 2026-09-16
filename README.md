# Better 8BitDo Ultimate 2 Support & DualSense 5 Emulation on macOS

A native macOS userspace driver and PlayStation DualSense 5 (DS5) emulation suite written in **Swift 6** and **SwiftUI**.

This project provides complete, first-class hardware support for the **8BitDo Ultimate 2 Wireless Controller** (2.4G D-Input mode) on macOS, unlocking full 500 Hz polling, 6-axis gyroscope motion aiming, physical back grip paddles (M1 & M2), and force-feedback motor rumble. By translating raw 8BitDo input reports into a virtual **Sony DualSense 5 (DS5)** controller, games that previously refused to work with third-party controllers will now detect an authentic first-party PlayStation gamepad with 100% compatibility.

---

## The Problem: Why This Exists

macOS has notoriously fragmented support for third-party gamepads:

1. **Broken Game Compatibility**: Many games on macOS (including native Mac ports like *Valheim*, *Death Stranding*, *Resident Evil*, as well as Steam games and emulators like *RPCS3*, *Ryujinx*, and *Dolphin*) have poor or nonexistent detection for third-party D-Input/X-Input gamepads. Often, the 8BitDo controller is either completely ignored or only partially recognized with missing axes.
2. **The "Switch Mode" Compromise**: Previously, the only workaround on Mac was switching the controller into Nintendo Switch mode. However, Switch mode sacrifices analog triggers (converting them into digital on/off switches), scrambles the face button layout, disables rumble on many titles, and adds noticeable input latency.
3. **Apple's GameController Limitations**: Apple's native `GameController.framework` completely ignores the 8BitDo's 6-axis gyroscope IMU and leaves the physical back grip paddles (M1 and M2) entirely inaccessible.
4. **Missing Touchpad Button**: Many modern console ports require clicking the PlayStation Touchpad to open the map, inventory, or journal. Standard controllers lack this input, leaving players unable to perform critical in-game actions.

### The Solution: 8BitDo D-Input to DualSense 5 Emulation

Apple includes first-party, kernel-level drivers for the **Sony PlayStation DualSense 5** controller across macOS Sonoma, Sequoia, and macOS 26+. 

By running our lightweight userspace driver:
- Your 8BitDo Ultimate 2 (in 2.4G D-Input mode) is read directly via IOKit USB HID at **500 Hz**.
- The raw inputs are packaged into a virtual **Sony DualSense (VID `0x054C`, PID `0x0CE6`)** controller.
- Games see a genuine DualSense controller with full native support.
- **Back Paddle M1** maps to the **PS5 Touchpad Click**, giving you an immediate hardware button for in-game maps and menus!
- **Rumble Loopback**: Vibration commands sent by games to the virtual DualSense are captured and played back through the physical 8BitDo grip motors.
- **6-Axis Gyroscope Aiming**: Real-time roll, pitch, and yaw are decoded and streamed to the virtual controller for full motion aiming in emulators and Steam.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│         8BitDo Ultimate 2 Wireless Controller                │
│             Mode Switch: "D" (2.4G D-Input)                  │
│                VID 0x2DC8 • PID 0x6012                       │
└──────────────────────────────┬───────────────────────────────┘
                               │ 34-byte Report ID 1 (500 Hz)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                        EightBitDoKit                         │
│ • IOHIDManager userspace driver (dedicated queue)            │
│ • Sub-millisecond thumbstick & trigger decoding              │
│ • Hardware Back Paddles (M1 & M2) decoded from Byte 10       │
│ • 6-Axis IMU complementary orientation filter (α = 0.98)     │
│ • Direct Output Report ID 5 rumble motor dispatcher          │
└──────────────────────────────┬───────────────────────────────┘
                               │ EightBitDoState
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                    DualSenseEmulationKit                     │
│ • Interactive remapping matrix (M1 → PS5 Touchpad Click)     │
│ • Stick deadzones & instant Hair Trigger curves              │
│ • 64-byte USB DualSense Input Report packer                  │
│ • Virtual Device Actor (CoreHID / IOKit fallback)            │
│ • DualSense Report 2 rumble loopback to 8BitDo motors        │
└──────────────────────────────┬───────────────────────────────┘
                               │ Virtual Sony DualSense (0x054C/0x0CE6)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                  macOS Games & Applications                  │
│   Steam • Valheim • RPCS3 • Ryujinx • Apple Arcade • Crossover│
└──────────────────────────────────────────────────────────────┘
```

---

## Key Features

- **🎮 DualSense 5 Emulation**: Converts 8BitDo D-Input packets into virtual DualSense reports with sub-2.0 ms latency.
- **🎛️ Back Paddle Customization**:
  - **Paddle M1 (Left Grip)**: Defaults to **PS5 Touchpad Click** (opens map/inventory in *Valheim*, *Elden Ring*, *Ghost of Tsushima*).
  - **Paddle M2 (Right Grip)**: Defaults to **L3 (Sprint)** to prevent thumbstick wear.
  - Can be remapped to any controller input.
- **🎯 Analog Stick & Trigger Tuning**:
  - Configurable inner deadzones for Left and Right thumbsticks.
  - **Hair Trigger Mode**: Instantly activates 100% digital trigger pull at 5% physical travel for competitive shooters.
- **🧭 6-Axis Gyro Aiming**: Streams real-time gyro and accelerometer telemetry with sensitivity multipliers ($0.5\times$ to $3.0\times$) and axis inversion options.
- **📳 Force-Feedback Rumble Loopback**: Translates in-game DualSense motor vibration directly to the 8BitDo physical rumble motors.
- **🖥️ Menu Bar & Background Mode**:
  - Runs in the macOS menu bar (`NSStatusItem`) with live connection and polling rate indicators.
  - Keeps emulating in the background when the app window is closed.
- **🕹️ Comprehensive Diagnostic Suite**:
  - Real-time vector gamepad visualizer with sub-millisecond feedback.
  - 72-bin circular perimeter drift and gate accuracy radar.
  - Switch actuation matrix recording click counts and hold durations (ms).
  - 3D Artificial Horizon ball for motion attitude visualization.
  - 60 Hz Virtual Demo Controller mode when no physical hardware is plugged in.

---

## Requirements

- **macOS**: macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or macOS 26+.
- **Hardware**: 8BitDo Ultimate 2 Wireless Controller with 2.4G USB adapter.
- **Permissions**: macOS **Accessibility** permission (required by macOS to register userspace virtual HID devices without kernel extensions).

---

## Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/GatorDawg100/Better-8bitdo-Ultimate-2-Controller-Support-on-Mac-OS.git
cd Better-8bitdo-Ultimate-2-Controller-Support-on-Mac-OS
```

### 2. Build the Application Bundle
Run the build and packaging script:
```bash
./scripts/build_app.sh
```
This compiles the release binaries and creates `ControllerTester.app` in the repository root.

### 3. Grant macOS Accessibility Permission
macOS requires Accessibility permissions for apps to instantiate virtual controller devices:
1. Launch `ControllerTester.app` (or click **"Grant Accessibility"** inside the app banner).
2. Go to **System Settings > Privacy & Security > Accessibility**.
3. Toggle on **Controller Tester** (or your terminal application if running from the command line).

---

## How to Use

### Step 1: Set Controller to 2.4G D-Input Mode
- Plug the 8BitDo 2.4G USB receiver into your Mac or USB dock.
- On the back of the 8BitDo Ultimate 2 controller, slide the mode switch to **`D`** (DirectInput mode).
- Turn on the controller. The status LED will indicate a solid connection to the USB receiver.

### Step 2: Launch the App
Open the app:
```bash
open ControllerTester.app
```
*(Or run it directly from the command line as shown in the section below).*

### Step 3: Start DS5 Emulation
1. In the sidebar, select **"DS5 Emulation"**.
2. Click **"Start Emulation"**.
3. The app will instantiate the virtual Sony DualSense controller. You will see:
   - Status: **Active**
   - Polling Rate: **~500 Hz**
   - Latency: **< 2.0 ms**
   - 8BitDo Hardware: **Connected**

### Step 4: Configure Button & Paddle Remapping
1. Click **"Button Remapping"** in the sidebar.
2. Under **8BitDo Extra Back Paddles**:
   - **M1 (Left Paddle)** is pre-configured to **Touchpad Click**.
   - **M2 (Right Paddle)** is pre-configured to **L3 (Sprint)**.
3. Choose from built-in presets:
   - **Standard**: Default 1:1 mapping with M1 as Touchpad and M2 as L3.
   - **Nintendo A/B Swap**: Inverts A/B and X/Y for players used to Nintendo layouts.
   - **Soulsborne**: Optimized for dodge/sprint and map access.
   - **FPS Pro**: Activates Hair Triggers with reduced stick deadzones.

### Step 5: Play in the Background
- Leave **"Keep Emulating in Background"** checked.
- Close the `Controller Tester` window. The app will continue running silently in your macOS menu bar.
- Launch your game (Steam, Valheim, RPCS3, Ryujinx, etc.). Your game will detect a native DualSense controller with working back paddles, gyro, and rumble!
- Click the menu bar icon anytime to switch profiles or stop emulation.

---

## Running from the Command Line

You can run, test, and launch the project entirely from the terminal:

### Run Directly with Swift PM (Debug Mode)
```bash
swift run ControllerTester
```

### Run the Packaged Binary Directly
```bash
./ControllerTester.app/Contents/MacOS/ControllerTester
```

### Launch the App via macOS `open`
```bash
open ControllerTester.app
```

### Run the Automated Unit Test Suite
To verify `EightBitDoKit`, `DualSenseEmulationKit`, and the controller state models:
```bash
swift test
```
*Expected output: All 7 test suites pass in < 0.01 seconds.*

---

## Project Structure

```
controller/
├── Package.swift                             # SPM Manifest (Swift 6 / macOS 14+)
├── ControllerTester.app                      # Packaged macOS Application Bundle
├── scripts/
│   └── build_app.sh                          # App bundle release compilation script
├── Sources/
│   ├── EightBitDoKit/                        # Modular 8BitDo userspace driver library
│   │   ├── EightBitDoConstants.swift         # VID 0x2DC8, PID 0x6012, Report IDs & scales
│   │   ├── EightBitDoButton.swift            # Physical input enum including paddles M1 & M2
│   │   ├── EightBitDoState.swift             # Instantaneous controller snapshot & IMU telemetry
│   │   ├── EightBitDoPacketDecoder.swift     # 500 Hz 34-byte decoder + complementary filter
│   │   └── EightBitDoDevice.swift            # IOHIDManager userspace driver & rumble sender
│   ├── DualSenseEmulationKit/                # Virtual DualSense 5 emulation library
│   │   ├── DualSenseConstants.swift          # Sony VID 0x054C, PID 0x0CE6 & HID descriptor
│   │   ├── DualSenseButtonTarget.swift       # Target buttons (Touchpad, Cross, Circle, etc.)
│   │   ├── RemappingProfile.swift            # Customization profile model & default presets
│   │   ├── DualSenseReportPacker.swift       # 64-byte USB Input Report 0x01 packer
│   │   ├── DualSenseVirtualDevice.swift      # Virtual HID device actor (CoreHID / IOKit)
│   │   ├── DualSenseEmulator.swift           # Pipeline coordinator & rumble loopback
│   │   └── PermissionHelper.swift            # Accessibility & Input Monitoring helper
│   └── ControllerTester/                     # Unified SwiftUI diagnostic & configuration app
│       ├── ControllerTesterApp.swift         # App entry point & background lifecycle delegate
│       ├── Models/
│       │   ├── MenuBarManager.swift          # NSStatusItem menu bar icon & background controls
│       │   ├── ControllerManager.swift       # Integrates EightBitDoKit with Apple GCController
│       │   ├── GamepadState.swift            # Live state model & telemetry
│       │   ├── DriftDiagnosticManager.swift  # Deadzone & 72-bin circularity diagnostics
│       │   ├── HapticsManager.swift          # CoreHaptics engine & rumble waveform tester
│       │   ├── InputLogManager.swift         # Event logger with filters & clipboard export
│       │   └── SimulatedController.swift     # 60 Hz virtual demo engine
│       └── Views/
│           ├── MainView.swift                # NavigationSplitView sidebar & tab routing
│           ├── DS5EmulatorView.swift         # DS5 Emulation status, pipeline, & controls
│           ├── RemappingView.swift           # Button matrix, M1/M2 paddle, deadzone editor
│           ├── GamepadOverviewView.swift     # Real-time vector gamepad canvas visualizer
│           ├── DriftDiagnosticView.swift     # Thumbstick polar radars & circularity test
│           ├── TriggerButtonHealthView.swift # Analog trigger meters & button hit counters
│           ├── MotionSensorDetailView.swift  # 3D attitude horizon & gyro meters
│           └── HapticsView.swift             # Rumble patterns & emergency stop
└── Tests/
    └── ControllerTesterTests/
        └── ControllerTesterTests.swift       # Unit tests for packet decoder, packer, & profiles
```

---

## License

MIT License. Designed with ❤️ for macOS gamers.
