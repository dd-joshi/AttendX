# Google Drive backup setup

As of 12 October 2026, the AttendX Google Auth Platform project
(`attendx-511008`) is External and **In production**. The configured scope is
only `https://www.googleapis.com/auth/drive.appdata`; the sensitive and
restricted scope lists are empty. The public homepage is
https://dd-joshi.github.io/AttendX/ and its privacy policy is
https://dd-joshi.github.io/AttendX/privacy.html. A test with an account that
was not on the former test-user list is still needed before broad sharing.

AttendX uses Google Drive only for a teacher-initiated backup or restore. It
does not use Firebase, a server, a client secret, or a refresh token. The
Android Google Identity API requests the narrow drive.appdata scope when the
teacher taps a Drive action.

Complete this before testing with a real Google account. Do not use real
student data for the first round trip.

## 1. Create and configure the Google Cloud project

1. Create a dedicated project in [Google Cloud Console](https://console.cloud.google.com/).
2. Open **APIs & Services → Library**, find **Google Drive API**, and enable
   it.
3. Open **Google Auth Platform → Branding**. Set the app name to AttendX, a
   support email, developer contact email, the public privacy-policy URL, and
   the homepage. The live URLs are listed above.
4. Under **Audience**, use **External** unless the app will only be used in one
   managed Workspace organization. This project is already In production, so
   new users do not need to be added as test users.
5. Under **Data Access**, add only the scope
   https://www.googleapis.com/auth/drive.appdata. Do not add broad Drive,
   Contacts, Gmail, profile, or offline-access scopes.

drive.appdata is the non-sensitive Drive app-data scope. It creates a hidden
private app folder for AttendX, so a normal Drive file browser will not show
the backups. Teachers manage those copies through AttendX's Google Drive backup
screen.

## 2. Register the Android app

1. Open **Google Auth Platform → Clients → Create client**.
2. Choose **Android**.
3. Enter package name io.github.ddjoshi.attendx.
4. Add the SHA-1 signing-certificate fingerprint for the exact build:

   - For a locally signed release APK, read the upload keystore:

        keytool -list -v -keystore android\app\upload-keystore.jks -alias upload

   - For a Play-distributed build, also add the **App signing certificate**
     SHA-1 from Play Console → **Setup → App integrity**. Play re-signs the
     final install, so this value is required for closed and production tests.
   - Add the debug-keystore SHA-1 only if testing a debug build.

Keep the keystore password and the android/key.properties file private.
Neither belongs in Google Cloud or source control.

## 3. Publishing to production (removes the test-user limit)

While the consent screen is **in Testing**, only accounts listed under
**Test users** can use Drive backup, and their access expires after 7 days.
This is why APKs cannot be shared freely — every new user would need their
email added to the project first.

To let **any Google account** use Drive backup without adding emails:

1. Complete **Google Auth Platform → Branding**: app name, user support
   email, developer contact email, homepage, and publicly reachable HTTPS
   privacy-policy URL.
2. Open **Google Auth Platform → Audience → Publishing status** and click
   **Publish app**. This was completed on 12 October 2026 for the AttendX
   project; these steps remain as a reference for future projects.

Because AttendX requests only `https://www.googleapis.com/auth/drive.appdata`,
a **non-sensitive** scope, full OAuth verification is not required to go
live (Google's OAuth App Verification Help Center: "If your app utilizes only
non-sensitive scopes, it is not mandatory for your app to complete the app
verification process"). Optionally, a lighter **brand verification** makes the
app name and logo appear on the consent screen.

After publishing:

- Any Google account can connect Drive backup; no per-user email adding.
- The 7-day token expiry of Testing mode no longer applies.
- APKs can be shared with anyone; file-based backup works regardless.

## 4. Real-device acceptance test

Use a fresh emulator or disposable test device and an empty/test class:

1. Install the locally signed release APK after its SHA-1 is registered.
2. Create a class and attendance record. Open **Backup & restore** and tap
   **Back up now to Google Drive**.
3. Read the disclosure, enable it, choose the test account, and confirm that
   the status names the selected account and reports a successful backup.
4. Make another small change and back up again. Create at least six test
   backups; confirm the app lists at most five completed copies.
5. On a separate fresh install, sign into the same Google account, choose
   **Restore from Google Drive**, restore the latest copy, and verify class,
   roster, date, topic, and attendance marks.
6. Test cancelled account selection, unavailable internet, revoked access,
   full Drive storage, account switching, delete-all, and disconnect. Failed
   upload or deletion must not report success.

Do not uninstall the teacher's working app to run this test. The automated
test suite verifies protocol and data-integrity behavior with fake Google
responses; only this test verifies the actual Cloud configuration.

## 4. Play Console and policy

Before submitting the build:

- Publish docs/privacy.html from the same source as PRIVACY.md, verify it
  while signed out, and put that exact URL in Google Cloud branding and Play
  Console.
- Review the current Play **Data safety** form against the final app behavior.
  The app sends attendance data directly to the teacher's chosen Google Drive
  account only after their tap; it has no AttendX account or developer server.
  Answer the form from the current Play definitions, not from this document.
- Ensure the store listing and in-app disclosure say that Google Drive is
  optional, user-started, private app-data backup. Do not promise permanent
  storage or guaranteed recovery.

Reference documentation: [Android authorization](https://developer.android.com/identity/authorization),
[Drive app data](https://developers.google.com/workspace/drive/api/guides/appdata),
and [Drive uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads).
