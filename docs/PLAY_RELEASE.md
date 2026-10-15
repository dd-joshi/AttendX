# AttendX — Google Play release checklist

See `RELEASE_REVIEW.md` for the code audit and remaining product decisions.
The privacy page and homepage are live; complete the remaining device QA
before Play submission.

## 0. Protect the signing key FIRST

- Upload keystore: `android/app/upload-keystore.jks` (alias `upload`).
- Credentials: `android/key.properties` — **both files are gitignored and exist
  only on this machine.**
- Copy the keystore file + the `key.properties` password to **at least two
  other places** (password manager + a USB drive / private cloud folder).
  Losing the upload keystore makes Play app updates painful (Google recovery
  is slow and not guaranteed). Same trap class as the debug-keystore lesson.

## 1. Play Console setup

1. Create the developer account at play.google.com/console (one-time **$25**
   fee) and complete identity verification.
   ⚠️ If the account is a new personal account, Google currently requires a
   **closed test with at least 12 opted-in testers for 14 continuous days**
   before production access.
   Start this first — it is the only step with a waiting period.
2. Create app: **AttendX**, category **Education**, free.
3. **Target audience: 18+ (teachers/faculty)** — avoids the Families/children
   policy stack. Complete the IARC content rating questionnaire when prompted
   (Education content → typically rated 3+/Everyone).
4. **Data safety form**: the developer receives no attendance data. Assess the
   final build against the current form's definitions and exceptions; account
   for user-directed exports, Android's system-managed backup, and user-tapped
   backup to the teacher's Google Drive. The privacy policy explicitly
   discloses all three. Do not claim that data never leaves the phone.
5. **Use the live privacy policy URL for submission:**
   https://dd-joshi.github.io/AttendX/privacy.html. It is linked from the
   homepage at https://dd-joshi.github.io/AttendX/. After any policy edits,
   regenerate `docs/privacy.html` with
   `dart run tool/generate_privacy_page.dart`, publish it, and verify the live
   URL. The app also includes the same policy for offline reading.

## 1a. Google Drive preparation

Complete [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md) before release:

- Enable the Drive API and configure Google OAuth branding with the same
  public privacy-policy URL.
- Register an Android OAuth client for `io.github.ddjoshi.attendx` and the
  upload certificate SHA-1 for local release testing.
- The Google Auth Platform project is External and In production as of
  12 October 2026. Test Drive with an account outside the former test-user
  list. After Play App Signing is enabled, add the Play app-signing certificate
  SHA-1 too and test the Play distribution path with a disposable account.

## 2. Store listing

- App icon 512×512 (source: `assets/icon/attendx_icon.png`).
- Feature graphic 1024×500.
- ≥2 phone screenshots from a **fresh install of the release build** (not the
  dev build): dashboard + attendance grid are the two that matter.
- Short + full description. Angle: offline attendance, no account,
  CSV export with topics, backup & restore.

## 3. Build and upload

```bat
C:\flutter\bin\flutter.bat build appbundle --release
```

- Output: `build/app/outputs/bundle/release/app-release.aab`
- Release signing requires the upload keystore and `android/key.properties`.
  Missing credentials cause signing to fail; there is no debug-key fallback.
- Increase `versionCode` before uploading if Play already has code 5.
- Enroll in **Play App Signing** when prompted (mandatory for new apps).
- First upload goes to the **closed test** track → promote to production
  after the testing requirement is met. Roll out 10% → 100%.

## 4. Fresh-device QA script (run on the closed-test build)

Use a test device and disposable records for reinstall/restore checks. Do not
uninstall the working app containing live attendance to run this checklist.

1. Install on a device that never had AttendX (or reset a disposable test install).
2. Create a class → paste roster → Save attendance → reopen → state intact.
3. Mark backdated attendance for an earlier date; update it; verify update.
4. Topic row: type topic, tap Save/Update, leave, reopen — persisted with the record.
5. Export CSV → file name shows `AttendX_<class>_<from>_to_<to>_<N>pct.csv`;
   open it: `Topic,,…` row under the date columns; marks P/A/- correct.
6. Backup & restore → save backup file → uninstall → reinstall → restore →
   every class, roster, and record identical. **(The rename to
   `io.github.ddjoshi.attendx` already changed the install identity — this
   step proves the migration path works for real users.)**
7. Connect a disposable Google account → Drive backup → fresh disposable
   install → Drive restore. Verify that cancelled authorization, no internet,
   revoked access, and failed upload never claim success. Make six copies and
   confirm the app retains five. Use **Disconnect** and **Delete all Google
   Drive backups** separately.
8. Airplane mode the whole time for attendance, local backup, restore, and CSV
   export. The app must remain usable while Drive is unavailable.
9. Dashboard backup banner: appears after the first changed record; "Later"
   hides it for one day; a confirmed backup hides the changes it included.
10. Cancel the save-file picker: no saved message and no reminder reset. Save and
   restore a roster with Marathi/Hindi names. Open the CSV in Excel as well.
11. Use TalkBack, large font size, and gesture navigation. Confirm marking,
    scrolling, date selection, deletion, and the bottom save button work.
12. On a test device with non-production data, exercise Android system backup
    and restore. Confirm the three Hive boxes return. Also test disabled backup
    and the manual file path; cloud backup may not run immediately.

## 5. Definition of done

- [ ] Keystore + password backed up in ≥2 places
- [ ] Drive API/OAuth setup and disposable-account round trip passed
- [ ] Closed test passed (including the 12-tester/14-day rule if applicable)
- [ ] Data safety matches the final build; privacy URL live and policy consistent
- [ ] Production rollout started
- [ ] `docs/HANDOVER.md` updated with the live link
