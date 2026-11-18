import AppKit
import Carbon
import SwiftUI

@main
struct MyDicApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let search = SearchState()
    private let hotKey = GlobalShortcut()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.image = Self.makeStatusIcon()
        item.button?.setAccessibilityLabel("MyDic")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        hotKey.action = { [weak self] in self?.toggle() }
        if !updateShortcut(search.shortcut) {
            item.button?.toolTip = "MyDic · 전역 단축키를 등록할 수 없음"
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.unregister()
    }

    private static func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            NSColor.black.setStroke()
            let cover = NSBezierPath(
                roundedRect: NSRect(x: 1.75, y: 1.5, width: 14.5, height: 15),
                xRadius: 2.5, yRadius: 2.5
            )
            cover.lineWidth = 1.4
            cover.stroke()

            let pageEdge = NSBezierPath()
            pageEdge.move(to: NSPoint(x: 2.2, y: 4.3))
            pageEdge.line(to: NSPoint(x: 15.8, y: 4.3))
            pageEdge.lineWidth = 1.15
            pageEdge.stroke()

            let lettering = NSAttributedString(string: "Aa", attributes: [
                .font: NSFont(name: "Georgia-Bold", size: 9.5) ?? NSFont.boldSystemFont(ofSize: 9.5),
                .foregroundColor: NSColor.black
            ])
            lettering.draw(at: NSPoint(x: bounds.midX - lettering.size().width / 2, y: 4.1))
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func toggle() {
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let panel = popover ?? makePopover()
        NSApp.activate(ignoringOtherApps: true)
        panel.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        alignBelowMenuBar()
        panel.contentViewController?.view.window?.makeKey()
        search.focusRequest += 1
    }

    private func alignBelowMenuBar() {
        guard let window = popover?.contentViewController?.view.window,
              let screen = statusItem?.button?.window?.screen ?? window.screen else { return }
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: screen.visibleFrame.maxY))
    }

    private func updateShortcut(_ shortcut: Shortcut) -> Bool {
        guard hotKey.register(shortcut) else { return false }
        statusItem?.button?.toolTip = "MyDic (\(shortcut.label))"
        return true
    }

    private func makePopover() -> NSPopover {
        let panel = NSPopover()
        panel.behavior = .transient
        panel.delegate = self
        panel.contentViewController = NSHostingController(
            rootView: SearchView(
                search: search,
                onShortcutChange: { [weak self] in self?.updateShortcut($0) ?? false },
                onResize: { [weak self] size in
                    self?.popover?.contentSize = size
                    self?.alignBelowMenuBar()
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        panel.contentSize = search.windowSize.contentSize
        popover = panel
        return panel
    }

    func popoverDidClose(_ notification: Notification) {
        search.close()
    }
}

@MainActor
private final class GlobalShortcut {
    private var handler: EventHandlerRef?
    private var registration: EventHotKeyRef?
    private var shortcut: Shortcut?
    private var registrationID: UInt32 = 0
    var action: (() -> Void)?

    func register(_ shortcut: Shortcut) -> Bool {
        if let current = self.shortcut,
           current.keyCode == shortcut.keyCode, current.carbonFlags == shortcut.carbonFlags { return true }
        guard handler != nil || installHandler() else { return false }

        let nextID = registrationID &+ 1
        let id = EventHotKeyID(signature: 0x4D594449, id: nextID) // MYDI
        var nextRegistration: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonFlags, id,
            GetApplicationEventTarget(), 0, &nextRegistration
        )
        guard status == noErr, let nextRegistration else { return false }

        if let registration { UnregisterEventHotKey(registration) }
        registration = nextRegistration
        registrationID = nextID
        self.shortcut = shortcut
        return true
    }

    private func installHandler() -> Bool {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            // The application event target dispatches on the main event loop.
            MainActor.assumeIsolated {
                Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().action?()
            }
            return noErr
        }, 1, &event, context, &handler)

        return handlerStatus == noErr
    }

    func unregister() {
        if let registration { UnregisterEventHotKey(registration) }
        if let handler { RemoveEventHandler(handler) }
        registration = nil
        shortcut = nil
        handler = nil
        action = nil
    }
}
