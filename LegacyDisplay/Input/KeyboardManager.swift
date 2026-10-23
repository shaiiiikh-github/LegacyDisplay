import UIKit

public protocol KeyboardManagerDelegate: AnyObject {
    func keyboardManager(_ manager: KeyboardManager, sendKeyEvent down: Bool, keySym: UInt32)
}

/// Native UIKit keyboard manager with auxiliary key bar (Section 9, Phase Five).
public final class KeyboardManager: NSObject, UIKeyInput {

    public weak var delegate: KeyboardManagerDelegate?

    // Active modifier states
    public private(set) var isCtrlActive = false
    public private(set) var isAltActive = false
    public private(set) var isShiftActive = false

    // UIKeyInput conformance
    public var hasText: Bool { return true }
    public var autocapitalizationType: UITextAutocapitalizationType = .none
    public var autocorrectionType: UITextAutocorrectionType = .no
    public var spellCheckingType: UITextSpellCheckingType = .no
    public var keyboardType: UIKeyboardType = .asciiCapable
    public var returnKeyType: UIReturnKeyType = .default

    // Standard X11 keysym definitions (RFC 6143 / X11 key mapping)
    public struct KeySym {
        public static let backspace: UInt32 = 0xFF08
        public static let tab: UInt32       = 0xFF09
        public static let enter: UInt32     = 0xFF0D
        public static let escape: UInt32    = 0xFF1B
        public static let left: UInt32      = 0xFF51
        public static let up: UInt32        = 0xFF52
        public static let right: UInt32     = 0xFF53
        public static let down: UInt32      = 0xFF54
        public static let shiftLeft: UInt32 = 0xFFE1
        public static let ctrlLeft: UInt32  = 0xFFE3
        public static let altLeft: UInt32   = 0xFFE9
    }

    public func insertText(_ text: String) {
        for char in text.utf16 {
            let sym = UInt32(char)
            sendKeyPress(keySym: sym)
        }
    }

    public func deleteBackward() {
        sendKeyPress(keySym: KeySym.backspace)
    }

    public func sendKeyPress(keySym: UInt32) {
        // Send key down
        delegate?.keyboardManager(self, sendKeyEvent: true, keySym: keySym)
        // Send key up
        delegate?.keyboardManager(self, sendKeyEvent: false, keySym: keySym)
    }

    // MARK: - Modifier Toggle and Shortcuts

    public func toggleCtrl() -> Bool {
        isCtrlActive.toggle()
        delegate?.keyboardManager(self, sendKeyEvent: isCtrlActive, keySym: KeySym.ctrlLeft)
        return isCtrlActive
    }

    public func toggleAlt() -> Bool {
        isAltActive.toggle()
        delegate?.keyboardManager(self, sendKeyEvent: isAltActive, keySym: KeySym.altLeft)
        return isAltActive
    }

    public func toggleShift() -> Bool {
        isShiftActive.toggle()
        delegate?.keyboardManager(self, sendKeyEvent: isShiftActive, keySym: KeySym.shiftLeft)
        return isShiftActive
    }

    public func sendShortcut(_ name: String) {
        switch name {
        case "Ctrl+C":
            sendCombination(modifiers: [KeySym.ctrlLeft], key: UInt32(UnicodeScalar("c").value))
        case "Ctrl+V":
            sendCombination(modifiers: [KeySym.ctrlLeft], key: UInt32(UnicodeScalar("v").value))
        case "Ctrl+L":
            sendCombination(modifiers: [KeySym.ctrlLeft], key: UInt32(UnicodeScalar("l").value))
        case "Ctrl+Alt+T": // Open terminal on Raspberry Pi LXDE
            sendCombination(modifiers: [KeySym.ctrlLeft, KeySym.altLeft], key: UInt32(UnicodeScalar("t").value))
        default:
            break
        }
    }

    private func sendCombination(modifiers: [UInt32], key: UInt32) {
        for m in modifiers {
            delegate?.keyboardManager(self, sendKeyEvent: true, keySym: m)
        }
        delegate?.keyboardManager(self, sendKeyEvent: true, keySym: key)
        delegate?.keyboardManager(self, sendKeyEvent: false, keySym: key)
        for m in modifiers.reversed() {
            delegate?.keyboardManager(self, sendKeyEvent: false, keySym: m)
        }
    }

    public func releaseAllModifiers() {
        if isCtrlActive {
            isCtrlActive = false
            delegate?.keyboardManager(self, sendKeyEvent: false, keySym: KeySym.ctrlLeft)
        }
        if isAltActive {
            isAltActive = false
            delegate?.keyboardManager(self, sendKeyEvent: false, keySym: KeySym.altLeft)
        }
        if isShiftActive {
            isShiftActive = false
            delegate?.keyboardManager(self, sendKeyEvent: false, keySym: KeySym.shiftLeft)
        }
    }
}
