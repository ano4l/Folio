# Folio Mobile — Native SwiftUI Replica

This is a **pixel-accurate native Swift/SwiftUI replica** of the `folio_mobile` Flutter app, built for direct deployment to a test iPhone via Xcode. It replicates the exact Apple Liquid Glass / HIG UI design and the exact simulated functionality (auth flow, document vault, grounded AI chat, deadlines, and POPIA security ledger) using 100% native iOS frameworks — no third-party dependencies required.

---

## Why Native Swift Instead of Cross-Compiling Flutter?

Xcode project files (`.xcodeproj` / `.pbxproj`) are binary-plist-adjacent formats that Xcode itself validates and regenerates on open. Since this workspace is on Windows (no Xcode available to validate the project graph), the safest and most reliable path is to hand you a **complete, ready-to-drop-in Swift source tree** plus exact step-by-step instructions to create the Xcode project shell yourself in under 2 minutes on your Mac. This guarantees the project opens cleanly with no corrupt project-file errors.

---

## Frameworks Used (all native, zero external dependencies)

| Feature | Flutter Package | Native iOS Equivalent Used Here |
|---|---|---|
| State management | `provider` (`ChangeNotifier`) | `ObservableObject` + `@Published` (`AppState.swift`) |
| Biometric login | `local_auth` | `LocalAuthentication` (`LAContext`) |
| MFA pin entry | `pinput` | Custom `PinEntryView` (SwiftUI) |
| Speech-to-text | `speech_to_text` | `Speech` framework (`SFSpeechRecognizer`) |
| Text-to-speech | `flutter_tts` | `AVFoundation` (`AVSpeechSynthesizer`) |
| File picker | `file_picker` | `fileImporter` (`UniformTypeIdentifiers`) |
| Share sheet | `share_plus` | `ShareLink` |
| Calendar | `table_calendar` | Custom `MiniCalendarView` (SwiftUI `LazyVGrid`) |
| Segmented control | `CupertinoSlidingSegmentedControl` | Native `Picker(.segmented)` |
| Frosted glass blur | Custom `BackdropFilter` | `.glassEffect` on iOS 26+, `.ultraThinMaterial` fallback (`GlassContainer.swift`) |
| Haptics | `HapticFeedback` | `.sensoryFeedback` (iOS 17+) / `UIFeedbackGenerator` (`Interactions.swift`) |

---

## Apple Design-Language Layer

The UI follows Apple's *Adopting Liquid Glass* guidance and the Human Interface Guidelines rather than reimplementing a blur by hand.

### 1. Glass is chrome, never content
`GlassContainer` is only used on surfaces that float **above** content: the top bar, the floating tab dock, the upload FAB, the AI credit meter, the chat input bar, the calendar control, and transient toasts. Everything that carries dense text — document rows, OCR output, audit entries, settings rows — uses `SurfaceCard` / `GroupedCard`, which are opaque. Apple is explicit that glass over dense text destroys legibility, and its own apps (Mail, Files) use the same split.

### 2. Three-tier glass implementation
`glassSurface(cornerRadius:tint:interactive:reduceTransparency:)` in `Widgets/GlassContainer.swift` resolves to one of three renderings:

| Condition | Rendering |
|---|---|
| **Reduce Transparency** on | Fully opaque fill + hairline border (keeps AA contrast) |
| iOS 26+ | Native `.glassEffect(_:in:)` — real refraction, specular highlight, scroll-edge adaptation |
| iOS 16–18 | `.ultraThinMaterial` + specular stroke + soft shadow |

`GlassGroup` wraps neighbouring glass in a `GlassEffectContainer` on iOS 26+, because glass cannot sample other glass — ungrouped neighbours show a visible seam.

### 3. Adaptive color and Dynamic Type
Every token in `Theme/AppTheme.swift` is either a system semantic color (`.label`, `.secondarySystemGroupedBackground`, `.separator`) or a `Color.dynamic(light:dark:)` pair keyed to Apple's system accent hues. There is no hard-coded `Color.white` left in the UI, so Dark Mode and Increase Contrast work with zero per-view branching. Text uses relative styles (`.body`, `.subheadline`, `.title2`), so every string scales with Dynamic Type; only compact chrome (badges, dock labels, PIN boxes) uses `AppFont.chrome(_:_:)` fixed metrics to protect layout at accessibility sizes.

