# Changelog

All notable changes to AttendX are documented in this file. The project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- A cancelled backup no longer reports success or resets the reminder. Backup
  now writes to a user-selected destination instead of a temporary share file.
- Correct UTF-8 restore and Excel CSV output for non-English names and topics.
- Validate whole backup files before replacing records; reject malformed
  schedules, dates, repeated IDs and invalid attendance rows.
- Accessible attendance actions for screen readers and visible errors for
  failed name corrections.
- Startup failure now offers retry; release signing no longer uses debug keys.
- Google Drive upload is accepted only after Drive confirms its size and MD5.
  Older cloud copies are never removed before that confirmation; a failed
  delete leaves the last verified-backup status intact.

### Added

- Offline privacy policy and dependency licenses in About.
- Explicit Android backup rules: encrypted cloud backup on supported devices,
  phone transfer, and manual JSON recovery. Updated privacy disclosures.
- A static privacy page generated from the policy bundled in the app.
- Optional user-tapped Google Drive backup and restore. AttendX uses the
  private Drive app-data folder, keeps the five newest verified copies, shows a
  first-use disclosure, supports account changes, delete-all, and disconnect.
- Drive backup tests cover consent gating, account/API failures, upload
  verification, retention, corruption-safe restore, and pending changes made
  while a backup is running. `docs/GOOGLE_DRIVE_SETUP.md` documents the Cloud
  project and real-device recovery test.

### Changed

- Simplified Backup & restore wording, moved Google account management into an
  options menu, and made cloud backup rows visibly selectable.
- Bumped the refined Drive backup build to `1.2.2+5` so it is distinguishable
  from previously shared test APKs.
- CSV generation visits rows once and avoids per-row map copies. Removed the
  unused export payload wrapper and redundant sort and serialization fields.
- Class scheduling computes each next occurrence once per sort. Class edits
  compare weekdays and times directly and avoid rebuilding roll lists per row.
- Backup reminders now follow every data change, including roster and class
  edits, deletion, and restore. They prompt after one change, then after one
  day or five further changes, and never start a network backup themselves.

- Simplified class creation by assigning each class an internal UUID; users no
  longer need to create or manage a shared class code.
- Replaced absolute offline-only wording with accurate offline-first wording:
  all attendance functions work locally, and Google Drive backup is optional.

### Removed

- The unfinished online synchronization prototype, its queue and setup files,
  and the companion web viewer.

## [1.2.0] - 2026-10-07

### Added

- **Google Play packaging**: applicationId `com.example.attendx` →
  `io.github.ddjoshi.attendx` (Play rejects `com.example.*`; existing installs
  migrate via **Backup & restore**), version `1.2.0+3`, release signing with an
  upload keystore + `android/key.properties`, the `docs/PLAY_RELEASE.md`
  checklist (console steps, QA script, keystore backup rules), and `PRIVACY.md`.
- **Backup reminder**: dashboard banner ("Time for a backup") appears after 5
  saves when no backup exists, or 30 days / 20 saves after the last one;
  **Later** snoozes it for 7 days and a created backup resets it.
- **Export upgrades**: the CSV carries a **Topic** row under the date columns,
  and the file name records class, exported date range, and overall attendance
  percentage (`AttendX_Class A_2026-07-10_to_2026-08-09_85pct.csv`).
- **About** screen: "All data stays on this device" statement with a privacy
  policy link.

### Changed

- **Home**: overflow menu (Export CSV, Backup & restore, About), labeled
  **+ New class** button, and three-line class rows (name · type and students ·
  days and start time).
- **Attendance screen**: compact tappable date line with the Lecture/Lab pill,
  bottom **Save**/**Update** button with truthful Saving/Saved states and
  **Retry** on failure, and a permanent tap-to-edit **Topic** row.
- Long-press a student in the name-card grid to correct their name.
- Brief color-only transitions on attendance cells (reduced-motion aware).
- **Visual refresh**: spec color palette (blue `#0066CC` actions, calm green /
  solid red attendance cells), 22sp screen titles, 10dp buttons, white
  outlined form fields, 14dp surfaces.
- **Backup & restore**: one JSON file containing every class, roster, and
  attendance record; restore after a reinstall or phone change. Protects
  against Android wiping app storage on uninstall.
- Per-weekday start times: each selected weekday gets its own start-time row
  (e.g. Monday 9:00 AM, Friday 1:00 PM). Older classes keep their single
  time. Dashboard "Now / Upcoming" and scheduling use the per-day times.
- Optional **Topic** field per attendance session (one per class, date, and
  Lecture/Lab) as a future reference of what was taught that day; kept in
  backups and CSV exports. Limited to 40 characters with a visible
  character counter.
- Class **type** chosen at creation (Lecture or Lab), each with its own
  schedule. Type badges (blue book / amber flask) identify classes
  everywhere; attendance is always of the class's type (older classes count
  as Lecture).
- CSV export keeps lecture and lab columns separate for the same date
  (`yyyy-MM-dd` for lectures, `yyyy-MM-dd Lab` for labs).

## [1.1.0] - 2026-08-10

### Added

- Today-first date selector with backdated attendance entry.
- Two-column roll-and-name cards plus a compact number-grid preference.
- Above-finger student-name preview when holding a number-grid cell.
- Class management and append-only roster updates for later admissions.
- Global CSV export filtered by class and attendance date range.
- Read-only access to saved attendance by selecting its class and date.

### Changed

- Dashboard classes are ordered by their next scheduled occurrence.
- History editing is consolidated into the main date-selected attendance flow.
- Name correction is centralized in **Manage class** and follows the same roll
  through saved attendance and exports.
- Refined spacing, colors, touch targets, and busy states for a compact,
  professional interface.

### Fixed

- Prevented a Flutter lifecycle assertion after saving a corrected student name.
- Guarded asynchronous roster, attendance, export, delete, and preference work
  when screens or providers are disposed.
- Preserved unsaved class-detail changes while correcting a roster name.
- Preserved changing X, Y, and Z rosters correctly in semester CSV exports.

## [1.0.0] - 2026-04-07

- Initial offline attendance MVP.

[1.2.0]: https://github.com/dd-joshi/AttendX/releases/tag/v1.2.0
[1.1.0]: https://github.com/dd-joshi/AttendX/releases/tag/v1.1.0
[1.0.0]: https://github.com/dd-joshi/AttendX/releases/tag/v1.0.0
