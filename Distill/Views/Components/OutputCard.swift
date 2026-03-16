import SwiftUI

struct OutputCard: View {
    let output: ContentOutput
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(output.type.rawValue, systemImage: iconName)
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    UIPasteboard.general.string = output.content
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(copied ? .green : .orange)

                ShareLink(item: output.content) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            Text(output.content)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var iconName: String {
        switch output.type {
        case .highlights: return "sparkles"
        case .xiaohongshu: return "text.book.closed"
        case .wechat: return "doc.richtext"
        case .twitter: return "bubble.left.and.text.bubble.right"
        case .notes: return "list.bullet.clipboard"
        }
    }
}
