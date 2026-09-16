import Foundation
import AppKit
import SwiftUI

public enum InputCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case button = "Buttons"
    case thumbstick = "Sticks"
    case trigger = "Triggers"
    case dpad = "D-Pad"
    case motion = "Motion"
    case system = "System"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .button: return "circle.grid.2x2.fill"
        case .thumbstick: return "circle.circle"
        case .trigger: return "slider.horizontal.2"
        case .dpad: return "dpad.fill"
        case .motion: return "gyroscope"
        case .system: return "gearshape.fill"
        }
    }
}

public struct InputLogEntry: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let timestamp: Date = Date()
    public let element: String
    public let category: InputCategory
    public let valueDescription: String
    public let isPressed: Bool
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

@MainActor
public final class InputLogManager: ObservableObject {
    @Published public var entries: [InputLogEntry] = []
    @Published public var selectedCategory: InputCategory = .all
    @Published public var searchText: String = ""
    @Published public var isPaused: Bool = false
    
    public let maxEntries: Int = 300
    
    public init() {}
    
    public var filteredEntries: [InputLogEntry] {
        entries.filter { entry in
            let matchesCategory = (selectedCategory == .all || entry.category == selectedCategory)
            if searchText.isEmpty {
                return matchesCategory
            } else {
                return matchesCategory && (
                    entry.element.localizedCaseInsensitiveContains(searchText) ||
                    entry.valueDescription.localizedCaseInsensitiveContains(searchText)
                )
            }
        }
    }
    
    public func log(element: String, category: InputCategory, valueDescription: String, isPressed: Bool = false) {
        guard !isPaused else { return }
        let entry = InputLogEntry(element: element, category: category, valueDescription: valueDescription, isPressed: isPressed)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }
    
    public func clear() {
        entries.removeAll()
    }
    
    public func copyToClipboard() {
        let text = entries.map { "[\($0.formattedTime)] [\($0.category.rawValue)] \($0.element): \($0.valueDescription)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
