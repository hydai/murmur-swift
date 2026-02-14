import SwiftUI
import MurmurKit

/// Searchable transcription history with copy and delete.
struct HistoryView: View {
    @State var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.bar)

            Divider()

            // Content
            if viewModel.filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.searchText.isEmpty ? "No History" : "No Results",
                        systemImage: viewModel.searchText.isEmpty ? "clock" : "magnifyingglass"
                    )
                } description: {
                    Text(
                        viewModel.searchText.isEmpty
                            ? "Transcriptions will appear here."
                            : "Try a different search term."
                    )
                }
            } else {
                List {
                    ForEach(viewModel.filteredEntries) { entry in
                        HistoryRow(entry: entry, viewModel: viewModel)
                    }
                }
                .listStyle(.plain)
            }

            // Footer
            if !viewModel.entries.isEmpty {
                Divider()
                HStack {
                    Text("\(viewModel.entries.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Clear All", role: .destructive) {
                        Task { await viewModel.clearAll() }
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .task { await viewModel.load() }
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let entry: HistoryEntry
    let viewModel: HistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with timestamp and command
            HStack {
                Text(entry.timestamp, style: .date)
                Text(entry.timestamp, style: .time)

                if let command = entry.command {
                    Text(command)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                Text("\(entry.processingTimeMs)ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Processed text
            Text(entry.processedText)
                .lineLimit(3)

            // Actions
            HStack(spacing: 12) {
                Button {
                    viewModel.copyToClipboard(entry.processedText)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .font(.caption)

                Button(role: .destructive) {
                    Task { await viewModel.deleteEntry(id: entry.id) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
