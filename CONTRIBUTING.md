# Contributing to Desktop Navigator

Thanks for thinking about contributing! A few notes to make the path smoother.

## Setup

```bash
git clone https://github.com/cloudcodetree/mac-desktop-navigator.git
cd mac-desktop-navigator
./scripts/install.sh
```

The install script creates a self-signed code-signing identity if you don't
already have one, builds and signs the app, installs the bundle, and starts
it via `launchd`.

If you have an Apple Developer ID, set `SIGN_IDENTITY` to override the
self-signed default:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install.sh
```

## Development loop

| What you want | Command |
|---|---|
| Quick local build (no install) | `swift build` |
| Release build (no install) | `swift build -c release` |
| Build and assemble the `.app` bundle | `./scripts/build-bundle.sh` |
| Full deploy (build + install + restart) | `./scripts/install.sh` |
| Stop and remove everything | `./scripts/uninstall.sh` |
| View runtime logs | `tail -f ~/Library/Logs/DesktopNavigator.log` |

## Code style

- 4-space indentation, no tabs
- Comments explain *why* something is non-obvious, not *what* the code is
  doing. The "what" should be self-evident from the code itself.
- Match existing patterns. The codebase is small enough that consistency is
  more valuable than personal preference.

## Pull requests

- One logical change per PR
- Add a note to `CHANGELOG.md` under `[Unreleased]`
- If you change rendering or hit-testing, manually verify the menu bar
  behavior — we have no automated UI tests yet
- If you touch the launchd plist format, run `./scripts/uninstall.sh`
  followed by `./scripts/install.sh` to confirm the migration path works

## Areas that could use help

- **Multi-monitor support** — currently we only switch desktops on the
  primary display because `Ctrl+N` only targets the focused display.
- **Preferences UI** — toggles for auto-launch, camera button, expand
  button, rectangle style.
- **App icon** — a proper designed icon. The bundle currently uses the
  macOS generic application icon.
- **Tests** — characterization tests for `DotsRenderer.hitTest` would be a
  good first contribution.
- **Apple Developer ID signing** in the GitHub Actions workflow (the
  signing/notarization blocks are commented placeholders).

## Architecture notes

See the "How it works" section of the [README](README.md) for an overview.
The code is intentionally compact (~7 source files) — a deep read takes
less than an hour.

## License

By contributing, you agree your changes will be licensed under the
[MIT License](LICENSE).
