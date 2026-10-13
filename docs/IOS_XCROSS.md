# iPhone Development on Windows

The xcross workflow builds and runs an attached iPhone debug app from Windows. Release distribution uses Flutter's macOS toolchain. Keep the Xcode archive, extracted SDK, signing credentials, and device logs outside the repository.

## Prerequisites

Install the toolchain described in the [xcross setup guide](https://github.com/arxdeus/xcross): Flutter, Swift, MSVC/Windows SDK, LLVM with the Darwin linker, and Python with pymobiledevice3. Windows USB access also needs Apple Mobile Device Support.

Download a complete Xcode `.xip` archive from [Apple Developer Downloads](https://developer.apple.com/download/all/). Use compatible toolchain versions and regenerate the Darwin SDK if the selected Swift toolchain changes.

## Prepare the Project

From the repository root:

```powershell
Push-Location mobile
flutter pub get
Pop-Location
.\scripts\ios-xcross.ps1 -Action sdk -XcodeArchive 'C:\path\to\Xcode.xip'
.\scripts\ios-xcross.ps1 -Action doctor
.\scripts\ios-xcross.ps1 -Action build
```

The build action creates an unsigned bundle without signing authentication. Doctor and run also check deployment prerequisites.

The native document plugin lives in `mobile/plugins/folio_documents/`. Local overrides under `mobile/third_party/` add SwiftPM packaging for secure storage and text-to-speech. Keep their licenses and patch notes. The helper checks that resolved native iOS plugins have SwiftPM manifests before building.

## Sign and Run

Authenticate in a local terminal:

```powershell
& "$env:LOCALAPPDATA\xcross\bin\xcross.exe" auth
```

Connect the unlocked iPhone over USB, trust the computer, and enable Developer Mode under Settings > Privacy & Security. Follow any restart prompts.

Keep the tunnel running in an Administrator PowerShell:

```powershell
.\scripts\ios-xcross.ps1 -Action tunnel
```

In a second terminal:

```powershell
.\scripts\ios-xcross.ps1 -Action run
```

To select another API:

```powershell
.\scripts\ios-xcross.ps1 -Action run -ApiUrl 'https://your-host/api'
```

Use `-Wifi` on the tunnel and run actions after device pairing when supported. Press `r` for hot reload and `R` for hot restart.

## Troubleshooting

If the phone is missing, reconnect it, unlock it, confirm trust, and check `pymobiledevice3 usbmux list`. See the [device-tool installation guide](https://github.com/doronz88/pymobiledevice3/blob/master/docs/installation.md) for USB requirements.

Debug/JIT execution needs the debugging connection. If the installed app closes when launched from its icon, start the tunnel and use the run action. After enabling Developer Mode or restarting the phone, restart the tunnel so the developer disk image is mounted. Check for `Debugger attached` and `Hot reload ready` in the run output.

A successful launch does not verify camera, OCR, PDF tools, biometrics, or performance. Follow the native-device checks in [testing](TESTING.md).
