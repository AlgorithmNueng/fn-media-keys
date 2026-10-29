import CoreGraphics

extension Action {
    /// Does what the key stands for. Media actions post the Magic Keyboard media key, Mission Control, Launchpad, Spotlight,
    /// Dictation and Do Not Disturb post their key code, and `fKey` does nothing.
    func perform(down: Bool, isRepeat: Bool) {
        if let media {
            MediaEvent.post(media, down: down, isRepeat: isRepeat)
        } else if let systemKeyCode, !isRepeat {
            // The code is none of the twelve F-key codes the tap acts on, so the posted event cannot loop back into it.
            let event = CGEvent(keyboardEventSource: nil, virtualKey: systemKeyCode, keyDown: down)
            event?.flags = .maskSecondaryFn  // always set: a nil source would inherit the modifiers held right now
            event?.post(tap: .cghidEventTap)
        }
    }
}
