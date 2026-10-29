# lucky65-media-keys

A macOS menu bar app, "Lucky65 Keys", for keyboards whose Fn layer sends plain F1-F12. It was written for the Lucky65 **V1** (wired, USB `0x0603:0x0351`), which has no VIA/QMK support and whose Fn+1 ... Fn+= keys arrive on the Mac as plain F1-F12, so the remap lives on the Mac: for each Fn key you choose either the plain F-key or a Magic Keyboard media key (brightness, previous / play-pause / next, mute, volume). You choose in the popover which keyboards are remapped; the Lucky65 V1 (wired) is chosen by default. Only keys pressed on a chosen keyboard are changed, so the MacBook keyboard is left alone unless you choose it. Requires macOS 13 or later. The repository also contains `keydebug`, a small command line tool that shows what a keyboard actually sends.

- [Install](#install)
- [Use](#use)
- [Security and privacy](#security-and-privacy)
- [Develop](#develop)
- [keydebug](#keydebug)
- [Findings](#findings)
- [Limits and not yet](#limits-and-not-yet)
- [Project layout](#project-layout)
- [License](#license)

## Install

There is no prebuilt download; the app is built from source. You need macOS 13+ and a Swift 6 toolchain (Xcode 16 or later).

```bash
scripts/make-app.sh
```

This builds a release binary, wraps it as `~/Applications/Lucky65 Keys.app` (a menu bar app: no Dock icon), signs it, and opens it. A running installed copy is quit first. The script reads three environment variables:

| Variable | Meaning | Default |
|----------|---------|---------|
| `APP_DIR` | directory the app is installed into | `~/Applications` |
| `SIGN_ID` | name of the code-signing identity | `-` (ad-hoc) |
| `NO_OPEN` | set to `1` to not open the app after installing | opens it |

### Permissions

Grant both to **Lucky65 Keys** under System Settings > Privacy & Security:

- **Input Monitoring**: to read which F-keys a chosen keyboard itself pressed.
- **Accessibility**: to drop the original F-key and post the media key instead.

The popover (the keyboard icon in the menu bar) shows each permission with a button that asks for it and opens the right System Settings pane. Remapping starts by itself within a second of both being granted. If both are granted but it still does not work, the popover offers a button to open the app again; macOS sometimes applies Input Monitoring only to a fresh process.

### Signing caveat

macOS ties a permission grant to the app's code signature. The default ad-hoc signature changes on every build, so **after a rebuild macOS no longer recognises the old grant, even if the toggle in System Settings still looks on.** Select "Lucky65 Keys" in the Accessibility and Input Monitoring lists, remove it with "-", and add it again.

A stable self-signed certificate avoids this:

1. Open Keychain Access > Certificate Assistant > Create a Certificate...
2. Name: for example `Lucky65 Local`. Identity Type: "Self Signed Root". Certificate Type: "Code Signing".
3. Build with it:

```bash
SIGN_ID="Lucky65 Local" scripts/make-app.sh
```

Grant the permissions once more after the first build with the new certificate; later rebuilds keep them.

## Use

Click the keyboard icon in the menu bar. The popover shows:

- the status of both permissions
- an enable switch (off: every key stays a plain F-key)
- the keyboards that are connected, each with a switch to choose it
- one picker per Fn key (F1 ... F12, with the Lucky65 label Fn+1 ... Fn+= beside it)
- "reset to defaults" (the twelve actions only; the keyboard choice stays)
- "launch at login" (only in the installed app)
- quit

The popover text is in Thai; the English meaning is given in parentheses below. Each picker offers: plain F-key ("F-key ปกติ (ไม่แปลง)"), brightness down, brightness up, previous track, play / pause, next track, mute, volume down, volume up. Volume and brightness repeat while the key is held; the other media keys do not.

### Choosing keyboards

Under "คีย์บอร์ดที่จะแปลงปุ่ม" (keyboards whose keys are remapped) the popover lists every keyboard macOS sees, with its name, its ID as `vendor:product` in hexadecimal (for example `0603:0351`) and a switch. Only keyboards that are switched on are remapped. A green dot means connected. A chosen keyboard that is not connected stays in the list, marked "ไม่ได้ต่ออยู่" (not connected), so it can be switched off. With no keyboard connected the list says "ไม่พบคีย์บอร์ด" (no keyboard found). The list is read once a second, so a keyboard shows up shortly after it is plugged in or connected.

Choose only keyboards that send plain F1-F12 when Fn is held (such as the Lucky65). The MacBook keyboard is in the list too; if you choose it, its F-keys are remapped as well. The choice is saved, and the Lucky65 V1 (wired, `0603:0351`) is chosen until you change it. The actions below are per F-key and shared by all chosen keyboards.

### Default layout

From `Layout.keys` in `Sources/mediakeys/Layout.swift`; the key names are the Lucky65's:

| Lucky65 key | Sends | Default action (popover title) |
|-------------|-------|--------------------------------|
| Fn+1 | F1 | Brightness down (ลดความสว่างจอ) |
| Fn+2 | F2 | Brightness up (เพิ่มความสว่างจอ) |
| Fn+3 | F3 | Plain F3 |
| Fn+4 | F4 | Plain F4 |
| Fn+5 | F5 | Plain F5 |
| Fn+6 | F6 | Plain F6 |
| Fn+7 | F7 | Previous track (เพลงก่อนหน้า) |
| Fn+8 | F8 | Play / pause (เล่น/หยุด) |
| Fn+9 | F9 | Next track (เพลงถัดไป) |
| Fn+0 | F10 | Mute (ปิดเสียง) |
| Fn+- | F11 | Volume down (ลดเสียง) |
| Fn+= | F12 | Plain F12, so browser dev tools keep working |

Previous and next track post the Rewind and Fast-forward media keys, which are what a Magic Keyboard sends for F7 and F9. Volume up is not in the default layout; pick it for any key.

### Getting the plain F-key

Hold **shift, ctrl, opt or cmd** with a remapped key and the app leaves the key alone, so macOS gets the plain F-key with that modifier (for example cmd+Fn+8 gives cmd+F8).

### Settings

Settings are stored in UserDefaults, domain `com.lucky65keys.app` (the installed app):

- `enabled`: a boolean; missing means on.
- `F1` ... `F12`: each holds an action name: `fKey`, `brightnessDown`, `brightnessUp`, `rewind`, `playPause`, `fastForward`, `mute`, `volumeDown` or `volumeUp`. A missing or unknown value falls back to the default.
- `keyboards`: the chosen keyboards as one comma-separated string of `vvvv:pppp` IDs (vendor ID, a colon, product ID; each four lowercase hexadecimal digits), for example `0603:0351,004c:0267`. Missing (or not a string) means `0603:0351`, the Lucky65 V1. An empty string means no keyboard, so nothing is remapped. Entries that are not well formed are ignored (capital letters and spaces around an entry are accepted). The popover writes the value back sorted and without duplicates.

The app reads them on every key press, so a change in the popover applies to the next press. They can also be set from the terminal:

```bash
defaults write com.lucky65keys.app F12 -string volumeUp
defaults write com.lucky65keys.app keyboards -string "0603:0351,004c:0267"
```

## Security and privacy

This app sees keyboard input, so here is exactly what it does with it.

- **Event tap.** To swallow an F-key and post a media key instead, the app installs an active event tap (key down and key up only). macOS therefore hands it the key events of every app, system-wide; that is how any remap works. The callback compares the key code with the twelve F-key codes and returns every other event untouched. For those twelve it also reads the auto-repeat flag and the modifier flags. It does not read the typed characters, and it does not subscribe to modifier-change or media-key events. Key codes are not stored, logged or sent anywhere.
- **Only the chosen keyboards are changed.** A key event carries no device, so the app asks the HID layer. It matches the interfaces of all keyboards (primary usage page `0x01`, usage `0x06`) and asks macOS for input values of the twelve F-key usages only (keyboard page `0x07`, usages `0x3A`-`0x45`). IOHIDManager filters every other key, on any keyboard, out before the app's callback (which checks again), so the HID side cannot see what is typed. It does receive the twelve F-key presses of keyboards that are not chosen too (the MacBook's, for example): for each press it reads the keyboard's vendor and product ID and the saved choice, and drops the press unless that keyboard is chosen. For the chosen ones all it keeps is the time of the last press of each of those twelve usages, in memory. An F-key event is remapped only if a chosen keyboard reported that same F-key within the last 100 ms. The keyboard list in the popover uses the names and IDs macOS gives for the connected keyboards (listing devices needs no permission); they are shown, never stored or sent.
- **No network access.** The code has no networking.
- **Nothing is logged or stored**, apart from the settings above in UserDefaults and, if you switch it on, the macOS login item (kept by macOS, not by the app).
- **Permissions are broader than the code.** Input Monitoring and Accessibility are all-or-nothing in macOS: they let the app receive more than it uses. The narrow behaviour described here comes from the code, not from macOS, so read it (it is small) or build it yourself before granting the permissions. The app is not notarized.

**`keydebug watch` prints every key press, system-wide**, from every keyboard and every app, including whatever you type while it runs; `--vid`/`--pid` only narrows the HID lines, not the event lines. Treat its output as sensitive. This is why `captures/*.txt` is git-ignored. Do not paste a capture anywhere without reading it first.

## Develop

```bash
swift build
swift test
```

GitHub Actions (`.github/workflows/ci.yml`) runs `swift build` and `swift test` on macOS 15 for every push and pull request.

`swift run mediakeys` (or `.build/debug/mediakeys`) starts the same app from your terminal. It then uses the **terminal app's** Accessibility and Input Monitoring permissions, so you do not need to re-grant anything after each build. Some differences from the installed app: it shows a Dock icon (no `Info.plist` marks it menu-bar-only), it has no "launch at login" switch, and it reads and writes a different defaults domain, so settings are not shared with the installed app. Quit the installed copy first so you know which one is handling the keys.

## keydebug

Shows what the keyboard sends and what macOS makes of it.

```bash
swift build
mkdir -p captures
.build/debug/keydebug list                              # HID devices macOS sees, with their usage pairs
.build/debug/keydebug watch | tee captures/watch.txt    # watch is the default command
.build/debug/keydebug post 100                          # post key code 100 (F8) once
```

```
usage: keydebug list  [--vid 0x0603] [--pid 0x0351] [--all]
       keydebug watch [--vid 0x0603] [--pid 0x0351] [--all]
       keydebug post <keycode> [--fn] [--cmd] [--opt] [--ctrl] [--shift]
```

| Command | What it does |
|---------|--------------|
| `list` | show the HID devices (and their usage pairs) macOS sees |
| `watch` | print every key press as raw HID, then as macOS events |
| `post` | post one synthetic key press (down, then up) at the HID event tap, to find out which keys macOS acts on when they come from user space |

Options for `list` and `watch`: `--vid`/`--pid` limit to one device (all its interfaces, including vendor ones); `--all` includes non-keyboard HID devices. For `post`: `<keycode>` is a macOS virtual key code (decimal or `0x` hex); `--fn --cmd --opt --ctrl --shift` set modifier flags (none by default).

### Reading `watch`

Each line starts with the seconds since the first event. A blank line separates key presses more than 400 ms apart. Auto-repeat of key events is not shown. Devices are printed as `name#id` (`vendor:product#id` when the device has no name); one keyboard exposes several HID interfaces under the same name, and the `#id` tells them apart. Attached and removed devices are printed with `+` and `-`.

| Tag | Layer | Meaning |
|-----|-------|---------|
| `HID` | IOKit HID | usage page and usage the keyboard reported, named when known |
| `RAW` | IOKit HID | the raw input report bytes (first byte = report id) |
| `EVT` | CoreGraphics event tap | what macOS made of it: key code and flags, or a media key (`systemDefined PLAY`) |

For example, Fn+5 on the Lucky65 (key-up lines left out):

```
  0.000  RAW  0x0603:0x0351#83d4  id=0  00 00 3e 00 00 00 00 00
  0.001  HID  0x0603:0x0351#83d4  0x0007:0x003E F5  value=1  [array]
  0.015  EVT  keyDown  keyCode=96 F5  flags=fn
```

What to conclude:

- `HID` shows `0x000C:0x00CD PlayPause` but no `EVT` media key: macOS drops it, a remap can fix that.
- `HID` shows a consumer usage and `EVT` shows the matching media key: the keyboard sends a real media key and macOS handles it by itself.
- `HID` shows a plain key (for example `F5`) instead of a consumer usage: the firmware sends the wrong code for Fn+5, a remap can turn it into Play/Pause.
- Nothing at all on Fn+5: the firmware swallows the key; no macOS-side tool can fix it.

### Permissions

The app that runs `keydebug` (Terminal, iTerm, ...) needs **Input Monitoring** for `watch`. Without it `watch` stops with `IOHIDManagerOpen failed (0xE00002E2)`; turn the app on and run it again. `post` needs **Accessibility**; without it macOS silently drops the posted keys (`keydebug` prints a note).

## Findings

Lucky65 on macOS, captured 2026-10-28 with `keydebug watch`.

- The Fn key sends nothing by itself; the firmware switches layer.
- Fn+1 ... Fn+= send plain F1 ... F12: keyboard usages `0x3A`-`0x45` on the boot keyboard interface (report id 0, for example Fn+5 is `00 00 3e 00 00 00 00 00`). macOS turns them into `keyDown` F1 ... F12 with key codes 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111 and the `fn` flag.
- So Play/Pause and the other media keys have to be added on the Mac, by remapping the F-keys.
- The keyboard does send consumer (media) usages for at least one key. One capture shows a native Volume Down (page `0x0C`, usage `0xEA`, report id 3, on a second HID interface of the keyboard) which macOS handled by itself, including auto-repeat. Which key sends it has not been identified yet.

## Limits and not yet

- The Lucky65's 2.4 GHz and Bluetooth modes are untested. The app has no special code for them: if they appear in the keyboard list with other IDs, choose them there. Only the wired V1 (`0603:0351`) is chosen by default.
- A key event carries no device, so if a chosen and a not chosen keyboard send the same F-key within 100 ms of each other, both presses may be remapped.
- Mission Control, Spotlight, Dictation and Do Not Disturb (the Magic Keyboard's F3-F6) are not available as actions yet, so F3-F6 stay plain F-keys. Which of them can be triggered from user space is being investigated with `keydebug post`.
- Only the twelve Fn-row keys are handled. The keyboard's own consumer keys (such as the Volume Down above) go straight to macOS and are not touched.
- The Lucky65 V1 has no VIA support, so the remap lives on the Mac: it works only while the app runs, and on another computer the keys are plain F-keys.
- The popover text is Thai only.

## Project layout

- `Package.swift`: two executables, `mediakeys` and `keydebug`, each with a test target; macOS 13
- `Sources/mediakeys/App.swift`: app entry (menu bar item); `Status` polls the permissions and the connected keyboards and starts or stops the remapper
- `Sources/mediakeys/MenuView.swift`: the popover UI
- `Sources/mediakeys/Layout.swift`: media keys, actions, the twelve Fn keys with their default actions, reading the settings
- `Sources/mediakeys/Actions.swift`: what an action does when its key is pressed
- `Sources/mediakeys/EventTap.swift`: the event tap that swallows the F-key and decides what to do with it
- `Sources/mediakeys/Keyboards.swift`: the connected keyboards, the saved choice of which to remap, and which F-keys a chosen keyboard itself just reported (HID)
- `Sources/mediakeys/MediaEvent.swift`: builds and posts the media-key event
- `Sources/keydebug/main.swift`: command line parsing and the commands
- `Sources/keydebug/HIDWatcher.swift`: `list` and the raw HID side of `watch`
- `Sources/keydebug/EventTapWatcher.swift`: the macOS event side of `watch`
- `Sources/keydebug/KeyPoster.swift`: `post`
- `Sources/keydebug/Names.swift`: usage, key code and flag names
- `Sources/keydebug/Timeline.swift`: timestamped, grouped output
- `Tests/`: unit tests for both targets
- `scripts/make-app.sh`, `scripts/Info.plist`: build and install the app bundle
- `.github/workflows/ci.yml`: build and test on GitHub Actions
- `captures/`: local recordings of `watch` (`*.txt` is git-ignored: they contain every key typed while running)

## License

MIT, see [LICENSE](LICENSE).
