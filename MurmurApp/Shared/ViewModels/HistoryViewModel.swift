import SwiftUI
import MurmurKit

/// Drives the History UI.
@MainActor
@Observable
final class HistoryViewModel {
    var entries: [HistoryEntry] = []
    var searchText: String = ""
    var errorMessage: String?

    private let store: HistoryStore

    init(store: HistoryStore = HistoryStore()) {
        self.store = store
    }

    var filteredEntries: [HistoryEntry] {
        guard !searchText.isEmpty else { return entries }
        let lowered = searchText.lowercased()
        return entries.filter {
            $0.rawText.lowercased().contains(lowered) ||
            $0.processedText.lowercased().contains(lowered) ||
            ($0.command?.lowercased().contains(lowered) ?? false)
        }
    }

    func load() async {
        do {
            try await store.load()
            entries = await store.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: HistoryEntry) async {
        do {
            try await store.add(entry)
            entries = await store.getAll()
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
