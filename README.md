# VoiceRemind - AI Voice-First Reminder App

A beautiful voice-first reminder application built with Flutter. VoiceRemind allows users to create reminders through natural speech and get intelligent notifications across all platforms.

## 🚀 Vision

**How it works:**
- **You speak:** "Remind me tomorrow at 8 a.m. to send the report."
- **AI listens:** Speech-to-text converts your words into text
- **AI understands:** LLM figures out date, time, and task details
- **It schedules:** Reminder syncs to the cloud and all your devices
- **It reminds you:** Push notifications with optional voice playback

## ✨ Current Features

- ✅ **Beautiful Material 3 UI** with modern design
- ✅ **Local reminder management** (create, edit, delete, mark complete)
- ✅ **Smart notifications** with cross-platform support
- ✅ **Dashboard with statistics** (total, pending, completed, overdue)
- ✅ **Repeat options** (daily, weekly, monthly)
- ✅ **Multi-platform support** (macOS, Windows, Linux, Android, iOS, Web)
- ✅ **Offline-first architecture** with local storage

## 🔄 Planned Features

- 🔮 **Voice input** with speech-to-text
- 🔮 **Natural language processing** for intelligent scheduling
- 🔮 **Text-to-speech** for voice reminders
- 🔮 **Cloud synchronization** across devices
- 🔮 **AI-powered reminder suggestions**

## 🛠️ Tech Stack

- **Framework:** Flutter 3.24.5 with Dart 3.5.0
- **UI:** Material 3 design system
- **Storage:** SharedPreferences (local), planned cloud sync
- **Notifications:** flutter_local_notifications with timezone support
- **State Management:** Built-in setState (simple and effective)
- **Architecture:** Clean, modular structure with services and models

## 🏃‍♂️ How to Run

### Prerequisites
- Flutter SDK installed and configured
- Android Studio (for Android emulator)
- VS Code or preferred IDE with Flutter extensions

### 1. Clone and Setup
```bash
git clone [repository-url]
cd voice_remind
flutter pub get
```

### 2. Check Your Setup
```bash
flutter doctor
```
Make sure all platforms you want to target show ✅

### 3. Run on Different Platforms

#### macOS Desktop
```bash
flutter run -d macos
```

#### Windows Desktop
```bash
flutter run -d windows
```

#### Linux Desktop
```bash
flutter run -d linux
```

#### Android Emulator
```bash
# First, start an emulator
flutter emulators --launch Pixel_4

# Then run the app
flutter run -d emulator-5554
```

#### Web Browser
```bash
flutter run -d chrome
```

#### iOS Simulator (macOS only)
```bash
flutter run -d apple_ios_simulator
```

### 4. Development Commands

```bash
# See available devices
flutter devices

# See available emulators
flutter emulators

# Hot reload (while app is running)
# Press 'r' in terminal

# Hot restart (while app is running)
# Press 'R' in terminal

# Clean build
flutter clean
flutter pub get
```

## 📱 Testing the App

### Core Features to Test
1. **Create Reminders**: Tap the "+ Add Reminder" button
2. **Set Notifications**: Create a reminder for 1-2 minutes from now
3. **Test Notifications**: Use the "Test Notification" button in the app bar
4. **Mark Complete**: Tap on reminders to toggle completion
5. **View Statistics**: Check the dashboard cards for counts
6. **Repeat Options**: Try creating daily/weekly reminders

### Platform-Specific Testing
- **Desktop (macOS/Windows/Linux)**: Test keyboard navigation and window resizing
- **Mobile (Android/iOS)**: Test touch interactions and notifications
- **Web**: Test responsive design and browser notifications

## 🐛 Common Issues & Solutions

### Android Build Issues
If you get NDK or desugaring errors:
```bash
flutter clean
flutter pub get
flutter run -d android
```

The project is configured with:
- NDK version 27.0.12077973
- Core library desugaring enabled
- Java 11 compatibility

### Emulator Not Found
```bash
# List available emulators
flutter emulators

# Launch specific emulator
flutter emulators --launch <emulator-id>
```

### Notification Issues
- **Android**: Ensure emulator has notification permissions
- **macOS**: Check System Preferences > Notifications
- **Web**: Browser will prompt for notification permission

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   └── reminder.dart      # Reminder model with enums
├── services/              # Business logic
│   ├── storage_service.dart     # Local data persistence
│   └── notification_service.dart # Cross-platform notifications
└── screens/               # UI screens
    ├── home_screen.dart   # Main dashboard
    └── add_reminder_screen.dart # Create/edit reminders
```

## 🎯 Development Priorities

1. **Phase 1**: Voice input integration (speech-to-text)
2. **Phase 2**: Natural language processing for smart scheduling
3. **Phase 3**: Cloud synchronization and multi-device support
4. **Phase 4**: AI-powered features and voice output

## 🤝 Contributing

1. **Pick a platform** to test on (Windows/Linux/Android)
2. **Run the app** and test all features
3. **Report issues** or suggest improvements
4. **Focus areas**: UI/UX, cross-platform compatibility, performance

## 📚 Documentation

- [Technical Project Plan](docs/VoiceRemind%20-%20Technical%20Project%20Plan%20&%20Developer%20Documentation.md) - Comprehensive development strategy
- [Flutter Documentation](https://flutter.dev/docs)
- [Material 3 Design](https://m3.material.io/)

---

**Current Status**: ✅ MVP Complete | 🔄 Voice Features In Development

*Built with ❤️ using Flutter for a zero-cost, community-driven approach*