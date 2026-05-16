import SwiftUI
import MurmurKit

struct DictionarySettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader(
                "Personal Dictionary",
                subtitle: "Custom terms (with optional aliases and descriptions) that the post-processor prefers when transcribing."
            )

            SettingsCard {
                SectionHeader("Add new entry")
                HStack(spacing: Spacing.s) {
                    TextField("Term", text: $viewModel.newEntryTerm)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.addEntry() }
                    TextField("Alias (optional)", text: $viewModel.newEntryAlias)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                    TextField("Description (optional)", text: $viewModel.newEntryDescription)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") { viewModel.addEntry() }
                        .disabled(viewModel.newEntryTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            SettingsCard {
                SectionHeader("Entries")
                TextField("Search entries…", text: $viewModel.dictionarySearch)
                    .textFieldStyle(.roundedBorder)

                if viewModel.filteredEntries.isEmpty {
                    Text(viewModel.dictionaryEntries.isEmpty
                         ? "No terms added yet."
                         : "No entries match the search.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.m)
                } else {
                    List(viewModel.filteredEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(entry.term).fontWeight(.medium)
                                if let alias = entry.alias, !alias.isEmpty {
                                    Text("aka: \(alias)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if let desc = entry.description, !desc.isEmpty {
                                    Text(desc).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeEntry(entry)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.bordered)
                    .frame(minHeight: 160)
                }
            }

            if !viewModel.dictionaryTerms.isEmpty {
                SettingsCard {
                    HStack {
                        SectionHeader("Legacy terms")
                        Spacer()
                        Text("\(viewModel.dictionaryTerms.count) terms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Add simple term…", text: $viewModel.newTerm)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { viewModel.addTerm() }
                        Button("Add") { viewModel.addTerm() }
                            .disabled(viewModel.newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    List {
                        ForEach(viewModel.dictionaryTerms, id: \.self) { term in
                            Text(term)
                        }
                        .onDelete { offsets in viewModel.removeTerm(at: offsets) }
                    }
                    .listStyle(.bordered)
                    .frame(maxHeight: 120)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
