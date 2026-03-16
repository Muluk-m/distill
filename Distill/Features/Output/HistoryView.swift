import SwiftUI

struct HistoryView: View {
    @State private var results: [DistillResult] = []

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView(
                        "还没有记录",
                        systemImage: "tray",
                        description: Text("炼金后的内容会出现在这里")
                    )
                } else {
                    List(results) { result in
                        NavigationLink {
                            HistoryDetailView(result: result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.sourceTitle)
                                    .font(.headline)
                                Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(result.outputs.count) 条内容")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("历史记录")
        }
    }
}

struct HistoryDetailView: View {
    let result: DistillResult

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(result.outputs) { output in
                    OutputCard(output: output)
                }
            }
            .padding()
        }
        .navigationTitle(result.sourceTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
