import AppKit
import Carbon
import ServiceManagement
import SwiftUI

struct SearchSettingsView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case home = "홈"
        case size = "창 크기"
        case shortcut = "단축키"
        case history = "검색 기록"
        case webLogin = "웹 로그인"
        case startup = "자동 실행"

        var id: Self { self }
    }

    @ObservedObject var search: SearchState
    let onShortcutChange: (Shortcut) -> Bool
    let onHistorySelection: (SearchHistory.Entry) -> Void
    let onClose: () -> Void
    let onQuit: () -> Void

    @State private var section: Section?
    @State private var home: Dictionary = .english
    @State private var width = ""
    @State private var height = ""
    @State private var shortcut = Shortcut.standard
    @State private var shortcutError: String?
    @State private var keyMonitor: Any?
    @State private var copied = false
    @State private var confirmHistoryDeletion = false
    @State private var selectedHistoryIDs: Set<UUID> = []
    @State private var clearDataConfirmation = false
    @State private var clearingData = false
    @State private var clearedData = false
    @State private var startupStatus = SMAppService.mainApp.status
    @State private var startupError: String?

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
                    case .webLogin: webLoginSettings
                    case .startup: startupSettings
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            startupStatus = SMAppService.mainApp.status
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            Divider()
            Button("MyDic 종료", action: onQuit)
                .keyboardShortcut("q", modifiers: .command)
        }
    }

    private var webLoginSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("로그인 유지", isOn: Binding(
                get: { search.remembersWebLogin },
                set: { search.setRemembersWebLogin($0) }
            ))
            .disabled(clearingData)
            Text("켜면 지원되는 사이트의 로그인 쿠키를 이 Mac에 저장합니다. 꺼도 이전에 저장한 데이터는 직접 삭제할 수 있습니다.")
                .foregroundStyle(.secondary)
            Button("저장된 웹 데이터 삭제", role: .destructive) { clearDataConfirmation = true }
                .disabled(clearingData)
                .confirmationDialog("저장된 웹 데이터를 삭제할까요?", isPresented: $clearDataConfirmation) {
                    Button("삭제", role: .destructive) {
                        clearingData = true
                        Task {
                            await search.clearWebsiteData()
                            clearingData = false
                            clearedData = true
                        }
                    }
                } message: {
                    Text("MyDic에 저장된 사이트의 로그인 쿠키와 캐시가 삭제됩니다.")
                }
            if clearingData {
                ProgressView()
            } else if clearedData {
                Text("저장된 웹 데이터를 삭제했습니다.").foregroundStyle(.secondary)
            }
        }
    }

    private var startupSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Mac 로그인 시 자동 실행", isOn: Binding(
                get: { startupStatus == .enabled || startupStatus == .requiresApproval },
                set: updateStartup
            ))
            if startupStatus == .requiresApproval {
                Text("시스템 설정의 로그인 항목에서 MyDic을 허용하세요.")
                    .foregroundStyle(.secondary)
                Button("로그인 항목 열기") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let startupError {
                Text(startupError).foregroundStyle(.red)
            }
        }
    }

    private func updateStartup(_ enabled: Bool) {
        let service = SMAppService.mainApp
        startupError = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            startupError = error.localizedDescription
        }
        startupStatus = service.status
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
                TextField("가로 (px)", text: $width)
                TextField("세로 (px)", text: $height)
            }
            if validSize == nil {
                Text("가로 440–1600px, 세로 300–1400px 범위의 정수를 입력하세요.")
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
            HStack {
                Button(copied ? "복사됨" : "JSON 복사") {
                    guard let data = try? search.history.jsonData(),
                          let json = String(data: data, encoding: .utf8) else { return }
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(json, forType: .string)
                }
                Spacer()
                Button("선택 삭제", role: .destructive) {
                    search.deleteSearchHistory(ids: selectedHistoryIDs)
                    selectedHistoryIDs.removeAll()
                    copied = false
                }
                .disabled(selectedHistoryIDs.isEmpty)
                Button(role: .destructive) {
                    confirmHistoryDeletion = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("검색 기록 전체 삭제")
                .help("검색 기록 전체 삭제")
                .confirmationDialog("검색 기록을 모두 삭제할까요?", isPresented: $confirmHistoryDeletion) {
                    Button("전체 삭제", role: .destructive) {
                        search.clearSearchHistory()
                        selectedHistoryIDs.removeAll()
                        copied = false
                    }
                }
            }
            .disabled(search.history.entries.isEmpty)
            if search.history.entries.isEmpty {
                Text("아직 검색 기록이 없습니다.").foregroundStyle(.secondary)
            }
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(search.history.entries) { entry in
                    HStack(spacing: 8) {
                        Toggle("선택: \(entry.keyword), \(entry.category.rawValue)", isOn: Binding(
                            get: { selectedHistoryIDs.contains(entry.id) },
                            set: { selected in
                                if selected {
                                    selectedHistoryIDs.insert(entry.id)
                                } else {
                                    selectedHistoryIDs.remove(entry.id)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
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
    }

    private func show(_ section: Section?) {
        stopRecording()
        home = search.homeDictionary
        width = String(search.windowSize.width)
        height = String(search.windowSize.height)
        shortcut = search.shortcut
        shortcutError = nil
        copied = false
        selectedHistoryIDs.removeAll()
        clearedData = false
        startupStatus = SMAppService.mainApp.status
        startupError = nil
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
