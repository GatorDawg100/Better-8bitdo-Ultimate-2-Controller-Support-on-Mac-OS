import SwiftUI

public struct HardwareAdvisoryView: View {
    let title: String
    let message: String
    
    public init(
        title: String = "8BitDo Hardware Mode Advisory (Gyro & Haptics)",
        message: String
    ) {
        self.title = title
        self.message = message
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("macOS GameController Driver")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(.yellow)
                    .clipShape(Capsule())
            }
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
