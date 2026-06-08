# Changelog

All notable changes to Desktop Navigator are documented here. The format
is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/) once a 1.0
release is cut.

## [Unreleased]

### Added
- Proper `.app` bundle scaffolding with `Info.plist`, privacy manifest, and
  build scripts.
- `MIT LICENSE`, README, and CHANGELOG.
- About panel that displays the version, build, and homepage.

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
