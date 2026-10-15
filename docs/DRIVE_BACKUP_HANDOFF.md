# Google Drive backup implementation note

Updated: 8 October 2026

The refined Drive build uses version `1.2.2+5`. Transfer
`build/app/outputs/flutter-apk/AttendX-1.2.2+5-BackupUI.apk`. Its SHA-256 is
`48359584BE5D00C486265DEDA5DF0959703003A70B0989EF14BEA4DAE13C6C7F`.

## Delivered behavior

- AttendX remains fully usable offline. Google Drive is optional and begins
  only when the teacher taps a Drive action in Backup & restore.
- A first-use disclosure explains exactly which attendance data will go to the
  chosen Google account. Consent is stored before Android authorization begins.
- Native Android authorization requests only the private Drive app-data scope.
  Access tokens stay in memory and are never written to Hive, a file, logs, or
  a developer server.
- The app writes immutable JSON backup files to the selected account's hidden
  app-data folder. It verifies the Drive response size and MD5 before marking
  the backup successful, then keeps the newest five verified copies.
- The teacher can select and restore a cloud copy, change account, delete all
  AttendX cloud copies, or disconnect Drive. Local file backup and restore are
  retained.
- Backup reminders follow changed data. A confirmed backup clears only the
  changes that were already in that backup, so a change during upload remains
  due.

## Files

- Dart authorization bridge: lib/data/drive_authorization.dart
- Drive protocol and integrity checks: lib/data/drive_backup_service.dart
- Android Google Identity bridge: android/app/src/main/kotlin/io/github/ddjoshi/attendx/MainActivity.kt
- User flow: lib/widgets/backup_bottom_sheet.dart
- Automated protocol tests: test/drive_backup_service_test.dart
- Cloud configuration and real-device script: docs/GOOGLE_DRIVE_SETUP.md

## Remaining release work

The Google Cloud project, Drive API, `drive.appdata` scope, Android OAuth client,
and test users are configured. Backup and restore passed with a real test
account on an Android 16 phone. OAuth is still in Testing, so test users see
Google's unverified-app notice. Before public release, complete public branding,
publish the OAuth app, and register the Play app-signing SHA-1 after Play App
Signing is enabled.
