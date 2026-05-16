import SwiftUI
import MurmurKit

/// Drives the History UI with debounced search and lazy pagination.
@MainActor
@Observable
final class HistoryViewModel {
    var entries: [HistoryEntry] = []
    var errorMessage: String?

    /// Search text bound to the text field. Filtering is debounced via
    /// `debouncedSearchText` rather than running on every keystroke.
    var searchText: String = "" {
        didSet { scheduleSearchDebounce() }
    }

    /// The query the filter actually uses — updated 300 ms after the last
    /// `searchText` change.
    private(set) var debouncedSearchText: String = ""

    /// Page size — matches the Rust UI default.
    let pageSize: Int = 50
    private(set) var visibleCount: Int = 50

    private let store: HistoryStore
    private var debounceTask: Task<Void, Never>?

    init(store: HistoryStore = HistoryStore()) {
        self.store = store
    }

    /// Entries after applying the debounced search filter. The view further
    /// limits to `visibleCount` items via `pagedEntries`.
    var filteredEntries: [HistoryEntry] {
        let query = debouncedSearchText.lowercased()
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.rawText.lowercased().contains(query) ||
            $0.processedText.lowercased().contains(query) ||
            ($0.command?.lowercased().contains(query) ?? false)
        }
    }

    var pagedEntries: [HistoryEntry] {
        Array(filteredEntries.prefix(visibleCount))
    }

    var canLoadMore: Bool {
        visibleCount < filteredEntries.count
    }

    func loadMore() {
        visibleCount = min(visibleCount + pageSize, filteredEntries.count)
    }

    private func scheduleSearchDebounce() {
        debounceTask?.cancel()
        let pending = searchText
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.debouncedSearchText = pending
            self.visibleCount = self.pageSize
        }
    }

    func load() async {
        do {
            try await store.load()
            entries = await store.getAll()
            visibleCount = pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: HistoryEntry) async {
        do {
            try await store.add(entry)
            entries = await store.getAll()
            // Prepend doesn't shrink visibility — keep the user's window.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(id: UUID) async {
        do {
            try await store.delete(id: id)
            entries = await store.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAll() async {
        do {
            try await store.clear()
            entries = []
            visibleCount = pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
