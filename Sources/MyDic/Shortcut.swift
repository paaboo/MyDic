import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    private enum LegacyModifiers: String, Codable {
        case optionCommand = "⌥⌘"
        case controlCommand = "⌃⌘"
        case controlOption = "⌃⌥"
        case shiftCommand = "⇧⌘"
        case shiftOptionCommand = "⌥⇧⌘"
        case controlOptionCommand = "⌃⌥⌘"

        var carbonFlags: UInt32 {
            switch self {
            case .optionCommand: UInt32(optionKey | cmdKey)
            case .controlCommand: UInt32(controlKey | cmdKey)
            case .controlOption: UInt32(controlKey | optionKey)
            case .shiftCommand: UInt32(shiftKey | cmdKey)
            case .shiftOptionCommand: UInt32(shiftKey | optionKey | cmdKey)
            case .controlOptionCommand: UInt32(controlKey | optionKey | cmdKey)
            }
        }
    }

    private enum LegacyKey: String, Codable {
        case space = "Space"
        case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F", g = "G", h = "H", i = "I"
        case j = "J", k = "K", l = "L", m = "M", n = "N", o = "O", p = "P", q = "Q", r = "R"
        case s = "S", t = "T", u = "U", v = "V", w = "W", x = "X", y = "Y", z = "Z"

        var keyCode: UInt32 {
            let codes: [Self: Int] = [
                .space: kVK_Space, .a: kVK_ANSI_A, .b: kVK_ANSI_B, .c: kVK_ANSI_C,
                .d: kVK_ANSI_D, .e: kVK_ANSI_E, .f: kVK_ANSI_F, .g: kVK_ANSI_G,
                .h: kVK_ANSI_H, .i: kVK_ANSI_I, .j: kVK_ANSI_J, .k: kVK_ANSI_K,
                .l: kVK_ANSI_L, .m: kVK_ANSI_M, .n: kVK_ANSI_N, .o: kVK_ANSI_O,
                .p: kVK_ANSI_P, .q: kVK_ANSI_Q, .r: kVK_ANSI_R, .s: kVK_ANSI_S,
                .t: kVK_ANSI_T, .u: kVK_ANSI_U, .v: kVK_ANSI_V, .w: kVK_ANSI_W,
                .x: kVK_ANSI_X, .y: kVK_ANSI_Y, .z: kVK_ANSI_Z
            ]
            return UInt32(codes[self]!)
        }
    }

    private struct LegacyShortcut: Decodable {
        let modifiers: LegacyModifiers
        let key: LegacyKey
    }

    let keyCode: UInt32
    let carbonFlags: UInt32
    private let keyName: String

    static let standard = Self(keyCode: UInt32(kVK_Space), carbonFlags: UInt32(optionKey | cmdKey), keyName: "Space")

    static func load(from data: Data?) -> Self {
        guard let data else { return .standard }
        let decoder = JSONDecoder()
        if let saved = try? decoder.decode(Self.self, from: data) { return saved }
        if let legacy = try? decoder.decode(LegacyShortcut.self, from: data) {
            return Self(keyCode: legacy.key.keyCode, carbonFlags: legacy.modifiers.carbonFlags, keyName: legacy.key.rawValue)
        }
        return .standard
    }

    static func recorded(from event: NSEvent) -> Self? {
        let flags = event.modifierFlags
        guard !flags.intersection([.control, .option, .command]).isEmpty,
              let keyName = keyName(for: event) else { return nil }
        var carbonFlags: UInt32 = 0
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        return Self(keyCode: UInt32(event.keyCode), carbonFlags: carbonFlags, keyName: keyName)
    }

    private static func keyName(for event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "Esc"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        default:
            guard let text = event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers,
                  let scalar = text.unicodeScalars.first else { return nil }
            let value = Int(scalar.value)
            if (NSF1FunctionKey...NSF20FunctionKey).contains(value) {
                return "F\(value - NSF1FunctionKey + 1)"
            }
            guard !CharacterSet.controlCharacters.contains(scalar),
                  !(0xF700...0xF8FF).contains(value) else { return nil }
            return text.uppercased()
        }
    }

    var label: String {
        var label = ""
        if carbonFlags & UInt32(controlKey) != 0 { label += "⌃" }
        if carbonFlags & UInt32(optionKey) != 0 { label += "⌥" }
        if carbonFlags & UInt32(shiftKey) != 0 { label += "⇧" }
        if carbonFlags & UInt32(cmdKey) != 0 { label += "⌘" }
        return label + keyName
    }
}
