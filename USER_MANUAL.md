# AttendX — User Manual

Version: 1.0

About
------
AttendX is a minimalist, true-offline-first Android attendance app to track attendance for classes and groups without mandatory internet access.

Requirements
------------
- Android device (phone/tablet) with Android 7.0+ recommended.
- If building from source:
  - Flutter SDK (stable release compatible with this repo)
  - Android SDK & Android Studio
  - Android NDK (required for native C/C++ components)
  - Java JDK
  - Command-line: git, flutter

Installation
------------
From Play Store (if published):
- Search for “AttendX” and install.

From APK (if provided):
- Enable installation from unknown sources on the device, transfer and install the APK.

Build from source (developers):
1. Clone the repo:
   - `git clone https://github.com/dd-joshi/AttendX.git`
2. Change directory and fetch dependencies:
   - `cd AttendX`
   - `flutter pub get`
3. If native code is used, install and configure the correct Android NDK (set `ANDROID_NDK_HOME` or use Android Studio SDK Manager).
4. Build an Android debug APK:
   - `flutter build apk --debug` or run on a connected device:
   - `flutter run`
5. For a release build, follow Flutter’s release signing:
   - `flutter build apk --release` and configure signing in `android/app/build.gradle` or `key.properties`.

First run and initial setup
---------------------------
- On first launch the app may request local storage permission to save exports/backups. Grant it to enable CSV export and backups.
- Create your first "Class" (or Group). Typical fields: Class name, code/ID, optional notes.
- Add Student records or import a student list (CSV import supported if available).

Core concepts
-------------
- Class / Group: A collection of students on which you take attendance.
- Student: A person entry (name, ID/roll number, optional contact).
- Attendance session: A time-bound attendance-taking event (date/time + roster status).
- Reports / Exports: CSV or other files showing attendance history or session summaries.
- Backup / Restore: Local file backups of the app’s database.

Typical workflows
-----------------
A. Create a Class
1. Tap “Add Class” (or “+”) from the Classes screen.
2. Enter Class name and optional fields (ID, description).
3. Save.

B. Add Students (manually)
1. Open the Class and tap “Add Student”.
2. Enter name, roll/ID, and any optional fields.
3. Save. Repeat for each student.

C. Bulk-import students (CSV)
- CSV format (recommended):
  - Required columns: `name`, `roll`
  - Optional columns: `email`, `phone`, `notes`
- Example header: `name,roll,email,phone,notes`
Steps:
1. Prepare CSV on your computer or phone.
2. Transfer CSV to the device (USB, email, Drive).
3. In the Class view, choose “Import students” and select the CSV.
4. Verify mapping of columns and confirm import.

D. Start an Attendance Session
1. Open a Class and tap “New Session” or “Take Attendance”.
2. Verify date/time (adjust if necessary).
3. Use the roster to mark Present/Absent/Late:
   - Tap a student to toggle status.
   - Long-press (if supported) for bulk actions.
4. Save the session.

E. Edit Session
- From Class or History/Reports, open a saved session and use “Edit” to adjust entries.

F. View Reports / Student Summary
- Open Class → Reports/History.
- Select student to view attendance percentage, sessions attended, absences.
- Use filters: date range, specific sessions, or status.

G. Export (CSV)
1. Go to Class → Reports or Exports.
2. Choose export type: session CSV, class summary CSV, or student history CSV.
3. Select storage location (local device folder).
4. Export options may include date-range and filename.

H. Backup and Restore (local)
Backup:
1. Settings → Backup → Create Backup.
2. App creates a file (e.g., `attendx_backup_YYYYMMDD.db` or `.zip`) under device storage.
3. Copy this file to external storage or cloud.

Restore:
1. Settings → Backup → Restore.
2. Choose the backup file from device storage.
3. Confirm and wait for restore.

Settings & app preferences
--------------------------
- Default session settings: duration, default mark for new students.
- Export options: CSV separator, include headers, date format.
- Backup preferences: auto-backup schedule (if implemented), backup location.
- Notifications: reminders (if available).
- Data management: clear data or reset app (backup recommended before doing this).

Permissions & privacy
---------------------
- Storage permission: required to save exports and backups (for some Android versions).
- Camera/Bluetooth/Location: only required if the app uses QR codes, BLE beacons, or geolocation.
- Data is stored locally by default. Backups are user-controlled and can be transferred at the user's discretion.

Troubleshooting
---------------
- App crashes at startup:
  - Reboot device.
  - Update or reinstall the app.
  - If building from source: run `flutter run --verbose` and check logs; verify NDK version for native builds.
- Export/permission denied:
  - Android Settings → Apps → AttendX → Permissions → allow storage.
  - Try a different folder or use app’s internal export option.
- Backup/restore failures:
  - Ensure backup file is not corrupted and is from a compatible app version.
- CSV import issues:
  - Ensure UTF-8 encoding, correct header names, and consistent delimiter (comma).

FAQ
---
Q: Is internet required?
A: No — AttendX is designed to work offline. Internet is only needed when you manually share exports or backups.

Q: Can I sync between devices?
A: Not automatically. Transfer backups between devices to copy data.

Q: Will app updates remove my data?
A: Normal updates preserve local storage, but make a backup before major updates.

Data formats (examples)
-----------------------
- Session CSV columns: `class_name,session_date,student_name,student_roll,status,notes`
- Student import CSV columns: `name,roll,email,phone,notes`

Support & feedback
------------------
Report issues or request features at: https://github.com/dd-joshi/AttendX/issues
Include: app version/commit if built from source, device model, Android version, steps to reproduce, and logs when possible.

Developer notes
---------------
- Native build errors: verify Android NDK version and check `CMakeLists.txt` and gradle config.
- Flutter issues: run `flutter doctor`, `flutter clean`, and `flutter pub get`.

Change log
----------
- 1.0 — Initial user manual commit.
