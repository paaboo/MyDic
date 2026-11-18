import AppKit
import Carbon
import SwiftUI

struct SearchSettingsView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case home = "홈"
        case size = "창 크기"
        case shortcut = "단축키"
        case history = "검색 기록"

        var id: Self { self }
    }

    @ObservedObject var search: SearchState
    let onShortcutChange: (Shortcut) -> Bool
    let onHistorySelection: (SearchHistory.Entry) -> Void
    let onClose: () -> Void

    @State private var section: Section?
    @State private var home: Dictionary = .english
    @State private var width = ""
    @State private var height = ""
    @State private var shortcut = Shortcut.standard
    @State private var shortcutError: String?
    @State private var keyMonitor: Any?
    @State private var copied = false

    private var validSize: SearchState.WindowSize? {
        guard let width = Int(width), let height = Int(height),
              SearchState.WindowSize.widthRange.contains(width),
              SearchState.WindowSize.heightRange.contains(height) else { return nil }
        return SearchState.WindowSize(width: width, height: height)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if section != nil {
                    Button { show(nil) } label: {
                        Label("뒤로", systemImage: "chevron.left")
                    }
                }
                Text(section?.rawValue ?? "설정").font(.headline)
                Spacer()
                Button("닫기", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch section {
                    case nil: sections
                    case .home: homeSettings
                    case .size: sizeSettings
                    case .shortcut: shortcutSettings
                    case .history: historySettings
                    }
                    if section == nil,
                       let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String {
                        Text(copyright)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 440, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .id(section)
        }
        .onDisappear(perform: stopRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didCloseNotification)) { _ in
            stopRecording()
        }
    }

    private var sections: some View {
        ForEach(Section.allCases) { section in
            Button { show(section) } label: {
                HStack {
                    Text(section.rawValue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    private var homeSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("홈 분야", selection: $home) {
                ForEach(Dictionary.allCases) { dictionary in
                    Text(dictionary.rawValue).tag(dictionary)
                }
            }
            Button("저장") {
                search.applySettings(home: home, size: search.windowSize, shortcut: search.shortcut)
                show(nil)
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var sizeSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                TextField("가로 (pt)", text: $width)
                TextField("세로 (pt)", text: $height)
            }
            if validSize == nil {
                Text("가로 440–1600pt, 세로 300–1400pt 범위의 정수를 입력하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("저장") {
                guard let validSize else { return }
                search.applySettings(home: search.homeDictionary, size: validSize, shortcut: search.shortcut)
                show(nil)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(validSize == nil)
        }
    }

    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("전역 단축키", value: shortcut.label)
            HStack {
                Button(keyMonitor == nil ? "키 조합 입력" : "입력 취소") {
                    if keyMonitor == nil {
                        startRecording()
                    } else {
                        stopRecording()
                    }
                }
                Button("기본값 복원") {
                    stopRecording()
                    shortcut = .standard
                    shortcutError = nil
                }
            }
            if keyMonitor != nil {
                Text("⌃, ⌥ 또는 ⌘를 포함한 키 조합을 누르세요. Esc로 취소합니다.")
                    .foregroundStyle(.secondary)
            }
            if let shortcutError {
                Text(shortcutError).foregroundStyle(.red)
            }
            Button("저장") {
                guard onShortcutChange(shortcut) else {
                    shortcutError = "단축키를 등록할 수 없습니다. 다른 조합을 입력하세요."
                    return
                }
                search.applySettings(home: search.homeDictionary, size: search.windowSize, shortcut: shortcut)
                show(nil)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(keyMonitor != nil)
        }
    }

    private var historySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(copied ? "복사됨" : "JSON 복사") {
                guard let data = try? search.history.jsonData(),
                      let json = String(data: data, encoding: .utf8) else { return }
                NSPasteboard.general.clearContents()
                copied = NSPasteboard.general.setString(json, forType: .string)
            }
            .disabled(search.history.entries.isEmpty)
            if search.history.entries.isEmpty {
                Text("아직 검색 기록이 없습니다.").foregroundStyle(.secondary)
            }
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(search.history.entries) { entry in
                    Button {
                        onHistorySelection(entry)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.keyword).lineLimit(1)
                                Text(entry.searchedAt, format: .dateTime.year().month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.category.rawValue).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private func show(_ section: Section?) {
        stopRecording()
        home = search.homeDictionary
        width = String(search.windowSize.width)
        height = String(search.windowSize.height)
        shortcut = search.shortcut
        shortcutError = nil
        copied = false
        self.section = section
    }

    private func startRecording() {
        shortcutError = nil
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let captured = Shortcut.recorded(from: event) {
                shortcut = captured
                shortcutError = nil
                stopRecording()
            } else if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
            } else {
                shortcutError = "⌃, ⌥ 또는 ⌘와 함께 누를 수 있는 키를 입력하세요."
            }
            return nil
        }
    }

    private func stopRecording() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }
}
