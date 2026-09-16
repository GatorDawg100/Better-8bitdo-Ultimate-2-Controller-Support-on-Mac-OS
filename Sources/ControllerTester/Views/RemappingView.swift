import SwiftUI
import DualSenseEmulationKit
import EightBitDoKit

public struct RemappingView: View {
    @ObservedObject private var emulator = DualSenseEmulator.shared
    @State private var editingProfile: RemappingProfile = .standard
    @State private var showingNewProfileDialog: Bool = false
    @State private var newProfileName: String = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Profile Selector & Actions
                profileHeaderCard
                
                // 2. Extra Back Paddles (M1 & M2) Section (Highlighted)
                paddlesCard
                
                // 3. Face & Shoulder Buttons
                buttonsMatrixCard
                
                // 4. Analog Deadzones & Hair Triggers
                analogTuningCard
                
                // 5. Gyro & Haptic Settings
                gyroAndHapticsCard
            }
            .padding(20)
        }
        .onAppear {
            editingProfile = emulator.activeProfile
        }
        .onChange(of: emulator.activeProfile.id) { _, _ in
            editingProfile = emulator.activeProfile
        }
    }
    
    // MARK: - Profile Header Card
    
    private var profileHeaderCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Controller Remapping & Profiles")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure button mappings, M1/M2 back paddles, hair triggers, and gyro sensitivity.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Profile Selector
                Picker("Profile", selection: Binding(
                    get: { emulator.activeProfile },
                    set: {
                        emulator.setProfile($0)
                        editingProfile = $0
                    }
                )) {
                    ForEach(emulator.savedProfiles) { p in
                        Text(p.name).tag(p)
                    }
                }
                .frame(width: 200)
                
                // Action Buttons
                Button(action: duplicateProfile) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                
                Button(action: resetToDefault) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
            
            Divider()
            
            // Editable profile name
            HStack {
                Text("Profile Name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Profile Name", text: Binding(
                    get: { editingProfile.name },
                    set: {
                        editingProfile.name = $0
                        saveChanges()
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
                
                Spacer()
                
                // Quick Layout Presets
                HStack(spacing: 8) {
                    Text("Quick Presets:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Standard") { applyPreset(.standard) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    
                    Button("Nintendo A/B Swap") { applyPreset(.nintendo) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    
                    Button("Soulsborne (M1=Touchpad)") { applyPreset(.soulsborne) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    
                    Button("FPS Pro (Hair Triggers)") { applyPreset(.fpsPro) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Back Paddles Section (Featured)
    
    private var paddlesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.purple)
                Text("8BitDo Extra Back Paddles (M1 & M2)")
                    .font(.headline)
                
                Spacer()
                
                Text("Exclusive Hardware Feature")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(6)
            }
            
            Text("The 8BitDo Ultimate 2 features two ergonomic back grip paddles that Apple's standard GameController framework cannot detect. We decode them via native D-Input and let you map them to any PlayStation DualSense button—especially the essential PS5 Touchpad Click.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                // Paddle M1 (Left Grip)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 8, height: 8)
                        Text("Left Back Paddle (M1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Picker("Target Button", selection: targetBinding(for: .paddleM1)) {
                        ForEach(DualSenseButtonTarget.allCases) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Default: Touchpad Click (opens map/inventory in Valheim, Ghost of Tsushima, Elden Ring, etc.)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
                
                // Paddle M2 (Right Grip)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("Right Back Paddle (M2)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Picker("Target Button", selection: targetBinding(for: .paddleM2)) {
                        ForEach(DualSenseButtonTarget.allCases) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Default: L3 Click (sprint without exhausting your thumbstick).")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Face & Shoulder Buttons Matrix
    
    private var buttonsMatrixCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Button Remapping Matrix")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                // Header
                GridRow {
                    Text("8BitDo Input")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text("DualSense Target")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text("8BitDo Input")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text("DualSense Target")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Row 1: A and B
                GridRow {
                    Text("Button A (Bottom)")
                    remappingPicker(for: .a)
                    Text("Button B (Right)")
                    remappingPicker(for: .b)
                }
                
                // Row 2: X and Y
                GridRow {
                    Text("Button X (Left)")
                    remappingPicker(for: .x)
                    Text("Button Y (Top)")
                    remappingPicker(for: .y)
                }
                
                // Row 3: Bumpers LB & RB
                GridRow {
                    Text("Left Bumper (LB)")
                    remappingPicker(for: .lb)
                    Text("Right Bumper (RB)")
                    remappingPicker(for: .rb)
                }
                
                // Row 4: Triggers LT & RT
                GridRow {
                    Text("Left Trigger (LT)")
                    remappingPicker(for: .lt)
                    Text("Right Trigger (RT)")
                    remappingPicker(for: .rt)
                }
                
                // Row 5: Stick Clicks L3 & R3
                GridRow {
                    Text("Left Stick Click (L3)")
                    remappingPicker(for: .l3)
                    Text("Right Stick Click (R3)")
                    remappingPicker(for: .r3)
                }
                
                // Row 6: System Buttons
                GridRow {
                    Text("Select / Minus")
                    remappingPicker(for: .select)
                    Text("Start / Plus")
                    remappingPicker(for: .start)
                }
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Analog Tuning & Hair Triggers
    
    private var analogTuningCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Analog Thumbstick & Trigger Tuning")
                .font(.headline)
            
            HStack(spacing: 24) {
                // Left Column: Stick Deadzones
                VStack(alignment: .leading, spacing: 12) {
                    Text("Thumbstick Deadzones")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Left Stick Deadzone")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f%%", editingProfile.leftStickDeadzone * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { editingProfile.leftStickDeadzone },
                            set: { editingProfile.leftStickDeadzone = $0; saveChanges() }
                        ), in: 0.0...0.30, step: 0.01)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Right Stick Deadzone")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f%%", editingProfile.rightStickDeadzone * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { editingProfile.rightStickDeadzone },
                            set: { editingProfile.rightStickDeadzone = $0; saveChanges() }
                        ), in: 0.0...0.30, step: 0.01)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Right Column: Trigger Tuning & Hair Triggers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Trigger Response")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Toggle("Hair Trigger Mode", isOn: Binding(
                            get: { editingProfile.hairTriggers },
                            set: { editingProfile.hairTriggers = $0; saveChanges() }
                        ))
                        .toggleStyle(.switch)
                    }
                    
                    Text("Hair Triggers instantly register 100% digital click at 5% pull for competitive shooters.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Trigger Deadzone")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f%%", editingProfile.triggerDeadzone * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { editingProfile.triggerDeadzone },
                            set: { editingProfile.triggerDeadzone = $0; saveChanges() }
                        ), in: 0.0...0.40, step: 0.02)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Gyro & Haptics Card
    
    private var gyroAndHapticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Motion / Gyro & Rumble Fine-Tuning")
                .font(.headline)
            
            HStack(spacing: 24) {
                // Gyro Controls
                VStack(alignment: .leading, spacing: 10) {
                    Text("6-Axis Gyro Aiming")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Toggle("Enable Gyro Streaming to DualSense", isOn: Binding(
                        get: { editingProfile.gyroEnabled },
                        set: { editingProfile.gyroEnabled = $0; saveChanges() }
                    ))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Gyro Sensitivity Multiplier")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1fx", editingProfile.gyroSensitivity))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { editingProfile.gyroSensitivity },
                            set: { editingProfile.gyroSensitivity = $0; saveChanges() }
                        ), in: 0.5...3.0, step: 0.1)
                    }
                    
                    HStack(spacing: 16) {
                        Toggle("Invert Yaw / Roll (X)", isOn: Binding(
                            get: { editingProfile.gyroInvertX },
                            set: { editingProfile.gyroInvertX = $0; saveChanges() }
                        ))
                        .font(.caption)
                        
                        Toggle("Invert Pitch (Y)", isOn: Binding(
                            get: { editingProfile.gyroInvertY },
                            set: { editingProfile.gyroInvertY = $0; saveChanges() }
                        ))
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Rumble Tuning
                VStack(alignment: .leading, spacing: 10) {
                    Text("Haptic Rumble Motor Scaling")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Toggle("Enable Rumble Feedback Passthrough", isOn: Binding(
                        get: { editingProfile.rumbleEnabled },
                        set: { editingProfile.rumbleEnabled = $0; saveChanges() }
                    ))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Rumble Strength Multiplier")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f%%", editingProfile.rumbleMultiplier * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { editingProfile.rumbleMultiplier },
                            set: { editingProfile.rumbleMultiplier = $0; saveChanges() }
                        ), in: 0.0...2.0, step: 0.1)
                    }
                    
                    Text("Controls the intensity with which games shake the 8BitDo grip motors.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func remappingPicker(for button: EightBitDoButton) -> some View {
        Picker("", selection: targetBinding(for: button)) {
            ForEach(DualSenseButtonTarget.allCases) { target in
                Text(target.shortName).tag(target)
            }
        }
        .pickerStyle(.menu)
    }
    
    private func targetBinding(for button: EightBitDoButton) -> Binding<DualSenseButtonTarget> {
        Binding(
            get: { editingProfile.buttonMap[button] ?? .none },
            set: { newTarget in
                editingProfile.buttonMap[button] = newTarget
                saveChanges()
            }
        )
    }
    
    private func saveChanges() {
        emulator.saveProfile(editingProfile)
    }
    
    private func duplicateProfile() {
        var copy = editingProfile
        copy.id = UUID()
        copy.name = "\(editingProfile.name) Copy"
        emulator.saveProfile(copy)
        emulator.setProfile(copy)
        editingProfile = copy
    }
    
    private func resetToDefault() {
        if let match = RemappingProfile.defaultPresets.first(where: { $0.name == editingProfile.name }) {
            var reset = match
            reset.id = editingProfile.id
            editingProfile = reset
            saveChanges()
        } else {
            var reset = RemappingProfile.standard
            reset.id = editingProfile.id
            reset.name = editingProfile.name
            editingProfile = reset
            saveChanges()
        }
    }
    
    private func applyPreset(_ preset: RemappingProfile) {
        var applied = preset
        applied.id = editingProfile.id
        applied.name = editingProfile.name
        editingProfile = applied
        saveChanges()
    }
}
