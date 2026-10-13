# Changelog

All notable changes to Desktop Navigator are documented here. The format
is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/) once a 1.0
release is cut.

## [Unreleased]

### Added
- Drag-to-select screenshot picker drawn by the app itself. The camera button
  no longer relies on `screencapture -i`, whose overlay and crosshair some
  remote desktop tools (macOS Screen Sharing among them) cannot show or drive.
- Single-instance guard: launching a second copy quits the older one, so
  `launchctl kickstart`, `install.sh`, and double-clicking a fresh build never
  leave two menu bar items.
- Unit tests (`swift test`) for the picker geometry and the instance rule.
- Proper `.app` bundle scaffolding with `Info.plist`, privacy manifest, and
  build scripts.
- `MIT LICENSE`, README, and CHANGELOG.
- About panel that displays the version, build, and homepage.

### Changed
- Menu bar actions fire on mouse-up instead of mouse-down.

## [0.1.0] — 2026-06-08

Initial development release.

### Added
- Clickable rectangles in the menu bar for each Mission Control space.
- Camera button that triggers a selectable-area screenshot to clipboard.
- Mission Control button (dotted rectangle with up-arrow).
- Right-click menu with Refresh and Quit.
- Auto-heal that binds the "Switch to Desktop N" symbolic hotkeys on
  launch and whenever the space count changes.
- 1-second polling to detect desktops added or removed without a switch.
- Self-signed code signing setup so TCC permissions persist across
  rebuilds (see README).
- LaunchAgent for auto-start at login (and crash recovery via `KeepAlive`).
