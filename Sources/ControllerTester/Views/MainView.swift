import SwiftUI
import GameController

public enum NavigationTab: String, CaseIterable, Identifiable {
    case emulator = "DS5 Emulation"
    case remapping = "Button Remapping"
    case overview = "Overview"
    case drift = "Sticks & Drift"
    case buttons = "Triggers & Buttons"
    case motion = "Motion & Sensors"
    case haptics = "Haptics"
    case log = "Event Log"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .emulator: return "cpu.fill"
        case .remapping: return "slider.horizontal.3"
        case .overview: return "gamecontroller.fill"
        case .drift: return "circle.circle.fill"
        case .buttons: return "slider.horizontal.2"
        case .motion: return "gyroscope"
        case .haptics: return "waveform"
        case .log: return "list.bullet.rectangle"
        }
    }
}

public struct MainView: View {
    @StateObject private var manager = ControllerManager()
    @State private var selectedTab: NavigationTab = .overview
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar
            List(NavigationTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("Controller Tester")
            .listStyle(.sidebar)
            
            // Controller info card at bottom of sidebar
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(manager.state.isSimulated ? Color.purple : Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(manager.state.vendorName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(manager.state.isSimulated ? "Virtual Device" : manager.state.productCategory)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let level = manager.state.batteryLevel {
                        HStack(spacing: 3) {
                            Image(systemName: batteryIcon(for: level, state: manager.state.batteryState))
                            Text(String(format: "%.0f%%", level * 100))
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
        } detail: {
            // Main Content Area
            Group {
                switch selectedTab {
                case .emulator:
                    DS5EmulatorView()
                case .remapping:
                    RemappingView()
                case .overview:
                    GamepadOverviewView(
                        state: manager.state,
                        hapticsManager: manager.hapticsManager
                    )
                case .drift:
                    DriftDiagnosticView(
                        state: manager.state,
                        driftManager: manager.driftManager
                    )
                case .buttons:
                    TriggerButtonHealthView(
                        state: manager.state
                    )
                case .motion:
                    MotionSensorDetailView(
                        state: manager.state,
                        onRecalibrate: {
                            manager.resetMotionOrientation()
                        }
                    )
                case .haptics:
                    HapticsView(
                        hapticsManager: manager.hapticsManager,
                        hasHaptics: manager.state.hasHaptics,
                        hardwareAdvisory: manager.state.hardwareAdvisory
                    )
                case .log:
                    InputLogView(
                        inputLog: manager.inputLog,
                        pollingRateHz: manager.state.pollingRateHz,
                        totalEvents: manager.state.totalEventsCount
                    )
                    .padding(16)
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    // Controller Selection Picker
                    Menu {
                        if manager.connectedControllers.isEmpty {
                            Text("No physical controllers found")
                        } else {
                            ForEach(Array(manager.connectedControllers.enumerated()), id: \.offset) { index, controller in
                                Button(action: {
                                    manager.selectController(controller)
                                }) {
                                    HStack {
                                        Text("\(controller.vendorName ?? "Controller") (#\(index + 1))")
                                        if manager.selectedController === controller {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            manager.setSimulatedMode(true)
                        }) {
                            HStack {
                                Text("Virtual Demo Controller")
                                if manager.isSimulatedMode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Label(
                            manager.state.isSimulated ? "Demo Controller" : manager.state.vendorName,
                            systemImage: "gamecontroller"
                        )
                    }
                    
                    // Wireless Discovery Button
                    Button(action: {
                        manager.toggleWirelessDiscovery()
                    }) {
                        Label(
                            manager.isDiscoveringWireless ? "Scanning..." : "Pair Wireless",
                            systemImage: manager.isDiscoveringWireless ? "antenna.radiowaves.left.and.right" : "wave.3.forward"
                        )
                    }
                    .tint(manager.isDiscoveringWireless ? .blue : .primary)
                    
                    // Background Events Monitor Toggle
                    Toggle(isOn: $manager.monitorBackgroundEvents) {
                        Image(systemName: "rectangle.stack.badge.play")
                    }
                    .help("Monitor input events in background when window is not focused")
                    
                    // Demo Mode Toggle
                    Toggle(isOn: Binding(
                        get: { manager.isSimulatedMode },
                        set: { manager.setSimulatedMode($0) }
                    )) {
                        Image(systemName: "play.circle")
                    }
                    .help("Toggle Demo / Virtual Controller Mode")
                }
            }
        }
    }
    
    private func batteryIcon(for level: Float, state: GCDeviceBattery.State?) -> String {
        if state == .charging {
            return "battery.100.bolt"
        }
        if level > 0.75 { return "battery.100" }
        if level > 0.50 { return "battery.75" }
        if level > 0.25 { return "battery.50" }
        return "battery.25"
    }
}
