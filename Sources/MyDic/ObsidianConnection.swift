import Foundation

enum ObsidianConnection {
    static func export(_ term: SavedTerm, to vault: URL) throws -> URL {
        let manager = FileManager.default
        guard manager.fileExists(atPath: vault.appendingPathComponent(".obsidian").path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = vault.appendingPathComponent("MyDic/용어", isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(term.id.uuidString + ".md")
        let marker = "<!-- MyDic term " + term.id.uuidString + " -->"
        if manager.fileExists(atPath: target.path) {
            guard try String(contentsOf: target, encoding: .utf8).hasPrefix(marker) else {
                throw CocoaError(.fileWriteFileExists)
            }
        }
        let title = term.keyword.components(separatedBy: .newlines).joined(separator: " ")
        let text = """
        \(marker)
        # \(title)

        ## 뜻
        \(term.meaning)

        ## 메모
        \(term.memo)

        - 분야 · \(term.category.rawValue)
        - 출처 · <\(term.sourceURL.absoluteString)>
        - 수정 시각 · \(ISO8601DateFormatter().string(from: term.updatedAt))
        """
        try text.write(to: target, atomically: true, encoding: .utf8)
        return target
    }

    static func export(_ history: SearchHistory, to vault: URL) throws -> URL {
        let manager = FileManager.default
        guard manager.fileExists(atPath: vault.appendingPathComponent(".obsidian").path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = vault.appendingPathComponent("MyDic", isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent("검색 기록.md")
        let marker = "<!-- MyDic managed search index v1 -->"
        if manager.fileExists(atPath: target.path) {
            let existing = try String(contentsOf: target, encoding: .utf8)
            guard existing.hasPrefix(marker) else { throw CocoaError(.fileWriteFileExists) }
        }
        let formatter = ISO8601DateFormatter()
        let entries = history.entries.map { entry in
            let keyword = entry.keyword.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "[", with: "&#91;")
                .replacingOccurrences(of: "]", with: "&#93;")
            return """
            ## \(keyword)

            - 분야 · \(entry.category.rawValue)
            - 검색 시각 · \(formatter.string(from: entry.searchedAt))
            - 출처 · <\(entry.sourceURL.absoluteString)>
            - ID · \(entry.id.uuidString)
            """
        }
        let text = marker + "\n# MyDic 검색 기록\n\n" + entries.joined(separator: "\n\n") + "\n"
        try text.write(to: target, atomically: true, encoding: .utf8)
        return target
    }
}
