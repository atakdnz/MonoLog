# MonoLog

A journal-style note-taking app for Android built with Flutter. MonoLog is designed for fast, low-friction capture: entries are written like messages, organized into notebooks, and grouped by time.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue) ![Platform](https://img.shields.io/badge/Platform-Android-green) ![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- Messaging-style entry input
- Color-coded notebooks
- Time-based entry grouping and date headers
- Text and image entries
- Starred entries
- Custom display times for entries
- Global and notebook-level search
- Notebook pinning and archiving
- Trash with recovery support
- ZIP export and import
- Light and dark themes
- Optional app lock with biometrics or device passcode

## Requirements

- Flutter 3.10 or newer
- Android SDK
- Android device or emulator

## Getting Started

```bash
git clone https://github.com/atakdnz/MonoLog.git
cd MonoLog
flutter pub get
flutter run
```

## Build

```bash
flutter build apk --release
```

The release APK is generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

MonoLog follows a straightforward Flutter layout:

- `lib/models`: notebook and entry models
- `lib/database`: SQLite persistence
- `lib/providers`: application state
- `lib/screens`: app screens
- `lib/widgets`: reusable UI components
- `lib/services`: import and export logic
- `lib/utils`: shared constants and helpers

## Stack

- Flutter
- Provider
- SQLite via `sqflite`
- Material 3
- Google Fonts

## License

This project is licensed under the MIT License.
