# Progression Session

A fast, simple songwriting tool that lets a musician choose a key, build a
chord progression, set a BPM, and hear it loop with a synthesised guitar strum –
all offline, all on-device.

Built with **Flutter** (Dart). Single codebase for iOS and Android.

---

## Features

| Feature | Details |
|---|---|
| Key selection | All 12 chromatic roots, Major or Minor mode |
| Diatonic chords | Auto-generated from music theory (I ii iii IV V vi vii°, etc.) |
| Preset progressions | I V vi IV · I IV V · ii V I · vi IV I V |
| Progression builder | Tap chords to add, drag to reorder, set 1 / 2 / 4 measures each |
| Tempo control | BPM slider 60–180 |
| Playback | Loops continuously with one strum per measure until stopped |
| Save / Load | Up to 3 progressions saved locally (SharedPreferences) |
| Offline | No backend, no APIs, no login – everything runs on-device |

---

## Project Structure

```
lib/
├── main.dart                          # App entry point & theme
├── models/
│   └── progression.dart               # ChordEntry & SavedProgression models
├── screens/
│   ├── key_selection_screen.dart       # Screen 1 – pick key & mode
│   ├── progression_builder_screen.dart # Screen 2 – build chord sequence
│   └── playback_screen.dart           # Screen 3 – tempo, play, save/load
├── services/
│   ├── music_theory_service.dart       # Diatonic chord & Roman numeral logic
│   ├── audio_service.dart             # WAV generation & just_audio playback
│   └── storage_service.dart           # SharedPreferences persistence
└── widgets/
    ├── chord_button.dart              # Reusable chord tap button
    └── progression_tile.dart          # Chord row with measure selector
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | ≥ 3.1.0 |
| Dart | ≥ 3.1.0 (comes with Flutter) |
| Xcode | 15+ (for iOS builds) |
| Android Studio | latest (for Android builds) |

---

## Getting Started

### 1. Install Flutter

Follow the official guide: <https://docs.flutter.dev/get-started/install>

### 2. Generate platform folders

Because this project was created without `flutter create`, you need to
generate the platform-specific directories once:

```bash
cd progression_session
flutter create . --org com.progressionsession
```

This adds `android/`, `ios/`, `web/`, `test/`, etc. while keeping the
existing `lib/`, `pubspec.yaml`, and `assets/` intact.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

```bash
# On a connected device or emulator
flutter run
```

---

## Building for Release

### Android (APK / AAB)

```bash
# APK
flutter build apk --release

# App Bundle (for Google Play)
flutter build appbundle --release
```

The output will be at:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### iOS (IPA)

```bash
# Open Xcode workspace
open ios/Runner.xcworkspace

# Or build from CLI
flutter build ipa --release
```

> **Note:** You need an Apple Developer account and valid provisioning
> profile / signing certificate to build for a physical iOS device or
> submit to the App Store.

---

## Audio

The app **synthesises chord audio at runtime** – no bundled WAV files are
required. On first play, it generates a short plucked-string WAV for each
chord (root + 3rd + 5th with staggered strum and exponential decay) and
caches the files in the device's temp directory.

To swap in real acoustic guitar samples, place WAV files in `assets/audio/`
and update `AudioService` to load from assets instead of generating.

---

## Customisation Ideas

- Add more chord types (sus2, sus4, 7th chords)
- Support custom time signatures (3/4, 6/8)
- Add a metronome click option
- Allow users to import/export progressions as JSON
- Swap synthesised tones for SoundFont-based playback

---

## License

This project is provided as-is for personal use. Feel free to modify and
distribute under your own terms.
