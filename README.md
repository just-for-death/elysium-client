# Elysium Mobile Client 📱

A pristine, native Flutter mobile client for the Elysium music architecture. Designed with absolute feature parity to the PWA interface, heavily leaning into platform-aware UI concepts like deep iOS glass-morphism and Android Material You aesthetics.

## Tech Stack
- **Framework:** [Flutter](https://flutter.dev/) (Dart 3.x)
- **State Management:** [Riverpod](https://riverpod.dev/) (`hooks_riverpod`)
- **Audio Engine:** `just_audio` backed by native `audio_service` (for seamless background play & lock-screen media controls)
- **Routing:** `go_router` (Stateful parallel navigation)

---

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK (>= 3.24)
- Android Studio / Xcode for deploying to physical hardware

### Building & Running
You can run this client on Android, iOS, or straight to your Linux/macOS desktop using Flutter's native desktop bindings!

```bash
# Fetch dependencies
flutter pub get

# Run on the connected device or desktop natively
flutter run

# Build a release Android APK
flutter build apk

# Build a release unsigned iOS IPA (Requires macOS)
flutter build ipa --no-codesign
```

---

## App Configuration
The mobile app expects an Elysium server backend to query iTunes metadata, Invidious endpoints, and listenbrainz graphs.

1. Launch the app.
2. Navigate to the **Settings** tab.
3. Under **Server URL**, input your configured Elysium backend IP (e.g. `http://192.168.1.10:7771` or your public domain).
4. Tap **Connect**.

---

## Architecture details
- **Background Media:** Native Android ExoPlayer capabilities are bound through `audio_service` using our explicit foreground media intents in the AndroidManifest. The iOS backend relies on configuring `AVAudioSession` natively. 
- **Riverpod Architecture:** The core logic bypasses stateful widgets entirely using global Provider hooks, guaranteeing deterministic rendering loops inside the player component.
- **Glass-morphism UI:** We leverage the `ui.ImageFilter.blur` engine mapped deeply into Sliver app bars to authentically mimic the native iOS Apple Music / Catalyst visuals.

## License
MIT © Elysium Contributors
