import SwiftUI

// MARK: - Design Tokens

enum Theme {
    // Warm amber palette — no pure black, no pure white
    enum Colors {
        static let surface = Color(red: 0.07, green: 0.06, blue: 0.05)
        static let surfaceRaised = Color(red: 0.11, green: 0.10, blue: 0.08)
        static let surfaceOverlay = Color(red: 0.15, green: 0.13, blue: 0.11)

        static let textPrimary = Color(red: 0.95, green: 0.91, blue: 0.84)
        static let textSecondary = Color(red: 0.62, green: 0.57, blue: 0.50)
        static let textTertiary = Color(red: 0.40, green: 0.37, blue: 0.33)

        static let amber = Color(red: 0.91, green: 0.65, blue: 0.20)
        static let amberLight = Color(red: 0.96, green: 0.78, blue: 0.38)
        static let amberDim = Color(red: 0.55, green: 0.39, blue: 0.12)

        static let ruby = Color(red: 0.82, green: 0.28, blue: 0.25)
        static let jade = Color(red: 0.28, green: 0.72, blue: 0.52)
        static let sapphire = Color(red: 0.30, green: 0.52, blue: 0.80)
        static let plum = Color(red: 0.65, green: 0.35, blue: 0.68)
        static let copper = Color(red: 0.76, green: 0.52, blue: 0.32)

        static func outputAccent(for type: OutputType) -> Color {
            switch type {
            case .highlights: return amber
            case .xiaohongshu: return ruby
            case .wechat: return jade
            case .twitter: return sapphire
            case .notes: return copper
            }
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 36
        static let xxl: CGFloat = 56
    }
}

// MARK: - Output Type Extensions

extension OutputType {
    var icon: String {
        switch self {
        case .highlights: return "flame"
        case .xiaohongshu: return "book.closed"
        case .wechat: return "text.alignleft"
        case .twitter: return "arrow.up.right"
        case .notes: return "list.bullet.indent"
        }
    }

    var shortLabel: String {
        switch self {
        case .highlights: return "金句"
        case .xiaohongshu: return "小红书"
        case .wechat: return "公众号"
        case .twitter: return "推文"
        case .notes: return "笔记"
        }
    }
}

// MARK: - View Modifiers

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Theme.Colors.amberLight.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    phase = UIScreen.main.bounds.width
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
