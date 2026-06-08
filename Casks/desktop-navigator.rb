# Homebrew Cask for DesktopNavigator.
#
# This file is the source of truth for publishing to a Homebrew tap.
# To distribute via a personal tap:
#   1. Create a repo named `homebrew-desktop-navigator` on your GitHub account.
#   2. Copy this file to that repo at `Casks/desktop-navigator.rb`.
#   3. Users install with:
#        brew tap cloudcodetree/desktop-navigator
#        brew install --cask desktop-navigator
#
# To submit to the official homebrew-cask repo, file a PR against
# https://github.com/Homebrew/homebrew-cask with this file at
# Casks/d/desktop-navigator.rb. Note: the official repo requires the app to
# be code-signed with a Developer ID and notarized.
#
# Update procedure when cutting a release:
#   1. Push the version tag (e.g., `git tag v0.2.0 && git push --tags`).
#   2. Wait for the Release workflow to complete and produce the zip.
#   3. Get the SHA256 from the release notes.
#   4. Update `version` and `sha256` below.

cask "desktop-navigator" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/cloudcodetree/mac-desktop-navigator/releases/download/v#{version}/DesktopNavigator-#{version}.zip"
  name "Desktop Navigator"
  desc "Menu bar app for switching between macOS Mission Control Spaces"
  homepage "https://github.com/cloudcodetree/mac-desktop-navigator"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "DesktopNavigator.app"

  # Files to remove when the user runs `brew uninstall --zap`.
  # Standard `brew uninstall` only removes the .app from /Applications.
  zap trash: [
    "~/Library/Application Support/DesktopNavigator",
    "~/Library/LaunchAgents/com.cloudcodetree.DesktopNavigator.plist",
    "~/Library/Logs/DesktopNavigator.log",
    "~/Library/Preferences/com.cloudcodetree.DesktopNavigator.plist",
  ]
end
