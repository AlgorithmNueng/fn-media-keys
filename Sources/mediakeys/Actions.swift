extension Action {
    /// Does what the key stands for. Media actions post the Magic Keyboard media key and `fKey` does nothing.
    /// Actions that are not a media key (Mission Control, Spotlight, ...) get their own branch here.
    func perform(down: Bool, isRepeat: Bool) {
        if let media { MediaEvent.post(media, down: down, isRepeat: isRepeat) }
    }
}
