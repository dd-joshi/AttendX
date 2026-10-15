# AttendX release review

Reviewed: 7 October 2026. Scope: offline-first Android app with optional,
user-started Google Drive recovery, release preparation, functional
correctness, and removal of unnecessary work in the code.

## Recommendation

AttendX has a useful first-release scope: create a lecture/lab class, paste a
roster, mark attendance offline, correct past records, record topics, export a
semester CSV, and save/restore a backup. A backend, login, advertising, or a
subscription is not needed to make that useful. Describe the current limits
accurately in the listing. The local changes are ready for device testing;
this review does not constitute Play approval or a completed physical-device test.

## Fixed during this pass

| Area | Finding and correction |
| --- | --- |
| Startup | Flutter now displays a loading state while opening local data and offers retry on failure. Attendance history opens after the dashboard's first frame. No before/after cold-start timings have been measured. |
| Backup save | The system file picker writes the JSON to the user's selected destination. Cancelling or failing no longer claims success or resets the backup reminder. |
| Restore | UTF-8 decoding preserves Marathi/Hindi names. The complete file is validated before any records are written; malformed later rows cannot partially replace classes. Unsupported versions, duplicate IDs, invalid marks/schedules, and orphan records are rejected. |
| Data compatibility | Existing Hive adapter IDs/field numbers are preserved. A test opens a real legacy-format Hive file, edits it, and reopens it with retired backend fields present. |
| Attendance | Saving/deleting prevents conflicting grid edits. A failed name correction reports an error. Updating a snapshot creates its replacement before writing instead of mutating the live object first. |
| Accessibility | Attendance cells expose tap and long-press actions to screen readers. The previous semantics wrapper hid those actions. |
| CSV | One row traversal collects marks, names, and topics; redundant map copies and pre-sorting were removed. Numeric rolls sort correctly. UTF-8 BOM helps Excel display local-language names. Formula-like text is exported as text. |
| Direct code | Removed the unused export payload class. Removed repeated roster-list generation and parse/string round trips. Schedule sort calculates each next occurrence once. Class-detail dirty checks compare actual values directly. |
| Async writes | Reminder writes are awaited so async failures are handled. Export captures its date range before async work and checks disposal. Inputs are disabled during saves/exports. |
| Privacy and release | Added an offline policy reader and dependency licences. About shows the build version. Release signing cannot silently fall back to a debug key. Explicit Android backup rules include only the three active Hive boxes. |

The app remains without Firebase, a developer backend, AttendX authentication,
or shared synchronization. Manual JSON files, Android system backup, and the
optional user-tapped Google Drive copy serve different recovery needs; keep
the manual file path available.

## Optional Google Drive backup

AttendX asks for Google Drive access only after the teacher chooses a Drive
action. It requests only `drive.appdata`, uploads a full existing JSON backup
to the account's private app-data folder, verifies the returned byte count and
MD5, and then retains the five newest completed copies. Access tokens remain
in memory for the open backup sheet; the selected email and consent are the
only Drive details retained locally.

The recovery path can list, confirm, download, verify, and merge a selected
copy. A malformed or checksum-mismatched file is rejected before it can write
local data. Delete-all is separate from Disconnect; Disconnect clears the
device configuration and asks Google to revoke access, while existing cloud
copies remain until deleted.

This implementation is not a verified real-account recovery claim yet. The
Google Cloud project, OAuth Android credentials, and disposable-account test
specified in `GOOGLE_DRIVE_SETUP.md` are still required before release.

## Product decisions before a broad release

1. **Multiple sessions on one day:** currently each class has one attendance
   record per date and its Lecture/Lab type. Reopening that date edits that
   record. Different subjects can be separate classes, but a second lecture of
   the same subject on the same day cannot be a separate record. Earlier
   discussions included multiple sessions; confirm whether the offline release
   needs this too. Adding it needs a session ID/label, a session chooser, CSV
   columns, migration, and restore tests. Do not silently change existing records.
2. **Actual student roll numbers:** current rosters use consecutive 01, 02, ...
   numbering. General institute use may require arbitrary roll/enrolment IDs,
   gaps, and lab batches. Confirm the needed input format before changing the
   attendance identity model. The current behaviour is suitable only where
   this numbering matches the register.
3. **Useful next additions:** a per-student attendance percentage/shortage
   summary and archiving completed classes would add more everyday value than
   online features. These can follow the first release if users accept the
   current CSV-based reporting and dashboard.
4. **Colours:** the existing blue and neutral background are suitable for an
   education tool. Optional alternative: indigo primary `#4338CA`, background
   `#F8FAFC`, white surfaces, dark text `#0F172A`. Keep present/absent colours
   separate from navigation colours and retain textual/accessibility cues.
   This is a suggestion; the current theme was retained.

## Automatic backup and Indian privacy requirements

