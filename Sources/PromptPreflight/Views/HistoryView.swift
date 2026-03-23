import SwiftUI

struct HistoryView: View {
    let entries: [ChatEntry]
    let onSelect: (ChatEntry) -> Void
    let onDone: (() -> Void)?

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(entry.provider.displayName) • \(entry.model)")
                                .font(.headline)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(entry.timestamp, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(entry.inputText)
                            .lineLimit(2)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(windowBackground)
            .navigationTitle("History")
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("No History Yet", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var windowBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
