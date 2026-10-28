# lucky65-media-keys

Make the Fn-layer media keys of a Lucky65 keyboard (USB `0x0603:0x0351`) work on macOS, like a Magic Keyboard.

First step: `keydebug`, a tool that shows what the keyboard actually sends when a key is pressed, at two levels:

| Tag   | Layer | Meaning |
|-------|-------|---------|
| `HID` | IOKit HID | usage page / usage the keyboard reported, named when known |
| `RAW` | IOKit HID | the raw input report bytes (first byte = report id) |
| `EVT` | CoreGraphics event tap | what macOS made of it: key code, flags, or a media key (`systemDefined PLAY`) |

Reading it:

- `HID` shows `0x000C:0x00CD PlayPause` but no `EVT` media key: macOS drops it, a remap can fix that.
- `HID` shows a plain key (for example `F5`) instead of a consumer usage: the firmware sends the wrong code for Fn+5, a remap can turn it into Play/Pause.
- Nothing at all on Fn+5: the firmware swallows the key; no macOS-side tool can fix it.

## Run

```bash
swift build
.build/debug/keydebug list                     # keyboards macOS sees, with their usage pairs
.build/debug/keydebug watch | tee captures/watch.txt
```

Options: `--vid 0x0603 --pid 0x0351` limits to one device (all its interfaces, including vendor ones), `--all` includes non-keyboard HID devices.

Output is grouped: a blank line separates key presses more than 400 ms apart. Key auto-repeat is not shown.

### Permission

The app that runs `keydebug` (Terminal, iTerm, ...) needs **System Settings > Privacy & Security > Input Monitoring**. Without it `watch` stops with `IOHIDManagerOpen failed (0xE00002E2)`. Turn the app on and run it again.

## Test

```bash
swift test
```

## Layout

- `Sources/keydebug/HIDWatcher.swift` — `list` and the raw HID side of `watch`
- `Sources/keydebug/EventTapWatcher.swift` — the macOS event side of `watch`
- `Sources/keydebug/Names.swift` — usage, key code and flag names
- `captures/` — recorded output from real key presses
