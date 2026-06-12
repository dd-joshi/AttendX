# AttendX

Minimal, offline-first Android attendance app built with Flutter.

AttendX is designed for classrooms and groups where internet connectivity may be limited. Data is stored locally on-device, with CSV import/export and local backup/restore. An APK is provided for direct distribution.

---

## Key features

- Fast roll calls — default-present roster: tap only absentees to mark attendance.
- True offline-first — no servers, no accounts; all data stays on-device.
- CSV import/export — bulk-import students and export session/class reports as CSV.
- Local backup & restore — create and restore local backup files for data portability.
- Direct APK distribution — ideal for low-connectivity environments (APK available in Releases).
- Native components — includes C/C++ native modules (Android NDK + CMake).

---

## Requirements

- Flutter SDK (stable)
- Android SDK & Android Studio
- Android NDK (required for native C/C++ components)
- Java JDK
- Android device with Android 7.0+ recommended

---

## Installation (developers)

1. Clone the repository:

   git clone https://github.com/dd-joshi/AttendX.git

2. Enter the project and fetch dependencies:

   cd AttendX
   flutter pub get

3. If native code is used, configure the Android NDK (set ANDROID_NDK_HOME or use Android Studio SDK Manager).

4. Run or build the app:

   - Debug (run on connected device/emulator):
     flutter run

   - Build debug APK:
     flutter build apk --debug

   - Build release APK (configure signing in android/app/build.gradle or key.properties):
     flutter build apk --release

---

## Usage (user-facing)

- Create a Class (Group) and add students manually or import a CSV (columns: `name,roll[,email,phone,notes]`).
- Start a new session: verify date/time and mark Present/Absent/Late. Default-present makes marking faster — tap absentees only.
- Save sessions and view per-student or per-class reports and history.
- Export reports or sessions to CSV and create local backups to transfer between devices.

---

## Release / APK

Visit the Releases page to download the provided APK (AttendX.zip contains the APK):
https://github.com/dd-joshi/AttendX/releases/tag/v1.0.0

---

## Troubleshooting

- If build errors reference native code, verify NDK and CMake versions and run `flutter clean` then `flutter pub get`.
- If exports fail, ensure the app has storage permission on the device.

---

## Contributing

Issues and feature requests: https://github.com/dd-joshi/AttendX/issues

If you want to contribute, fork the repo, create a branch, and open a pull request with a clear description and tests where applicable.

---

## License

See LICENSE (if present) or contact the repo owner for licensing details.

---

## Contact

Project: https://github.com/dd-joshi/AttendX

