# Sluice architecture

## Layers

```
┌──────────────────────────────────────────────────────────┐
│  App         SluiceApp, AppDelegate                      │  URL events from OS
├──────────────────────────────────────────────────────────┤
│  Core        Router, RuleEngine, Rule, RuleStore,        │  pure Swift, no AppKit
│              RouteLog, Glob                              │  fully unit-tested
├──────────────────────────────────────────────────────────┤
│  Discovery   BrowserCatalog, AppCatalog, SourceDetector  │  AppKit / Launch Services
├──────────────────────────────────────────────────────────┤
│  System      DefaultBrowserClient, URLOpener             │  LSSetDefaultHandler,
│                                                          │  NSWorkspace.open
├──────────────────────────────────────────────────────────┤
│  UI          MenuBar + Preferences (SwiftUI)             │  no tests
└──────────────────────────────────────────────────────────┘
```

**Core lives in a Swift Package (`Sources/SluiceCore/`)** so it can be tested
without an Xcode build. The Xcode app target consumes it as a local SPM
dependency.

## Critical Info.plist settings

- `LSUIElement = YES` — menu bar app, no dock icon, **does not steal focus when
  handling a URL**, which keeps `frontmostApplication` accurate at click time.
- `CFBundleURLTypes` — register `http` and `https` schemes.
- `LSHandlerRank = Default` — eligible to be system default browser.

## Click-time data flow

1. macOS launches Sluice with URL(s) → `AppDelegate.application(_:open:)`.
2. **Immediately** call `SourceDetector.currentSourceApp()`. Implementation:
   `NSWorkspace.frontmostApplication` plus a ring buffer of recent
   `NSWorkspaceDidActivateApplicationNotification` events (covers races where
   the click is followed by an OS focus change before we get the URL).
3. `Router.route(urls:source:)` calls `RuleEngine.match` — first rule wins,
   default browser is the fallback.
4. `URLOpener.open(urls, with: bundleID)` via
   `NSWorkspace.openURLs(_:withApplicationAt:configuration:)`.
5. Append `RouteEvent` to in-memory `RouteLog` (ring buffer, ~50 entries, not
   persisted).
6. App stays alive as a menu bar agent.

## Rule model

```swift
struct Rule: Codable, Identifiable {
    let id: UUID
    var enabled: Bool
    var match: Match
    var target: String          // browser bundle ID
}

enum Match: Codable {
    case sourceApp(bundleID: String)
    case urlHost(glob: String)  // simple glob: "*", "?", literals
}

struct RuleSet: Codable {
    var version: Int            // 1
    var defaultBrowser: String  // bundle ID
    var rules: [Rule]
}
```

First-match-wins evaluation. No priority scores; ordering = priority.

## Config persistence

`~/Library/Application Support/Sluice/rules.json`, versioned for migration.
`RuleStore` is the only Core type that touches disk.

## Testing

- **Core**: pure unit tests via `swift test`. Inject fakes for `URLOpener`,
  catalogs, etc. through protocols.
- **Discovery / System**: light integration tests via XCTest target —
  validate Safari shows up in `BrowserCatalog`, etc.
- **UI**: no automated tests.

## Distribution

Direct distribution only (Mac App Store sandbox breaks Launch Services
default-handler APIs). Path:

- Dev: ad-hoc sign (`codesign --sign -`), users right-click → Open first time.
- Release: Developer ID + notarization, zip / DMG via GitHub Releases,
  optional Homebrew Cask.

## One subtlety

Calling `LSSetDefaultHandlerForURLScheme` triggers an OS confirmation prompt
since macOS 12. This is enforced by the system to block malware from silently
hijacking the default browser. Surface this in the "Set as default" UI flow.
