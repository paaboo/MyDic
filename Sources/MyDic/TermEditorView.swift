import SwiftUI

struct TermEditorView: View {
    @ObservedObject var store: SavedTerms
    @State var term: SavedTerm
    let onClose: () -> Void
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("용어 저장").font(.headline)
                Spacer()
                Button("닫기", action: onClose)
            }
            TextField("용어", text: $term.keyword)
            Text("뜻")
            TextEditor(text: $term.meaning).frame(minHeight: 60, maxHeight: 100)
            Text("메모")
            TextEditor(text: $term.memo).frame(minHeight: 60, maxHeight: 100)
            Link("출처 · " + term.category.rawValue, destination: term.sourceURL)
            HStack {
                Button("저장") { save(export: false) }
                Button("Obsidian에 저장") { save(export: true) }
            }
            .disabled(term.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let message { Text(message).font(.caption) }
        }
        .padding(20)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private func save(export: Bool) {
        do {
            term.keyword = term.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            term.updatedAt = .now
            try store.save(term)
            message = "용어를 저장했습니다."
            if export {
                let path = UserDefaults.standard.string(forKey: "obsidianVaultPath") ?? ""
                guard !path.isEmpty else {
                    message = "용어를 저장했습니다. 검색 기록에서 Obsidian 보관함 경로를 설정하세요."
                    return
                }
                _ = try ObsidianConnection.export(term, to: URL(fileURLWithPath: NSString(string: path).expandingTildeInPath))
                message = "용어와 Obsidian 노트를 저장했습니다."
            }
        } catch {
            message = "저장 실패 · " + error.localizedDescription
        }
    }
}

struct SavedTermsList: View {
    @ObservedObject var store: SavedTerms
    let onSelect: (SavedTerm) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if store.entries.isEmpty {
                Text("검색창 옆 책갈피를 눌러 용어를 저장하세요.")
            }
            ForEach(store.entries) { term in
                Button { onSelect(term) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.keyword).fontWeight(.semibold)
                        Text(term.meaning).lineLimit(2).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
