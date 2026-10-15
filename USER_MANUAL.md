# AttendX User Manual

AttendX works offline and stores its data on the Android device. Google Drive
backup is optional and starts only when you tap a Drive action.

## Create a class

1. On the main screen, tap **+**.
2. Enter a class/subject name, choose Lecture or Lab, and set weekdays and start times.
3. Tap **Continue to students**.
4. Paste one student name per line, tap **Preview changes**, then **Add roster**.

Roll numbers are assigned automatically. There is no separate enrollment-number or total-student field.

If you leave roster setup, the class remains visible as **Roster not added**. Tap that class to continue adding its roster.

## Take attendance

1. Tap a class that has a roster.
2. Attendance defaults to today. Tap the date row to choose an earlier date.
3. Every student starts green (Present). Tap only absent students to make them red.
4. Continue scrolling through the two-column roll-and-name cards.
5. Tap **Save**. Opening the same class and date later loads that record and allows an update.

Use the view icon in the top bar to switch between name cards and the compact roll-number grid. AttendX remembers this choice for each class.

In the compact number grid, hold a roll number to reveal the student's name above your finger. In name cards, long-press a student to correct their name.

## Manage a class or roster

1. On the main screen, open the class **three-dot menu**.
2. Choose **Manage class**.
3. Edit the class name, weekdays, or start time and save the class details.
4. Use **Update roster** to add later admissions.

The current roster is pre-filled. Append new student names at the bottom and preview the changes. Existing students cannot be removed, replaced, inserted in the middle, or reordered because their roll identity is used by saved attendance.

Newly appended students appear in new attendance from the day they are added. They are not inserted into older dates, and saved attendance is never rewritten. The initial roster remains available when entering missed backdated attendance.

Use the pencil beside a student only to correct that existing name. Name corrections also update saved records for the same roll.

## Export CSV

1. Open the main screen menu and tap **Export CSV**.
2. Select one class.
3. Select the From and To dates.
4. Tap **Export CSV** and choose where to share or save the file.

The export uses attendance dates, not the time when a record was created. A dash (`-`) means that student was not part of a saved session for that date. Right under the date columns, a **Topic** row lists the topic of each session. The file name records the class, the exported date range, and the overall attendance percentage — for example `AttendX_Class A_2026-07-10_to_2026-08-09_85pct.csv`.

## Backup & restore

Attendance is stored on this device. **Uninstalling the app (or installing a build with a different signature) erases the local copy.** Use **Backup & restore** from the main screen menu:

- **Save backup file** opens a destination picker and writes one JSON file with every class, roster, and attendance record. Choose a folder or provider and keep a copy outside the phone. Cancelling does not count as a successful backup.
- **Restore from file** validates the entire file before merging it into the app. Matching IDs are replaced by the backup version, which may be older. Other records are kept. Save a current backup first.
- **Back up now to Google Drive** asks for your approval and Google account the
  first time. It saves one JSON backup in AttendX's private folder in that
  account. AttendX never schedules or starts a Drive upload itself. Up to five
  recent verified copies are kept.
- **Restore from Google Drive** lists the copies in the selected account. Pick
  one, confirm the restore, and AttendX validates it before merging it into the
  app. Use **Change Google account**, **Disconnect Google Drive**, or **Delete
  all Google Drive backups** in the same screen when needed.

Android 9 and newer may back up app data automatically through system backup settings when the required encryption capability is enabled. Android controls backup timing, size limits, and restoration; AttendX cannot verify the latest copy. Android 7 and 8 use manual JSON backup only. Save a manual file before changing phones or reinstalling.

The dashboard shows a **Time for a backup** reminder after changed data needs
protection. It first appears after the first change, then after one day with
unprotected changes or five more changes. Tap **Back up now** to open the
backup screen, or **Later** to hide the reminder for one day. A confirmed
backup clears only the changes included in that backup.

## Delete data

- To delete attendance for one date, open that class and date, then use the top-bar menu and choose **Delete attendance**.
- To delete a complete class and all of its attendance, use the class three-dot menu on the main screen and choose **Delete class**.

There is no undo for deletion. Records can be recovered only from an existing backup; restoring an older backup can bring deleted records back.

## Topics

On the attendance screen, the **Topic (optional)** row is always visible. Tap it to edit — it switches to an input with a character counter (**40 characters maximum**, shown like `0/40`), and tapping anywhere outside turns it back into a saved-looking text. It is saved with the attendance record and included in CSV exports.

Marking is instant — tap a student and the totals update right away. Saving is the bottom button — **Save** for a new attendance and **Update** when editing an existing one; after a failed save use **Retry**. In the name-card grid, **long-press a student** to correct their name — same roll-preserving correction as **Manage class**.

## Lecture classes and Lab classes

A class is either a **Lecture** or a **Lab**, chosen when the class is created, because lectures and labs usually meet on different days and times. Create one class per type when both are needed (for example `SE COMP A` and `SE COMP A Lab`).

The class type is shown everywhere with a small colored pill (blue book = Lecture, amber flask = Lab), on the class list, in **Manage class**, and on the attendance screen. There is no Lecture/Lab selector anymore — attendance is always of the class's type.

Classes created before this feature count as Lecture classes.

## Class times per weekday

When creating or managing a class, each selected weekday has its own start-time row — tap it to set the time for that day (for example Monday 9:00 AM and Friday 1:00 PM). Classes created before this feature keep their single time for every day.

