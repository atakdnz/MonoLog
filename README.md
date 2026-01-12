# MonoLog

A journal-style note-taking app for Android built with Flutter. Capture quick entries like sending messages in a chat app, with time-based organization and visual grouping.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue) ![Platform](https://img.shields.io/badge/Platform-Android-green) ![License](https://img.shields.io/badge/License-MIT-yellow)

## ✨ Features

### Core
- **Messaging-style input** - Quick entry capture like sending messages
- **Notebooks with colors** - Organize entries into color-coded notebooks
- **Time-based grouping** - Visual separation based on time gaps between entries
- **Date headers** - Clear day separators in entry timeline
- **Timestamps on every entry** - See exactly when each entry was made

### Entry Management
- **Text & image entries** - Add text, photos, or both
- **Star/favorite entries** - Mark important entries
- **Edit display time** - Backdate or forward-date entries
- **Move between notebooks** - Relocate entries as needed

### Organization
- **Pin notebooks** - Keep important notebooks at top
- **Archive notebooks** - Hide completed notebooks
- **Search globally** - Find entries across all notebooks
- **Search locally** - Filter within current notebook
- **Jump to date** - Quick navigation to specific dates

### Data Management
- **Trash with 30-day retention** - Recover deleted notebooks/entries
- **Export to ZIP** - Full backup with JSON + images
- **Import from backup** - Restore with merge/replace options
- **Dark mode** - Eye-friendly dark theme

## 📱 Screenshots

*Coming soon*

## 🚀 Getting Started

### Prerequisites
- Flutter 3.10 or higher
- Android SDK
- Android device or emulator

### Installation

```bash
# Clone the repository
git clone https://github.com/atakdnz/MonoLog.git
cd MonoLog

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Build APK

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`

## 🏗️ Architecture

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   ├── notebook.dart
│   └── entry.dart
├── database/              # SQLite operations
│   └── database_helper.dart
├── providers/             # State management
│   ├── notebooks_provider.dart
│   ├── entries_provider.dart
│   ├── trash_provider.dart
│   ├── search_provider.dart
│   └── theme_provider.dart
├── screens/               # UI screens
│   ├── home_screen.dart
│   ├── notebook_screen.dart
│   ├── entry_edit_screen.dart
│   ├── search_screen.dart
│   ├── trash_screen.dart
│   └── settings_screen.dart
├── widgets/               # Reusable widgets
│   ├── notebook_card.dart
│   ├── entry_bubble.dart
│   ├── date_header.dart
│   ├── input_bar.dart
│   └── search_result_item.dart
├── services/              # Business logic
│   ├── export_service.dart
│   └── import_service.dart
└── utils/                 # Utilities
    ├── time_utils.dart
    └── constants.dart
```

## 🔧 Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter |
| State Management | Provider |
| Database | SQLite (sqflite) |
| Typography | Google Fonts (Inter) |
| Theme | Material 3 |

## 📦 Dependencies

- `sqflite` - SQLite database
- `provider` - State management
- `path_provider` - File system access
- `image_picker` - Camera/gallery access
- `share_plus` - Share functionality
- `archive` - ZIP handling
- `file_picker` - File selection
- `google_fonts` - Typography
- `shared_preferences` - Theme persistence
- `intl` - Date formatting
- `uuid` - ID generation

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
