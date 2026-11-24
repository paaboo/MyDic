import AppKit
import SwiftUI
import WebKit

@MainActor
final class SearchState: ObservableObject {
    let savedTerms = SavedTerms()
    @Published var termEditor: TermEditor?
    @Published var selectionMessage: String?
    struct WindowSize: Equatable {
        static let widthRange = 440...1600
        static let heightRange = 300...1400
        let width: Int
        let height: Int

        var contentSize: CGSize { CGSize(width: width, height: height) }
    }

    struct Lookup: Equatable {
        let url: URL
        let id = UUID()
    }

    @Published var query = ""
    @Published var focusRequest = 0
    @Published private(set) var dictionary: Dictionary
    @Published private(set) var lookup: Lookup?
    @Published private(set) var homeDictionary: Dictionary
    @Published private(set) var windowSize: WindowSize
    @Published private(set) var shortcut: Shortcut
    @Published private(set) var history: SearchHistory
    @Published private(set) var remembersWebLogin = UserDefaults.standard.bool(forKey: "remembersWebLogin")
    private var submittedQuery: String?

    init() {
        let home = UserDefaults.standard.string(forKey: "homeDictionary")
            .flatMap(Dictionary.init(rawValue:)) ?? .chatGPT
        homeDictionary = home
        dictionary = home
        shortcut = Shortcut.load(from: UserDefaults.standard.data(forKey: "shortcut"))
        history = SearchHistory.load(from: UserDefaults.standard.data(forKey: "searchHistory"))
        let width = UserDefaults.standard.integer(forKey: "windowWidth")
        let height = UserDefaults.standard.integer(forKey: "windowHeight")
        windowSize = WindowSize(
            width: WindowSize.widthRange.contains(width) ? width : 680,
            height: WindowSize.heightRange.contains(height) ? height : 800
        )
    }

    func applySettings(home: Dictionary, size: WindowSize, shortcut: Shortcut) {
        guard WindowSize.widthRange.contains(size.width),
              WindowSize.heightRange.contains(size.height) else { return }
        homeDictionary = home
        windowSize = size
        self.shortcut = shortcut
        UserDefaults.standard.set(home.rawValue, forKey: "homeDictionary")
        UserDefaults.standard.set(size.width, forKey: "windowWidth")
        UserDefaults.standard.set(size.height, forKey: "windowHeight")
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: "shortcut")
        }
    }

    func goHome() {
        close()
        query = ""
        select(homeDictionary)
        lookup = Lookup(url: dictionary.homeURL)
    }

    func prepareToOpen() {
        guard lookup == nil else { return }
        select(homeDictionary)
    }

    func setRemembersWebLogin(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "remembersWebLogin")
        remembersWebLogin = enabled
    }

    func clearWebsiteData() async {
        close()
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
    }

    func select(_ dictionary: Dictionary) {
        self.dictionary = dictionary
        UserDefaults.standard.set(dictionary.rawValue, forKey: "selectedDictionary")
        if let submittedQuery {
            load(submittedQuery)
        } else {
            lookup = Lookup(url: dictionary.homeURL)
        }
    }

    func submit() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        submittedQuery = term
        load(term)
    }

    func reopen(_ entry: SearchHistory.Entry) {
        close()
        select(entry.category)
        query = entry.keyword
        submit()
    }

    func editCurrentTerm() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        let existing = savedTerms.entries.first {
            $0.keyword.caseInsensitiveCompare(keyword) == .orderedSame && $0.category == dictionary
        }
        termEditor = TermEditor(term: existing ?? SavedTerm(
            id: UUID(), keyword: keyword, meaning: "", memo: "", category: dictionary,
            sourceURL: dictionary.searchURL(for: keyword) ?? dictionary.homeURL, updatedAt: .now
        ))
    }

    func clearSearchHistory() {
        history = SearchHistory()
        persistSearchHistory()
    }

    func deleteSearchHistory(ids: Set<UUID>) {
        history.remove(ids: ids)
        persistSearchHistory()
    }

    func close() {
        lookup = nil
        submittedQuery = nil
    }

    private func load(_ term: String) {
        guard let url = dictionary.searchURL(for: term) else { return }
        if dictionary == .gemini {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(term, forType: .string)
            selectionMessage = "검색어를 복사했습니다. Gemini 입력창에 붙여넣어 전송하세요."
        } else {
            selectionMessage = nil
        }
        lookup = Lookup(url: url)
        history.record(term, category: dictionary, sourceURL: url)
        persistSearchHistory()
    }

    private func persistSearchHistory() {
        if history.entries.isEmpty {
            UserDefaults.standard.removeObject(forKey: "searchHistory")
        } else if let data = try? history.jsonData() {
            UserDefaults.standard.set(data, forKey: "searchHistory")
        }
    }
}

