import SwiftUI
import MurmurKit

/// Searchable, paginated transcription history with copy and delete.
struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    private let timestampFormatter = RelativeTimestampFormatter()

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
                    ForEach(viewModel.pagedEntries) { entry in
                        HistoryRow(
                            entry: entry,
                            viewModel: viewModel,
                            timestampFormatter: timestampFormatter
                        )
                    }

                    if viewModel.canLoadMore {
                        Button {
                            viewModel.loadMore()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Load \(min(viewModel.pageSize, viewModel.filteredEntries.count - viewModel.pagedEntries.count)) more")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .listStyle(.plain)
            }

            // Footer
            if !viewModel.entries.isEmpty {
                Divider()
                HStack {
                    Text("\(viewModel.pagedEntries.count) of \(viewModel.filteredEntries.count) entries")
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
        .modifier(HistoryViewSizing())
        .task { await viewModel.load() }
    }
}

private struct HistoryViewSizing: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 400, minHeight: 300)
        #else
        content
        #endif
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let entry: HistoryEntry
    let viewModel: HistoryViewModel
    let timestampFormatter: RelativeTimestampFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(timestampFormatter.string(from: entry.timestamp))

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

            Text(entry.processedText)
                .lineLimit(3)

            HStack(spacing: 12) {
                MobileHistoryShareButton(text: entry.processedText)
                    .font(.caption)

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
        .modifier(HistoryRowSwipeActions(entry: entry, viewModel: viewModel))
    }
}

private struct HistoryRowSwipeActions: ViewModifier {
    let entry: HistoryEntry
    let viewModel: HistoryViewModel

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    Task { await viewModel.deleteEntry(id: entry.id) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    viewModel.copyToClipboard(entry.processedText)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .tint(.blue)

                ShareLink(item: entry.processedText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.green)
            }
        #else
        content
        #endif
    }
}

private struct MobileHistoryShareButton: View {
    let text: String

    var body: some View {
        #if os(iOS)
        ShareLink(item: text) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        #else
        EmptyView()
        #endif
    }
}
