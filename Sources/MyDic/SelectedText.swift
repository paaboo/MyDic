import AppKit
import ApplicationServices

enum SelectedText {
    @MainActor
    static func capture() async -> String? {
        if let text = read() { return text }
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else { return nil }
        let allowed = UserDefaults.standard.string(forKey: "clipboardFallbackApps") ?? ""
        guard allowed.components(separatedBy: .whitespacesAndNewlines).contains(bundleID) else { return nil }
        // The trigger may still be held. Let the user's modifiers release before Cmd+C.
        for _ in 0..<40 {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).isEmpty { break }
            try? await Task.sleep(for: .milliseconds(25))
        }
        guard CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).isEmpty,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return nil }
        let pasteboard = NSPasteboard.general
        let original = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []
        let count = pasteboard.changeCount
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else { return nil }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(app.processIdentifier)
        try? await Task.sleep(for: .milliseconds(30))
        up.postToPid(app.processIdentifier)
        for _ in 0..<25 {
            try? await Task.sleep(for: .milliseconds(40))
            if pasteboard.changeCount != count {
                let copiedCount = pasteboard.changeCount
                let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if pasteboard.changeCount == copiedCount {
                    pasteboard.clearContents()
                    let items = original.map { values in
                        let item = NSPasteboardItem()
                        for (type, data) in values { item.setData(data, forType: type) }
                        return item
                    }
                    pasteboard.writeObjects(items)
                }
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return nil }
                return text?.isEmpty == false ? text : nil
            }
        }
        return nil
    }

    static func read() -> String? {
        guard AXIsProcessTrusted(),
              let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }

        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.3)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) != .success {
            var range: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
                  let range,
                  AXUIElementCopyParameterizedAttributeValue(
                    element, kAXStringForRangeParameterizedAttribute as CFString, range, &value
                  ) == .success else { return nil }
        }
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
