import SwiftUI

public struct InputLogView: View {
    @ObservedObject var inputLog: InputLogManager
    let pollingRateHz: Double
    let totalEvents: Int
    
    public init(inputLog: InputLogManager, pollingRateHz: Double, totalEvents: Int) {
        self.inputLog = inputLog
        self.pollingRateHz = pollingRateHz
        self.totalEvents = totalEvents
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Stats: Polling rate and counts
            HStack(spacing: 16) {
                // Polling Rate Badge
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.title2)
                        .foregroundColor(pollingRateHz > 100 ? .green : .accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("POLLING RATE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f Hz", pollingRateHz))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Total Events Badge
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL EVENTS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(totalEvents)")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Spacer()
                
                // Actions: Pause, Copy, Clear
                HStack(spacing: 8) {
                    Button(action: {
                        inputLog.isPaused.toggle()
                    }) {
                        Label(
                            inputLog.isPaused ? "Resume" : "Pause",
                            systemImage: inputLog.isPaused ? "play.fill" : "pause.fill"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        inputLog.copyToClipboard()
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        inputLog.clear()
                    }) {
                        Label("Clear", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Search and Category Filter
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search input events...", text: $inputLog.searchText)
                        .textFieldStyle(.plain)
                    if !inputLog.searchText.isEmpty {
                        Button(action: { inputLog.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                
                // Filter Picker
                Picker("Filter", selection: $inputLog.selectedCategory) {
                    ForEach(InputCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            
            // Live Event Stream List
            ScrollView {
                LazyVStack(spacing: 4) {
                    let items = inputLog.filteredEntries
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.largeTitle)
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Waiting for controller input events...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(items) { entry in
                            EventRowView(entry: entry)
                        }
                    }
                }
            }
            .frame(maxHeight: 340)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct EventRowView: View {
    let entry: InputLogEntry
    
    var categoryColor: Color {
        switch entry.category {
        case .all: return .secondary
        case .button: return .green
        case .thumbstick: return .blue
        case .trigger: return .orange
        case .dpad: return .cyan
        case .motion: return .purple
        case .system: return .indigo
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Timestamp
            Text(entry.formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            // Category Badge
            Text(entry.category.rawValue)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(categoryColor.opacity(0.2))
                .foregroundColor(categoryColor)
                .clipShape(Capsule())
                .frame(width: 65, alignment: .center)
            
            // Element Name
            Text(entry.element)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 140, alignment: .leading)
            
            // Value description
            Text(entry.valueDescription)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(entry.isPressed ? .green : .primary)
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(entry.isPressed ? Color.green.opacity(0.06) : Color.clear)
    }
}