Android backup remains enabled at the user's request. Android 9-11 rules
require the client-side encryption flag. Android 12+ cloud rules require
encryption capability and separate rules permit phone-to-phone transfer.
Android 7/8 use manual backup only. The allowlist contains class, snapshot,
and settings Hive files, excluding temporary exports and retired backend data.

Android controls timing and restoration. Its cloud quota is 25 MB per app user;
an oversized dataset is not backed up. Manual JSON remains necessary before
reinstalling or changing phones. See [Android Auto Backup documentation](https://developer.android.com/identity/data/autobackup).

The official material reviewed does not establish a blanket Indian ban on this
system-backup design. That is not a legal compliance certification: student
records, educator authority, institutional policies, and applicable obligations
still matter. The DPDP Act's cross-border provision allows government
restrictions and preserves stricter applicable law; commencement is phased.
See the [DPDP Act](https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023-1.pdf)
and [commencement notification](https://www.meity.gov.in/static/uploads/2025/11/c56ceae6c383460ca69577428d36828b.pdf).
The app policy now discloses system backup and user-selected file destinations,
instead of claiming data can never leave the phone.

## Release tasks still required

- **Publish the privacy policy.** The previously documented GitHub PRIVACY.md
  URL returned 404 during this review. `docs/privacy.html` is prepared from the
  same `PRIVACY.md` bundled inside the app. Publish it on a stable public HTTPS
  page, verify access while signed out, and put that actual URL in Play Console.
  Google requires an accessible policy even for apps that do not collect data:
  [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en).
- **Real-device QA:** follow `PLAY_RELEASE.md` using test data. Check cold launch
  with a realistic history, large text/TalkBack, native file pickers, Excel CSV,
  release updates over an existing install, and manual plus Android backup
  restoration. Do not uninstall the user's working copy to run these tests.
- **Google OAuth production setup:** Drive API, the local release Android OAuth
  client, test users, and real-device backup/restore are complete. Add the live
  policy URL and other public branding, publish the OAuth app, and register the
  Play app-signing SHA-1 before broad Play distribution.
- **Play Console:** complete listing/screenshots, developer verification, Data
  safety, content rating, and any account-specific closed-testing requirement.
  The current target is API 36, matching the
  [published requirement for new apps/updates](https://developer.android.com/google/play/requirements/target-sdk).
- **Signing/version:** protect the upload key and credentials outside this
  computer. Current version is `1.2.2+5`; use a higher build number if 5 has
  already been uploaded. The ZIP checkout has no Git history; these changes
  have not been committed or published.

## Remaining technical limits

- Restore validates before writes, but writes to multiple Hive boxes are not a
  single transaction. Disk failure or process interruption during restore can
  leave a partial import; save a current manual backup before merging an old one.
- Hive files have Android app-storage protection, not app-level encryption.
  CSV/JSON exports contain readable personal information.
- Google Drive app-data files are private to the Google account and app, but
  are subject to Google account storage and lifecycle. They can be unavailable
  if the account is lost, storage is full, the user removes the app's Drive
  data, or Google access is revoked. Keep a manual JSON copy for important
  records.
- No measured startup-speed percentage, guaranteed backup completion, or full
  16 KB device-runtime compatibility is claimed by unit tests or package checks.

## Verification

- `dart format --output=none --set-exit-if-changed lib test tool`: passed.
- `flutter analyze`: no issues.
- `flutter test`: 63 tests passed, including file-save cancellation/failure,
  Unicode restore, malformed-file validation, Hive backward compatibility,
  attendance/date/roster workflows, CSV, Drive consent, pagination, verified
  upload/retention, corrupt-restore protection, and accessible actions.
- `flutter build apk --release`: passed; APK 56,242,764 bytes (53.6 MiB).
- `flutter build appbundle --release`: passed; AAB 54,859,937 bytes (52.3 MiB).
- APK and AAB signatures verify. APK signer is AttendX, not Android Debug.
- Packaged manifest: application ID `io.github.ddjoshi.attendx`, version
  `1.2.2+5`, minimum API 24, target API 36. The optional Drive implementation
  adds only the normal `INTERNET` permission; there is no broad Drive storage
  permission, background upload service, or developer API endpoint.
- Packaged backup rules include the corrected encryption requirement. AAB and
  APK contain the policy matching the source file.
- `zipalign -c -P 16 4` passes on the final APK. ARM64/x86_64 libraries have
  64 KB ELF LOAD alignment; 32-bit ARM app code has the required 16 KB
  alignment. A real 16 KB device/emulator runtime test remains part of release
  QA.

Artifacts: `build/app/outputs/flutter-apk/AttendX-1.2.2+5-BackupUI.apk`
(same bytes as `app-release.apk`, SHA-256
`48359584BE5D00C486265DEDA5DF0959703003A70B0989EF14BEA4DAE13C6C7F`)
and `build/app/outputs/bundle/release/app-release.aab`. These are local build
files, not uploaded Play releases. Drive backup and restore passed on the
remote Android 16 phone with the previous signed build; install this UI update
on the same phone for final visual verification.