struct SearchView: View {
    @ObservedObject var search: SearchState
    let onShortcutChange: (Shortcut) -> Bool
    let onResize: (CGSize) -> Void
    let onQuit: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        search.goHome()
                        searchFocused = true
                    } label: {
                        Image(systemName: "house")
                    }
                    .buttonStyle(.plain)
                    .help("홈")
                    .accessibilityLabel("홈")
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("검색어 입력", text: $search.query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onSubmit(search.submit)
                    if !search.query.isEmpty {
                        Button {
                            search.query = ""
                            searchFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("검색어 지우기")
                        .help("검색어 지우기")
                    }
                    Button("검색", action: search.submit)
                        .disabled(search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { search.editCurrentTerm() } label: {
                        Image(systemName: "bookmark")
                    }
                    .buttonStyle(.plain)
                    .help("용어 저장")
                    .accessibilityLabel("용어 저장")
                    .disabled(search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("설정")
                    .help("설정")
                    .keyboardShortcut(",", modifiers: .command)
                }
                .padding(9)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) { categories }
                        .onChange(of: search.dictionary, initial: true) { _, dictionary in
                            let target = visibleCategories.contains(dictionary) ? dictionary : (overflowCategories.first ?? dictionary)
                            proxy.scrollTo(target)
                        }
                }
            }
            .padding(12)

            Divider()
            if let lookup = search.lookup {
                ResultView(lookup: lookup, remembersWebLogin: search.remembersWebLogin)
                    .id(search.remembersWebLogin)
            } else {
                VStack(spacing: 7) {
                    Text("예시 검색어")
                        .foregroundStyle(.secondary)
                    Button(search.dictionary.example) {
                        search.query = search.dictionary.example
                        search.submit()
                    }
                    .buttonStyle(.link)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()

            HStack {
                Text("MyDic")
                    .fontWeight(.semibold)
                Text("·")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Link(search.dictionary.source, destination: search.lookup?.url ?? search.dictionary.homeURL)
                    .help("브라우저에서 열기")
                Spacer()
                Link("개발문의 : redinboo@gmail.com", destination: URL(string: "mailto:redinboo@gmail.com")!)
            }
            .font(.caption)
            .padding(10)
        }
        .allowsHitTesting(!showingSettings)
        .disabled(showingSettings)
        .accessibilityHidden(showingSettings)
        .overlay {
            if showingSettings {
                SearchSettingsView(
                    search: search,
                    onShortcutChange: onShortcutChange,
                    onHistorySelection: { entry in
                        showingSettings = false
                        search.reopen(entry)
                    },
                    onClose: { showingSettings = false },
                    onQuit: onQuit
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
        .frame(width: search.windowSize.contentSize.width, height: search.windowSize.contentSize.height)
        .overlay {
            if let editor = search.termEditor {
                TermEditorView(store: search.savedTerms, term: editor.term, onClose: { search.termEditor = nil })
                    .id(editor.id)
            }
        }
        .onAppear { searchFocused = true }
        .onChange(of: search.focusRequest) { _, _ in
            showingSettings = false
            searchFocused = true
        }
        .onChange(of: search.windowSize) { _, size in onResize(size.contentSize) }
    }

    private var visibleCategories: [Dictionary] {
        Array(Dictionary.allCases.prefix(through: Dictionary.allCases.firstIndex(of: .scholarly)!))
    }

    private var overflowCategories: [Dictionary] {
        Array(Dictionary.allCases.dropFirst(visibleCategories.count))
    }

    private var categories: some View {
        HStack(spacing: 4) {
            ForEach(Array(visibleCategories.enumerated()), id: \.element) { index, dictionary in
                let selected = search.dictionary == dictionary
                Button {
                    search.select(dictionary)
                    searchFocused = true
                } label: {
                    Text(dictionary.rawValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.16))
                            }
                        }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            if let firstOverflow = overflowCategories.first {
                Menu {
                    ForEach(Array(overflowCategories.enumerated()), id: \.element) { index, dictionary in
                        Button {
                            search.select(dictionary)
                            searchFocused = true
                        } label: {
                            if search.dictionary == dictionary {
                                Label(dictionary.rawValue, systemImage: "checkmark")
                            } else {
                                Text(dictionary.rawValue)
                            }
                        }
                        .keyboardShortcut(overflowShortcut(index))
                    }
                } label: {
                    Text("더보기")
                        .foregroundStyle(overflowCategories.contains(search.dictionary) ? Color.accentColor : Color.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .id(firstOverflow)
            }
        }
    }

    private func overflowShortcut(_ index: Int) -> KeyboardShortcut? {
        let number = visibleCategories.count + index + 1
        return number <= 9 ? KeyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .command) : nil
    }
}

private struct ResultView: View {
    let lookup: SearchState.Lookup
    let remembersWebLogin: Bool
    @State private var loading = true
    @State private var failed = false
    @State private var retry = 0

    var body: some View {
        ZStack {
            ResultWebView(
                lookup: lookup, retry: retry, remembersWebLogin: remembersWebLogin,
                loading: $loading, failed: $failed
            )
            if loading {
                ProgressView("불러오는 중…")
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            } else if failed {
                VStack(spacing: 9) {
                    Text("검색 페이지를 불러오지 못했습니다.")
                    Button("다시 시도") { retry += 1 }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct ResultWebView: NSViewRepresentable {
    let lookup: SearchState.Lookup
    let retry: Int
    let remembersWebLogin: Bool
    @Binding var loading: Bool
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(loading: $loading, failed: $failed)
    }

    func makeNSView(context: Context) -> ResultWebContainer {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = remembersWebLogin ? .default() : .nonPersistent()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        let hideLogin = WKUserScript(source: """
            (() => {
                if (location.hostname !== 'chatgpt.com') return;
                const style = document.createElement('style');
                style.textContent = `
                    header [data-testid="login-button"],
                    header a[href^="/auth/login"],
                    header a[href^="https://chatgpt.com/auth/login"],
                    [data-testid="login-button"] { display: none !important; }
                `;
                document.documentElement.appendChild(style);
                const hide = () => {
                    const signupButtons = document.querySelectorAll('button, a');
                    for (const button of signupButtons) {
                        if (!/^(무료로 회원가입|무료 회원가입|Sign up for free)$/i.test((button.textContent || '').trim())) continue;
                        // Match the promotional card by its copy, without hiding chat messages.
                        let card = button.parentElement;
                        for (let depth = 0; card && depth < 5; depth++, card = card.parentElement) {
                            if (card.matches('main, body, form, [role="dialog"], [data-message-author-role]')) break;
                            const text = card.textContent || '';
                            const matchesCopy = /이 채팅을 저장하려면|to save this chat|save (?:your|this) (?:chat|conversation)/i.test(text);
                            if (matchesCopy && text.length < 1200 &&
                                !card.querySelector('[data-message-author-role], [contenteditable="true"], textarea')) {
                                card.style.setProperty('display', 'none', 'important');
                                break;
                            }
                        }
                    }
                    const elements = document.querySelectorAll(
                        'header button, header a, [role="banner"] button, [role="banner"] a, button[data-testid="login-button"], a[href*="/auth/login"]'
                    );
                    // Some versions of the guest page render its top controls outside a header.
                    const candidates = new Set([...elements, ...document.querySelectorAll('button')]);
                    for (const element of candidates) {
                        if (!/^(로그인|Log in|Login|Sign in)$/i.test((element.textContent || '').trim())) continue;
                        if (element.closest('[role="dialog"], [aria-modal="true"], form')) continue;
                        element.style.setProperty('display', 'none', 'important');
                        requestAnimationFrame(() => {
                            if (element.isConnected && element.getClientRects().length > 0) element.remove();
                        });
                    }
                };
                let pending = false;
                new MutationObserver(() => {
                    if (pending) return;
                    pending = true;
                    requestAnimationFrame(() => { pending = false; hide(); });
                }).observe(document.documentElement, { childList: true, subtree: true });
                hide();
            })();
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(hideLogin)
        let acceptCookies = WKUserScript(source: """
            (() => {
                if (location.hostname !== 'chatgpt.com') return;
                const accept = () => {
                    const choices = document.querySelectorAll(
                        '[role="dialog"] button, [aria-modal="true"] button, #onetrust-banner-sdk button'
                    );
                    for (const button of choices) {
                        const text = (button.textContent || '').trim();
                        if (!/^(모두 허용|모두 수락|Accept all|Allow all|Accept all cookies)$/i.test(text)) continue;
                        const dialog = button.closest('[role="dialog"], [aria-modal="true"], #onetrust-banner-sdk');
                        if (!dialog || !/쿠키|cookies?/i.test(dialog.textContent || '')) continue;
                        if (button.disabled || button.getClientRects().length === 0) continue;
                        button.click();
                        return;
                    }
                };
                let scheduled = false;
                const observer = new MutationObserver(() => {
                    if (scheduled) return;
                    scheduled = true;
                    requestAnimationFrame(() => { scheduled = false; accept(); });
                });
                observer.observe(document.documentElement, { childList: true, subtree: true });
                accept();
            })();
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(acceptCookies)
        let view = WKWebView(frame: .zero, configuration: configuration)
        // Providers that select a layout on the server need a mobile user agent.
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        let container = ResultWebContainer(webView: view)
        context.coordinator.container = container
        return container
    }

    func updateNSView(_ container: ResultWebContainer, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.lookup != lookup || coordinator.retry != retry else { return }
        container.dismissLogin(reload: false)
        coordinator.lookup = lookup
        coordinator.retry = retry
        let view = container.webView
        view.stopLoading()
        view.load(URLRequest(url: lookup.url, timeoutInterval: 20))
    }

    static func dismantleNSView(_ container: ResultWebContainer, coordinator: Coordinator) {
        container.dismissLogin(reload: false)
        let view = container.webView
        view.navigationDelegate = nil
        view.uiDelegate = nil
        view.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var loading: Bool
        @Binding var failed: Bool
        var lookup: SearchState.Lookup?
        var retry = 0
        weak var container: ResultWebContainer?
        private var activeNavigation: WKNavigation?

        init(loading: Binding<Bool>, failed: Binding<Bool>) {
            _loading = loading
            _failed = failed
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            activeNavigation = navigation
            failed = false
            loading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard navigation === activeNavigation else { return }
            loading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webView.navigationDelegate?.webView?(webView, didFail: navigation, withError: error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard navigation === activeNavigation, (error as NSError).code != NSURLErrorCancelled else { return }
            loading = false
            failed = true
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loading = false
            failed = true
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url, url.scheme == "https" else { return nil }
            if url.host == "nid.naver.com",
               let origin = navigationAction.sourceFrame.request.url,
               origin.scheme == "https",
               let host = origin.host,
               ["en.dict.naver.com", "ko.dict.naver.com", "hanja.dict.naver.com"].contains(host)
            {
                return container?.showLogin(configuration: configuration, delegate: self)
            }
            webView.load(navigationAction.request)
            return nil
        }

        func webViewDidClose(_ webView: WKWebView) {
            if container?.loginWebView === webView {
                container?.dismissLogin(reload: true)
            }
        }
    }
}

private final class ResultWebContainer: NSView {
    let webView: WKWebView
    private(set) var loginWebView: WKWebView?
    private var loginPanel: NSStackView?

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        fill(with: webView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func showLogin(configuration: WKWebViewConfiguration, delegate: WKUIDelegate) -> WKWebView {
        dismissLogin(reload: false)
        // WebKit supplies the popup configuration with the originating data store.
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.customUserAgent = webView.customUserAgent
        popup.uiDelegate = delegate
        let back = NSButton(title: "사전으로 돌아가기", target: self, action: #selector(closeLogin))
        let panel = NSStackView(views: [back, popup])
        panel.orientation = .vertical
        panel.spacing = 6
        panel.alignment = .leading
        panel.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 0, right: 8)
        webView.isHidden = true
        loginWebView = popup
        loginPanel = panel
        fill(with: panel)
        popup.widthAnchor.constraint(equalTo: panel.widthAnchor, constant: -16).isActive = true
        window?.makeFirstResponder(popup)
        return popup
    }

    func dismissLogin(reload: Bool) {
        guard let loginWebView else { return }
        loginWebView.uiDelegate = nil
        loginWebView.stopLoading()
        loginPanel?.removeFromSuperview()
        self.loginWebView = nil
        loginPanel = nil
        webView.isHidden = false
        if reload { webView.reload() }
    }

    @objc private func closeLogin() {
        dismissLogin(reload: true)
    }

    private func fill(with view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
