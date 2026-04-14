import AppKit

extension Notification.Name {
    static let clickFloaterToggleRunShortcut = Notification.Name("ClickFloaterToggleRunShortcut")
    static let clickFloaterToggleFloaterShortcut = Notification.Name("ClickFloaterToggleFloaterShortcut")
}

enum ToggleRunShortcut {
    static func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == 47 && flags == [.command] // . with cmd
    }
}

enum ToggleFloaterShortcut {
    static func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
        return flags == [.command] && (event.keyCode == 44 || chars == "/" || chars == "?")
    }
}
