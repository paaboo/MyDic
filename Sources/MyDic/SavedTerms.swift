import Foundation

struct SavedTerm: Codable, Identifiable {
    let id: UUID
    var keyword: String
    var meaning: String
    var memo: String
    let category: Dictionary
    let sourceURL: URL
    var updatedAt: Date
}

@MainActor
final class SavedTerms: ObservableObject {
    @Published private(set) var entries: [SavedTerm]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.data(forKey: "savedTerms")
            .flatMap { try? JSONDecoder().decode([SavedTerm].self, from: $0) } ?? []
    }

    func save(_ term: SavedTerm) throws {
        var next = entries.filter { $0.id != term.id }
        next.insert(term, at: 0)
        let data = try JSONEncoder().encode(next)
        defaults.set(data, forKey: "savedTerms")
        entries = next
    }
}

struct TermEditor: Identifiable {
    var id: UUID { term.id }
    var term: SavedTerm
}
