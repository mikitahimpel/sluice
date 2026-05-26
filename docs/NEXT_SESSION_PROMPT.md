# Handoff prompt — Sluice UI polish + menu bar icon, round 2

Paste the section under **"Prompt for next session"** into a fresh Claude Code conversation. Everything above is reference material for *you* (the human) to skim first.

---

## Current state (so the next agent doesn't have to dig)

- **Project:** Sluice — macOS menu-bar URL router. SwiftUI + AppKit. `LSUIElement: true`. macOS 14+ minimum. Bundle ID `com.mikitahimpel.sluice`. Repo at `~/Developer/sluice`. Currently shipped at v0.1.3 via brew tap (`mikitahimpel/sluice/sluice`) and GitHub Releases. Notarization pipeline works via `scripts/release.sh <version>`.

- **What just happened:** A `designer:design-builder` subagent did a substantial UI rebuild — added `Sluice/UI/Common/DesignSystem.swift` (design tokens), `Sluice/UI/Common/PaletteList.swift` (Raycast-style searchable list with arrow-key nav), rewrote `RuleEditorSheet`, `RulesTab`, `GeneralTab`, `PreferencesWindow` (sidebar nav instead of top tabs), and `MenuBarContent` (rich status row). Also redesigned the menu bar icon as a "source dot — thin diagonal line — destination dot" mark.

- **User verdict on the rebuild:**
  - Better than before, but "still doesn't look cool"
  - Animations feel buggy (state transitions, opening/closing the editor, profile picker fade-in)
  - The new menu bar icon (dot-line-dot) is **worse** than the previous attempt and needs another direction

## Hard constraints (don't relitigate these)

- **No purple-blue gradients** anywhere. The user explicitly hates them. See `~/.claude/projects/-Users-mikitahimpel/memory/feedback_no_purple_blue.md`.
- **No Y / fork / branching arrow** marks for the menu bar — rejected many times.
- **No thick filled bars** for the menu bar — rejected.
- **No dot-line-dot** for the menu bar — just rejected.
- Menu bar icon must match Apple's SF Symbol "Regular" stroke weight so it sits as a peer to Wi-Fi / Search / Battery in the menu bar.
- macOS 14+ only. Use modern SwiftUI APIs.
- Build must stay green: `xcodebuild ... build` and 43 SluiceTests pass.
- Don't touch `Sources/SluiceCore/`, `Sluice/Discovery/`, `Sluice/System/`, or any test files.
- Don't break the public surface of `AppCoordinator`. Mutate rules via `coordinator.updateRuleSet(_)`.

## References the user likes

Raycast, Linear, Things 3, Cron / Notion Calendar, Cursor, Zen Browser. Aesthetic: tight type hierarchy, restrained color, generous-but-not-bloated padding, deliberate hover/focus states, embedded searchable pickers (not dropdown buttons), polished empty states, subtle materials.

## How to validate

- Build: `cd ~/Developer/sluice && xcodegen generate && xcodebuild -project Sluice.xcodeproj -scheme Sluice -configuration Release -derivedDataPath ./build build`
- Launch: `killall Sluice 2>/dev/null; open ./build/Build/Products/Release/Sluice.app`
- Run tests: `xcodebuild test -project Sluice.xcodeproj -scheme Sluice -destination 'platform=macOS,arch=arm64'`
- Click the menu bar icon to see the dropdown; open Preferences (⌘,); click **Rules** then **Add Rule** to see the editor sheet (the surface formerly called out as worst).

## How to ship after approval

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `project.yml` (also update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for the target).
2. `./scripts/release.sh <version>` — builds, signs with Developer ID, notarizes via `xcrun notarytool` (keychain profile `Sluice-Notarization`), staples, zips to `release-artifacts/Sluice-<version>.zip`. Prints SHA256.
3. `git tag v<version> && git push origin main --tags`
4. `gh release create v<version> release-artifacts/Sluice-<version>.zip --title "Sluice v<version>" --notes "..."`
5. Update `homebrew-sluice/Casks/sluice.rb` with new `version` and `sha256`, commit + push that repo (`~/Developer/sluice/homebrew-sluice/`).