### 4. Motion, haptics and symbols
`Widgets/Interactions.swift` centralises the compatibility shims:

- `Haptics.play(_:)` and `.hapticFeedback(_:trigger:)` — `.sensoryFeedback` on iOS 17+ so the system coalesces events and honours the user's System Haptics setting.
- `.symbolBounce(value:)` — SF Symbol bounce on state change (iOS 17+), a no-op below.
- `.numericRoll(value:)` — `.contentTransition(.numericText())` digit rolls for credits, stat counters and day countdowns, matching Fitness and Stocks.
- `PressableStyle` — the standard subtle scale/dim press response, which drops the scale change under **Reduce Motion**.

Every custom animation checks `accessibilityReduceMotion` (typing dots, MFA error shake, press states).

---

## Project Structure

```
ios/
├── README.md                          # This file
└── FolioMobile/
    ├── FolioMobileApp.swift           # @main entry point + RootView auth switch
    ├── Info.plist                     # Face ID / Mic / Speech permission strings
    ├── Models/
    │   ├── Models.swift                # FolioDocument, Deadline, AuditEntry, ChatMessage
    │   └── SeedData.swift               # Exact same seed data as Flutter app
    ├── Services/
    │   └── AppState.swift               # ObservableObject mirroring app_state.dart 1:1
    ├── Theme/
    │   └── AppTheme.swift                # Apple HIG color palette + typography
    ├── Widgets/
    │   ├── GlassContainer.swift          # Liquid Glass chrome + GlassGroup + PressableStyle
    │   ├── SurfaceCard.swift              # Opaque content layer + GroupedCard (Settings-style)
    │   ├── Interactions.swift             # Haptics, symbol bounce, numeric roll, sheet detents
    │   ├── DocTypeBadge.swift             # Frosted category pill badge
    │   └── FolioLogo.swift                # Squircle gradient app logo
    └── Screens/
        ├── LoginView.swift                # Face ID + 6-digit MFA pin screen
        ├── MainShellView.swift             # Frosted navbar + floating glass dock
        ├── DashboardView.swift              # Stats, AI prompt banner, recent items
        ├── DocumentsView.swift               # Vault list, upload sheet, detail view
        ├── AskAIView.swift                    # Chat bubbles, STT/TTS, credit sheet
        ├── DeadlinesView.swift                 # List/Calendar segmented views
        └── SecurityView.swift                   # Toggles + immutable audit ledger
```

---

## Setup Instructions (macOS + Xcode required)

> You need a Mac with **Xcode 15+** installed to build and deploy to a physical iPhone. This cannot be built on Windows.

### 1. Create a new Xcode project
1. Open **Xcode** → **File → New → Project**.
2. Choose **iOS → App**, click **Next**.
3. Set:
   - **Product Name:** `FolioMobile`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - Uncheck "Use Core Data" and "Include Tests" (not required).
4. Save it anywhere temporarily (e.g., Desktop).

### 2. Replace the generated files with this source tree
1. In Finder, delete the auto-generated `ContentView.swift` and the `*App.swift` file Xcode created.
2. Copy the entire contents of this repo's `ios/FolioMobile/` folder (all subfolders: `Models`, `Services`, `Theme`, `Widgets`, `Screens`, plus `FolioMobileApp.swift`) into your new Xcode project's `FolioMobile/` folder, replacing/merging as needed.
3. In Xcode, right-click your project's yellow folder in the Navigator → **Add Files to "FolioMobile"...** → select all the copied files/folders → ensure **"Create groups"** and your app target's checkbox are both selected → **Add**.

