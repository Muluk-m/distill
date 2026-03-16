import SwiftUI

struct OutputCard: View {
    let output: ContentOutput
    @State private var copied = false
    @State private var isExpanded = true

    private var accent: Color {
        Theme.Colors.outputAccent(for: output.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            header
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            // Accent line
            Rectangle()
                .fill(accent.opacity(0.15))
                .frame(height: 1)

            // Content — collapsible
            if isExpanded {
                Text(output.content)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.85))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .padding(Theme.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accent.opacity(0.12), lineWidth: 1)
        )
        // Left accent bar
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: isExpanded ? 0 : 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(accent)
            .frame(width: 3)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: output.type.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)

            Text(output.type.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            // Copy
            Button {
                UIPasteboard.general.string = output.content
                withAnimation(.snappy(duration: 0.2)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.snappy(duration: 0.2)) { copied = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                    Text(copied ? "已复制" : "复制")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(copied ? Theme.Colors.jade : Theme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(copied ? Theme.Colors.jade.opacity(0.1) : Theme.Colors.surfaceOverlay)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Share
            ShareLink(item: output.content) {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.surfaceOverlay)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Collapse
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.surfaceOverlay)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
