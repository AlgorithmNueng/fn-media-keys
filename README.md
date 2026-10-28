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

## Findings (Lucky65 on macOS, captured 2026-10-28)

- The Fn key sends nothing by itself; the firmware switches layer.
- The 12 Fn combinations pressed in order (Fn+1 first) send plain F1 ... F12 on the boot keyboard interface: keyboard usages `0x3A`...`0x45` (Fn+5 is `00 00 3e ...`). macOS turns them into `keyDown` F1 ... F12 (key codes 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111) with the `fn` flag.
- The keyboard never sent a consumer (media) usage, although its descriptor has a consumer report. So no key is swallowed: Fn+5 is F5, and Play/Pause has to be added on the Mac side by remapping F5.

## mediakeys: the Fn row as Magic Keyboard media keys

`mediakeys` runs in the foreground and, for keys pressed on the Lucky65 only, swallows the F-key and posts the media key a Magic Keyboard would send. The MacBook keyboard is untouched: the HID layer tells the two devices apart, because a key event itself carries no device.

| Fn+ | F-key | Does |
|-----|-------|------|
| 1 | F1 | brightness down |
| 2 | F2 | brightness up |
| 7 | F7 | rewind (previous track) |
| 8 | F8 | play / pause |
| 9 | F9 | fast-forward (next track) |
| 10 | F10 | mute |
| 11 | F11 | volume down |
| 12 | F12 | volume up |

F3-F6 (Mission Control, Spotlight, Dictation, Do Not Disturb) are not mapped yet and still arrive as plain F-keys. Holding shift, ctrl, opt or cmd also lets the plain F-key through. The table is `Layout.keys` in `Sources/mediakeys/Layout.swift`.

```bash
swift build
.build/debug/mediakeys
```

Needs **Input Monitoring** (to read the Lucky65) and **Accessibility** (to swallow keys and post events) for the app that runs it.

Known limits: it only understands the Lucky65's boot-keyboard reports (the interface the F-keys arrived on in the captures); it runs in the foreground, there is no login item yet.

## keydebug: what the keyboard sends

Run it to see what a key press looks like (the section below).

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
- `Sources/mediakeys/Layout.swift` — the F-key to media-key table
- `Sources/mediakeys/LuckyKeys.swift` — which keys the Lucky65 itself reported (HID)
- `Sources/mediakeys/EventTap.swift` — swallows the F-key, posts the media key
- `Sources/mediakeys/MediaEvent.swift` — builds and posts the media-key event
- `captures/` — local recordings of `watch` (git-ignored: they contain every key typed while running)
