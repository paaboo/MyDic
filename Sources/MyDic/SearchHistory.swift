import Foundation

struct SearchHistory: Codable {
    struct Entry: Codable, Identifiable {
        let id: UUID
        let keyword: String
        let category: Dictionary
        let sourceURL: URL
        let searchedAt: Date
    }

    let schemaVersion: Int
    private(set) var entries: [Entry]

    init() {
        schemaVersion = 1
        entries = []
    }

    mutating func record(_ keyword: String, category: Dictionary, sourceURL: URL, at date: Date = .now) {
        let index = entries.firstIndex {
            $0.category == category && $0.keyword.caseInsensitiveCompare(keyword) == .orderedSame
        }
        let id = index.map { entries.remove(at: $0).id } ?? UUID()
        entries.insert(Entry(id: id, keyword: keyword, category: category, sourceURL: sourceURL, searchedAt: date), at: 0)
        if entries.count > 100 { entries.removeLast(entries.count - 100) }
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    static func load(from data: Data?) -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data, let history = try? decoder.decode(Self.self, from: data),
              history.schemaVersion == 1 else { return Self() }
        return history
    }
}
