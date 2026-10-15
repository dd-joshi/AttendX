# AttendX — Handover Note

_Last updated: 2026-10-08 after live Google Drive backup/restore testing and UI refinement._

## 1. Product scope

AttendX is an Android-first Flutter attendance app for faculty. Classes,
rosters, attendance, and preferences live in local Hive boxes and work without
an AttendX account or internet connection. Users share CSV through Android's
share sheet, save JSON backups through its destination picker, or optionally
tap to save and restore a private Google Drive app-data backup.

The app has no developer-operated network service, AttendX login, analytics,
or tracking. Google Drive access is direct from the device, only after an
explicit user action and consent; no token is persisted. Android system backup
can copy the three Hive files when encryption requirements are met; phone
transfer is supported too. JSON **Backup & restore** remains available because
a current system backup is not guaranteed. See `RELEASE_REVIEW.md`.

## 2. Data and compatibility

Hive boxes:

- `class_box`: `ClassEntry` records keyed by `classId`.
- `snapshot_box`: saved attendance records.
- `settings_box`: UI preferences and backup reminder state.

The settings box also contains the optional Drive email, consent flag, last
verified backup time, and pending-change count. It contains no Drive token.

New classes receive an internal UUID. Older class IDs remain valid and do not
need migration.

`SnapshotEntry` keeps one record per class, date, and class type. Hive field
numbers 7 and 8 are retired; do not reuse them. Field 9 stores the optional
topic. Older Hive records and JSON backups may contain the retired fields;
current readers safely ignore them.

Backup restore is merge-only: matching class and snapshot IDs are replaced,
and unrelated local records are retained. All records are validated before
writes begin. The two Hive boxes are not a cross-box transaction if disk I/O
fails during restore. The backup format remains version 1
because removing ignored optional keys is backward compatible.

## 3. Behavior to preserve

- Attendance starts as Present; tap a student to mark Absent.
- Save is at the bottom. It reads **Save** for new attendance and **Update**
  for an existing record.
- A class is either Lecture or Lab. Create separate classes when both schedules
  are needed.
- Each selected weekday has its own start time. End time is not required.
- Rosters are append-only. Name correction keeps the same roll and updates
  saved attendance rows.
- Later admissions appear from their added date onward. Older attendance keeps
  its captured roster.
- Topic is optional, limited to 40 characters, stored with attendance, and
  included in CSV export and backups.
- Grid geometry and long-press name preview are intentional UI behavior.
- The dashboard opens immediately from `class_box`; the potentially larger
  `snapshot_box` opens after the first frame.
- Drive backup only starts from Backup & restore. It uses the `drive.appdata`
  scope, verifies Drive's returned size and MD5, then trims to five copies.
  Restore validates the full JSON before local writes. Delete all cloud copies
  and Disconnect are separate actions.

## 4. Code map

| Area | Files |
|---|---|
| Startup and lazy history open | `lib/main.dart`, `lib/core/snapshot_storage.dart` |
| Theme | `lib/core/app_theme.dart` |
| Hive models | `lib/data/models/class_entry.dart`, `lib/data/models/snapshot_entry.dart` |
| Attendance logic and UI | `lib/providers/attendance_grid_notifier.dart`, `lib/screens/attendance_grid_screen.dart` |
| Dashboard | `lib/screens/dashboard_screen.dart` |
| Class and roster management | `lib/screens/create_class_screen.dart`, `lib/screens/manage_class_screen.dart`, `lib/data/class_roster_service.dart` |
| Backup | `lib/data/backup_service.dart`, `lib/data/backup_reminder.dart`, `lib/data/drive_authorization.dart`, `lib/data/drive_backup_service.dart`, `lib/widgets/backup_bottom_sheet.dart` |
| CSV export | `lib/export/`, `lib/providers/export_filter_notifier.dart`, `lib/widgets/export_bottom_sheet.dart` |
| Release | `docs/PLAY_RELEASE.md`, `docs/GOOGLE_DRIVE_SETUP.md`, `PRIVACY.md`, `android/app/build.gradle.kts` |
| Tests | `test/` |

## 5. Build and release

- Application ID: `io.github.ddjoshi.attendx`.
- Version: `1.2.2+5`.
- Release signing reads `android/key.properties`; the upload key is expected at
  `android/app/upload-keystore.jks`. Both are gitignored and must be backed up
  securely.
- Flutter command on this machine: `C:\flutter\bin\flutter.bat`.
- Release checklist and real-device QA steps: `docs/PLAY_RELEASE.md`.
- The AttendX Google Cloud project is configured for the locally signed release
  APK, and backup/restore passed on an Android 16 phone. Google Auth Platform
  is External and In production as of 12 October 2026, with only the
  non-sensitive `drive.appdata` scope. The homepage and privacy policy are live
  at `https://dd-joshi.github.io/AttendX/` and
  `https://dd-joshi.github.io/AttendX/privacy.html`. Before broad sharing,
  test Drive with an account outside the former test-user list. For Play
  distribution, register the Play app-signing SHA-1.

Before release, run:

```console
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Always test a freshly built artifact. For migrations from an install with a
different package ID or signing key, save a JSON backup before uninstalling
and restore it in the new install.

## 6. Future improvements

- Add a per-student attendance percentage to CSV if requested.
- Keep Drive uploads user-started unless scheduling is separately designed,
  disclosed, tested, and approved.
- Review dependency upgrades deliberately with `flutter pub outdated`.

