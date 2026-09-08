# Folio Mobile — Student Financial Vault & AI Assistant

`folio_mobile` is a cross-platform Flutter application built according to **Apple Human Interface Guidelines (HIG)** and a custom **Liquid Glass Frosted Material Design System**. It provides students with an ultra-premium, secure workspace to manage funding documents, interact with grounded AI, track deadlines, and maintain POPIA security settings.

---

## Design System: Apple Liquid Glass & HIG

The mobile app incorporates Apple's design language for macOS/iOS:

- **Frosted Backdrop Blurs (`GlassContainer`)**: Built using `BackdropFilter` with `ImageFilter.blur(sigmaX: 20, sigmaY: 20)` and semi-transparent white/dark tints (`Colors.white.withValues(alpha: 0.75)`).
- **Specular Hair-Line Highlight Borders**: 0.5px–1.0px semi-transparent borders (`Colors.white.withValues(alpha: 0.8)`) mimicking light reflection on glass edges.
- **Continuous Squircle Corners**: Smooth rounded corners (`BorderRadius.circular(18)` to `32`).
- **Floating Liquid Glass Navigation Dock**: Capsule dock floating above page content with active tab highlight pills and Cupertino icons.
- **SF Pro Typography & Spacing**: Clean Inter/SF Pro typography with tight character tracking (`letterSpacing: -0.6` to `-0.2`) and subtle weight hierarchy.

---

## App Architecture & Screen Routes

The mobile app follows a clean feature-based architecture managed by `AppState` via Provider:

```
lib/
├── main.dart                   # Entry point & ChangeNotifierProvider setup
├── models/
│   ├── document.dart           # Document, Entity, and AuditLog data models
│   └── deadline.dart           # Deadline obligation model
├── services/
│   └── app_state.dart          # Reactive state management (Auth, Docs, Q&A, Security)
├── theme/
│   └── app_theme.dart          # Apple HIG color palette, text themes, and card tokens
├── widgets/
│   ├── glass_container.dart    # Reusable Liquid Glass container with backdrop blur
│   ├── doc_type_badge.dart     # Frosted document category pill badge
│   └── folio_logo.dart         # Apple squircle logo mark
└── screens/
    ├── login_screen.dart       # Biometric Face ID & 6-digit Pinput MFA screen
    ├── main_shell.dart         # Frosted AppBar header & Floating Glass Dock shell
    ├── dashboard_screen.dart   # Stats widgets, AI quick prompt banner, recent items
    ├── documents_screen.dart   # Document vault, upload sheet, Extracted vs OCR view
    ├── ask_ai_screen.dart      # Credit bar, iOS Messages chat, speech-to-text / TTS
    ├── deadlines_screen.dart   # CupertinoSlidingSegmentedControl & TableCalendar
    └── security_screen.dart    # CupertinoSwitches for MFA/Biometrics & POPIA log
```

### Route & Screen Breakdown

1. **`LoginScreen` (`/login`)**:
   - Biometric Face ID / Fingerprint verification using `local_auth`.
   - 6-digit passcode verification using `pinput`.
   - Glass form containers and Cupertino styled buttons.

2. **`MainShell` (`/shell`)**:
   - Translucent `AppBar` with blurred backdrop and profile avatar sheet.
   - Floating Liquid Glass Dock bottom bar (`_DockItem`) with active tab highlight pill.

3. **`DashboardScreen` (`index: 0`)**:
   - High-level metric cards (`Documents`, `Pending`, `Audit events`).
   - Gradient AI quick query card (`Color(0xFF007AFF)` → `Color(0xFF5856D6)`).
   - Apple Grouped List cards for recent paperwork and urgent deadlines.

4. **`DocumentsScreen` (`index: 1`)**:
   - Filterable document list with confidence badges and soft-delete recycle bin.
   - `_UploadSheet` modal with drag-and-drop / file picker (`file_picker`).
   - `DocumentDetailView` with `CupertinoSlidingSegmentedControl` switching between **Extracted Data** (Entities) and **OCR Raw Text**.

5. **`AskAiScreen` (`index: 2`)**:
   - Frosted AI credit meter header bar with top-up modal.
   - iOS Messages style chat bubbles (`_Bubble`) with source document citation chips.
   - Voice input integration (`speech_to_text`) and text-to-speech voice reader (`flutter_tts`).

6. **`DeadlinesScreen` (`index: 3`)**:
   - `CupertinoSlidingSegmentedControl` toggling between List and Calendar views.
   - Interactive `TableCalendar` widget highlighting document due dates.
   - Severity indicator bars (High: `#FF3B30`, Medium: `#FF9500`, Low: `#007AFF`).

7. **`SecurityScreen` (`index: 4`)**:
   - `CupertinoSwitch` toggles for MFA, Biometric Unlock, and Financial Aid Data Sharing.
   - Immutable POPIA Access Ledger timeline showing timestamped vault operations.

---

## Architectural & Method Choices

### Why Flutter & Cupertino Widgets over React Native or Native iOS/Android?
- **Pixel-Perfect Rendering**: Flutter's Skia/Impeller engine renders custom `BackdropFilter` glassmorphism identically across iOS, Android, and Web without OS-level view hierarchy inconsistencies.
- **Cross-Platform Parity**: A single codebase manages biometrics, local state, audio TTS/STT, and complex multi-tab navigation simultaneously.

### Why Provider (`ChangeNotifier`) for State Management?
- **Zero Boilerplate**: Provider offers a transparent reactive loop (`context.watch<AppState>()` and `context.read<AppState>()`).
- **Performance**: Fine-grained widget rebuilds without heavy stream controllers or code-generation pipelines (`build_runner`).

### Why `CupertinoSlidingSegmentedControl` for Detail Views?
- **Apple Parity**: iOS users expect sliding segmented controls for secondary view toggles rather than Material tab bars.
- **Haptic Touch Feel**: Smooth animated slide transitions when comparing AI extracted key-values against raw unedited OCR text.

---

## Running the Mobile App

### Prerequisites
- Flutter SDK `^3.7.2` or higher
- Dart SDK `^3.7.2` or higher

### Commands
```bash
# Fetch dependencies
flutter pub get

# Run static code analysis
flutter analyze

# Run unit and widget tests
flutter test

# Launch on Chrome web browser
flutter run -d chrome

# Launch on macOS desktop
flutter run -d macos
```
