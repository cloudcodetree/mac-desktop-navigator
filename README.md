# Desktop Navigator

A native macOS menu bar utility for switching between Mission Control Spaces,
launching Mission Control, and capturing screenshots — all from one
unobtrusive row of icons in your menu bar.

## Features

- **Clickable rectangles** — one per desktop, the current one is filled. Click
  any rectangle to switch to that desktop.
- **Screenshot button** — click the camera to start macOS's selectable-area
  screenshot. The capture goes straight to your clipboard, ready to paste.
- **Mission Control button** — click the dotted rectangle to open Mission
  Control's overview.
- **Right-click menu** — a small menu with Refresh and Quit options.
- **Auto-heal** — if you add new desktops, the corresponding rectangles and
  keyboard shortcuts appear automatically.
- **Auto-launch** — runs at login via a `launchd` LaunchAgent.

## Install

### From source (current path)

Requires Xcode Command Line Tools (Swift toolchain).

```bash
git clone https://github.com/cloudcodetree/mac-desktop-navigator.git
cd mac-desktop-navigator
./scripts/install.sh
```

The install script will:
1. Build a release binary
2. Assemble it into a `.app` bundle
3. Sign it with a code-signing identity (creates a self-signed one if you
   don't have a Developer ID)
4. Install the bundle to `~/Library/Application Support/DesktopNavigator/`
5. Register a LaunchAgent so it starts at login

After install, macOS will prompt you to grant Accessibility permission. This
is required to synthesize the `Ctrl+N` keystroke that switches desktops.

### Homebrew (planned)

Once a stable release is cut, install via:

```bash
brew tap cloudcodetree/desktop-navigator
brew install --cask desktop-navigator
```

## Usage

The menu bar shows three groups, left to right:

```
[ camera ] [ rect 1 ] [ rect 2 ] ... [ rect N ] [ mission control ]
```

- **Click a rectangle** to switch to that desktop
- **Click the camera** to start a selectable-area screenshot (cmd+v to paste)
- **Click the Mission Control rectangle** to open Mission Control
- **Right-click anywhere on the icon** to open the Refresh/Quit menu

## How it works

This app intentionally uses several macOS private APIs because the public
ones don't expose what we need. Specifically:

- **Reading the active space** uses the private `CGSGetActiveSpace` symbol.
- **Reading the list of spaces** uses `CGSCopyManagedDisplaySpaces`.
- **Switching desktops** is done by synthesizing the `Ctrl+N` keystroke via
  `CGEvent.post`, which triggers macOS's built-in "Switch to Desktop N"
  Mission Control shortcut.
- **Auto-heal** writes to `com.apple.symbolichotkeys` to enable the Mission
  Control shortcuts for newly-created desktops.

Because of the private API usage, this app cannot be distributed via the App
Store. Direct distribution (or Homebrew Cask) is the intended path.

For a deeper technical overview, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Permissions

The app needs two macOS permissions to function fully:

- **Accessibility** — required to synthesize the keystroke that switches
  desktops. Without this, clicking rectangles does nothing.
- **Screen Recording** — required on macOS 14+ for the screenshot button to
  work. macOS will prompt the first time you click the camera.

Both grants persist across app updates as long as the code signing identity
is stable.

## Uninstall

```bash
./scripts/uninstall.sh
```

This removes the LaunchAgent, stops the running process, and deletes the
installed app bundle. It does **not** remove your Accessibility/Screen
Recording grants (those are managed in System Settings).

## Build from source

```bash
swift build -c release                          # build the binary
./scripts/build-bundle.sh                       # assemble the .app bundle
./scripts/install.sh                            # install and run it
```

The bundle ends up at:
`~/Library/Application Support/DesktopNavigator/DesktopNavigator.app`

## Limits

- **9-desktop cap** — macOS only defines symbolic hotkeys for "Switch to
  Desktop 1" through "Switch to Desktop 9". The app caps at 9 to match.
- **Single display** — the keyboard shortcut for switching only targets the
  focused display, so multi-monitor switching from non-primary displays
  doesn't work yet.

## License

[MIT](LICENSE) — see the LICENSE file for details.