### 3. Merge the Info.plist permission keys
Open your project's `Info` tab (target → **Info**) and add these three keys (or merge the provided `Info.plist` directly):
- `NSFaceIDUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

### 4. Set the deployment target
- Select the project in the Navigator → target **FolioMobile** → **General** tab → set **Minimum Deployments** to **iOS 16.0** or higher (required for `.ultraThinMaterial`, `ShareLink`, and `fileImporter`).

### 5. Run on your test iPhone
1. Connect your iPhone via USB (or same Wi-Fi with wireless debugging enabled).
2. In Xcode's top toolbar, select your iPhone as the run destination.
3. Go to **Signing & Capabilities** → select your **Apple ID team** under **Team** (a free Apple ID works for local device testing; you may need to trust the developer certificate on the iPhone under **Settings → General → VPN & Device Management**).
4. Press **⌘R** (Run). The app installs and launches directly on your iPhone.

---

## Functional Parity Notes

- **Authentication**: Simulated credentials → 6-digit MFA pin (auto-verifies at 6 digits, matching the Flutter `Pinput.onCompleted`) → session state. Face ID / Touch ID uses the real `LocalAuthentication` biometric prompt on-device.
- **Document Vault**: Same 4 seeded documents, soft-delete/restore recycle bin, upload sheet using the real iOS document/photo picker (`fileImporter`), and the same dual-tab Extracted Data vs OCR Raw Text detail view using a native `Picker(.segmented)`.
- **Ask AI**: Same canned grounded-response logic (keyword-matched on bursary/fees/funding/draft topics) as `app_state.dart`'s `_buildResponse`, live on-device speech-to-text via `SFSpeechRecognizer`, and text-to-speech playback via `AVSpeechSynthesizer`.
- **Deadlines**: Same 3 seeded deadlines with severity colors, list/calendar segmented toggle, and a native calendar grid marking due dates.
- **Security**: Same MFA/Biometric/Sharing toggles and the same immutable, prepend-only audit ledger — every action (login, document view, delete, upload, AI query, credit purchase, deadline resolution) appends a new `AuditEntry`, exactly matching the Flutter `_addAuditLog` behavior.

All 4 seed documents, 3 seed deadlines, and 5 seed audit logs are transcribed exactly from `mobile/lib/models/seed_data.dart` into `ios/FolioMobile/Models/SeedData.swift`.

---

## Per-Screen Apple Interactions (and why)

### `Screens/LoginView.swift`
- Queries `LAContext.biometryType` so the button reads **Face ID** or **Touch ID** according to the actual hardware, never a guess.
- `.textContentType(.oneTimeCode)` on the PIN field enables the keyboard's SMS autofill strip; `.username` / `.password` enable Keychain autofill.
- Wrong-PIN feedback is a short horizontal shake plus `.error` haptic — the system's own passcode idiom — and it is skipped under Reduce Motion.
- Toasts render on glass rather than a hard-coded black capsule, so they read correctly in both appearances.

### `Screens/MainShellView.swift`
- The dock is a `GlassGroup` so all pills share one backdrop sample; the selection pill morphs with a `matchedGeometryEffect`-style spring, and tab changes fire `.selection` haptics.

### `Screens/DocumentsView.swift`
- Built on a `List` (never a `Form`) so rows get real swipe actions: full-swipe left to delete, swipe right to open.
- Context menus include a rich `preview:` card, the pattern Files and Photos use.
- Deletion always routes through a `confirmationDialog` that explains the action is reversible and audited.
- Search covers title, category, summary and OCR text — the same fields the retrieval layer indexes — with category filter chips beside it.
- OCR confidence is a small gauge, not just a number, so weak extractions are visible at a glance.
- The upload sheet uses `.presentationDetents([.medium, .large])` with a drag indicator, narrates its four processing stages, and blocks interactive dismissal mid-upload.

### `Screens/AskAIView.swift`
- The credit meter is a glass bar with a live capacity gauge and numeric-roll counter.
- The input bar uses `interactive: true` glass (the live warp Apple reserves for surfaces users actually touch), a growing 1–4 line `TextField`, and a pulsing halo whenever the mic is hot.
- Typing dots animate in sequence like Messages and collapse to a static row under Reduce Motion.
- `SpeechSpeaker` publishes playback state so the speaker button becomes a **stop** control instead of trapping the user in a long read-out.

### `Screens/DeadlinesView.swift`
- Deadline cards are opaque `SurfaceCard`s with a severity rail, a countdown that rolls numerically, and both a tap target and a context menu for completion.
- The calendar derives weekday initials and the first-weekday offset from `Calendar.current`, so it is correct outside en-US.

### `Screens/SecurityView.swift`
- Settings rows use the opaque grouped surface Settings.app uses, with symbol bounce and `.selection` haptics on each toggle.
- The audit ledger gains category filter chips and a copy action, while the toggles keep individual VoiceOver labels and hints rather than being collapsed into one element.