---

## Prompt for next session

```
I'm continuing work on Sluice, a macOS menu-bar URL router at ~/Developer/sluice. A previous Claude session rebuilt the Preferences UI with a Raycast/Linear aesthetic but I'm not satisfied. Three specific complaints:

1. The UI is better than before but still doesn't feel premium / "wow". It looks polished but not cool.
2. Animations feel buggy — e.g. the Chrome-profile picker fading in when target changes to Chrome, sheet open/close, hover transitions, navigation transitions.
3. The new menu bar icon (a source dot + thin diagonal line + destination dot) is worse than the previous attempt. Needs another direction.

Read docs/NEXT_SESSION_PROMPT.md in the repo for full context, hard constraints (the long list of things I've rejected), the aesthetic references I like (Raycast, Linear, Things 3, Cron, Cursor, Zen), and the ship pipeline. Then:

Step 1 — Launch the app and inspect every surface yourself:
- killall Sluice 2>/dev/null; xcodegen generate; xcodebuild -project Sluice.xcodeproj -scheme Sluice -configuration Release -derivedDataPath ./build build; open ./build/Build/Products/Release/Sluice.app
- Click the menu bar icon, navigate every screen. Take screenshots if helpful.

Step 2 — Diagnose what's "not cool" and what's "buggy" with concrete observations. Don't theorize. Look at the actual app on screen. Note specifically:
- Which animations stutter / janks / pop-in awkwardly
- Which surfaces still feel like SwiftUI defaults
- Where the type hierarchy reads as "system pref panel" instead of "modern app"
- Where the picker / list / button styling slips

Step 3 — Propose ONE confident menu-bar-icon direction. Not three options — pick one and execute it. Rules: not a Y/fork, not thick bars, not dot-line-dot, not previously rejected. Could be another SF Symbol entirely (look at Apple's catalog), or a custom template image generated via docs/assets/generate_menu_bar_icon.py. Must match SF Regular stroke weight.

Step 4 — Fix the animations. Likely root causes: .easeInOut/0.2 generic timings, AnyTransition default (.opacity), no .id() forcing rerenders, state changes that pop instead of animate. Use SwiftUI's transition APIs deliberately (slide+opacity combined, spring physics, custom curves).

Step 5 — Push the UI from "polished" to "cool". Concrete moves: micro-interactions on hover, focus ring detail, type weights tuned (semibold for emphasis, not bold), accent color presence reduced, surface elevation / shadow tuned, empty states given character.

Step 6 — Build green + 43 tests still pass + don't touch Core/Discovery/System/tests/AppCoordinator API.

Step 7 — Report back. List every file you touched, the icon direction you chose and why, the top 3 animation fixes, and how I should inspect (which view to open first). Do not bump version, commit, or push — I'll review and ship as v0.1.4 myself after I see your work.

The hard constraint list (things I've already rejected) is in docs/NEXT_SESSION_PROMPT.md — read it before guessing palette/mark.
```

---

## Notes for the next agent (if it's me again)

- The agent who did the last rebuild used `LazyVStack` over `List.onMove` because List forces chrome-heavy presentation. Reasonable; don't revert without a better answer for drag-reorder discoverability.
- The Settings scene is at `SluiceApp.swift`. Opening it needs `NSApp.activate(ignoringOtherApps: true)` BEFORE `openSettings()` — LSUIElement quirk.
- The notarization pipeline is mature, don't reinvent it. Just bump version, run `scripts/release.sh`.
- Cross-repo: the brew Cask formula lives in `~/Developer/sluice/homebrew-sluice/Casks/sluice.rb` (separate git repo, on `origin` as `mikitahimpel/homebrew-sluice`). After shipping v0.1.4, update that file with the new version + SHA256 and push.
