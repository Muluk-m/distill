import SwiftUI

struct HistoryView: View {
    @State private var results: [DistillResult] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Spacer().frame(height: Theme.Spacing.xxl)

                    Text("HISTORY")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(Theme.Colors.amberDim)

                    Text("历史记录")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer().frame(height: Theme.Spacing.xl)

                if results.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.surface)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer().frame(height: Theme.Spacing.xxl)

            // Subtle illustration
            ZStack {
                Circle()
                    .fill(Theme.Colors.surfaceRaised)
                    .frame(width: 80, height: 80)

                Image(systemName: "flame")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.Colors.amberDim)
            }

            Text("还没有炼金记录")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("提炼的内容会保存在这里")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        LazyVStack(spacing: 1) {
            ForEach(results) { result in
                NavigationLink {
                    HistoryDetailView(result: result)
                } label: {
                    historyRow(result)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func historyRow(_ result: DistillResult) -> some View {
        HStack(spacing: 14) {
            // Accent dot
            Circle()
                .fill(Theme.Colors.amber)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.sourceTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textTertiary)

                    Text("\(result.outputs.count) 条")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.amberDim)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 14)
        .background(Theme.Colors.surface)
    }
}

// MARK: - Detail View

struct HistoryDetailView: View {
    let result: DistillResult

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: Theme.Spacing.lg)

                Text(result.sourceTitle)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.lg)

                Text(result.createdAt.formatted(date: .long, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, 4)

                Spacer().frame(height: Theme.Spacing.xl)

                ForEach(result.outputs) { output in
                    OutputCard(output: output)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.md)
                }
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.surface)
        .navigationBarTitleDisplayMode(.inline)
    }
}
