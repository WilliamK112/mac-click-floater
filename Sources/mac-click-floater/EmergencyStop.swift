import AppKit

extension Notification.Name {
    static let clickFloaterEmergencyStop = Notification.Name("ClickFloaterEmergencyStop")
}

enum EmergencyStopShortcut {
    static func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let stopFlags: NSEvent.ModifierFlags = [.command, .option, .control]

        if event.keyCode == 53 { return true } // Escape
        if event.keyCode == 47 && flags.contains(stopFlags) { return true } // . with cmd+opt+ctrl
        return false
    }
}
