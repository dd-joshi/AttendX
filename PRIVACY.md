# AttendX Privacy Policy

Last updated: 7 October 2026

AttendX is an attendance tool for teachers and faculty, maintained by the
dd-joshi/AttendX project. It works without an AttendX account or internet
connection. Google Drive backup is optional and starts only when you choose a
Google Drive action. The developer does not receive your classes or attendance.

## Data stored and used

The app stores class names, schedules, student names and roll numbers,
attendance marks, topics, and preferences in its private storage on your
device. These records are used to take attendance, manage rosters, and create
the exports and backups you request.

## Android automatic backup

On supported Android devices, the operating system may back up classes,
attendance, and preferences to your configured backup provider or transfer
them during phone setup. Cloud backup is allowed only when Android reports
the required encryption capability. Android 7 and 8 use manual backup only.

Android controls whether and when a backup runs, its storage limits, retention,
and restoration. Manage backup through your phone's system backup settings.
AttendX cannot verify that the latest attendance was backed up or guarantee
restoration. The developer cannot access these system backups.

## Optional Google Drive backup

If you choose **Google Drive** in Backup & restore, AttendX asks you to choose
a Google account and authorize the Google Drive app-data permission. When you
tap **Back up now**, AttendX sends a JSON backup through HTTPS to that account's
private AttendX app-data folder. The backup contains class names, schedules,
student names and roll numbers, attendance marks, topics, and backup metadata.

AttendX does not upload to Google Drive in the background or on a schedule.
It keeps up to five recent verified backups. The folder is private to AttendX
and is not shared with other AttendX users; Google processes it under the
Google terms and settings for your account. The developer cannot access it.

You can restore a listed backup, delete all AttendX Drive backups, or
disconnect Google Drive in Backup & restore. Disconnecting removes the account
from AttendX and requests that Google revoke the permission. Existing Drive
backups remain until you delete them. Google Drive storage, availability, and
retention remain under Google's control.

## Files you save or share

Export CSV opens the system share sheet. Save backup file opens the system
file picker and writes a JSON file to the location you choose. Selecting an
online provider may upload that file under that provider's terms.

CSV and JSON files contain readable student information and are not encrypted
by AttendX. Choose an appropriate destination and share them only with people
who should receive the records.

## Retention, deletion, and security

Local records remain until you delete a class or attendance record, clear app
storage in Android settings, or uninstall the app. Deleting a class removes its
local roster and attendance. Restoring an older backup may bring back records
that you previously deleted.

Copies saved outside the app, shared with other apps, retained by Android's
backup provider, or saved to Google Drive must be deleted through those
locations or providers. Deleting local records does not recall those copies.

AttendX uses Android's private app storage. It does not provide a separate app
password or database encryption. Protect the phone with a screen lock. Users
are responsible for following their institution's rules when entering,
backing up, or sharing student records.

## Accounts, tracking, and children

AttendX has no accounts, advertising, analytics, tracking, or developer-operated
data server. It is intended for educators, not children. Educators may enter
student information, including information about minors, when authorized to
do so; the developer does not receive that information.

## Contact and updates

For a privacy inquiry, use the project's issue form:
https://github.com/dd-joshi/AttendX/issues

Do not post student names or attendance records in a public issue. Policy
updates are published in PRIVACY.md in the AttendX project and included in
future app releases.
