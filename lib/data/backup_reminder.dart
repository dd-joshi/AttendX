import 'package:hive_flutter/hive_flutter.dart';

import '../core/hive_constants.dart';

/// Reminders follow unprotected changes, never schedule uploads themselves.
class BackupReminder {
  BackupReminder._();

  static const String lastBackupAtKey = 'backup_last_at_millis';
  static const String savesSinceBackupKey = 'backup_saves_since_backup';
  static const String snoozeUntilKey = 'backup_reminder_snooze_until_millis';
  static const String driveEmailKey = 'drive_backup_email';
  static const String driveLastBackupAtKey = 'drive_backup_last_at_millis';
  static const String driveChangesKey = 'drive_backup_pending_changes';
  static const String driveConsentKey = 'drive_backup_consent_v1';

  /// Remind on the next day when saved data has changed.
  static const Duration remindAfter = Duration(days: 1);

  static const Duration snoozeFor = Duration(days: 1);

  /// Never-backed-up devices are nudged after real usage starts.
  static const int firstReminderAfterSaves = 1;

  /// Backed-up devices are nudged after heavy activity too.
  static const int remindAfterSaves = 5;

  static Box<dynamic> get _settings =>
      Hive.box<dynamic>(HiveConstants.settingsBox);

  /// Reads the current reminder state from the settings box.
  ///
  /// Returns false (never throws) when the settings box is unavailable, so
  /// marking and saving can never fail because of the reminder.
  static bool isDue({DateTime? now}) {
    try {
      if (!Hive.isBoxOpen(HiveConstants.settingsBox)) return false;
      final clock = now ?? DateTime.now();
      final drive = _settings.get(driveEmailKey) != null;
      return isBackupReminderDue(
        savesSinceBackup: pendingChanges(drive: drive),
        lastBackupAt: _readDate(drive ? driveLastBackupAtKey : lastBackupAtKey),
        snoozeUntil: _readDate(snoozeUntilKey),
        now: clock,
      );
    } catch (_) {
      return false;
    }
  }

  static int pendingChanges({bool drive = false}) =>
      (_settings.get(drive ? driveChangesKey : savesSinceBackupKey) as int?) ??
      0;

  static bool get hasDriveConsent => _settings.get(driveConsentKey) == true;

  static Future<void> grantDriveConsent() =>
      _settings.put(driveConsentKey, true);

  /// Record all data changes, including roster edits, deletion, and restore.
  static Future<void> recordDataChange() async {
    try {
      if (!Hive.isBoxOpen(HiveConstants.settingsBox)) return;
      await _settings.putAll({
        savesSinceBackupKey: pendingChanges() + 1,
        driveChangesKey: pendingChanges(drive: true) + 1,
      });
    } catch (_) {}
  }

  /// Resets the reminder only after the chosen destination confirms a save.
  static Future<void> recordBackupSaved({
    DateTime? now,
    bool drive = false,
    int? includedChanges,
  }) async {
    try {
      if (!Hive.isBoxOpen(HiveConstants.settingsBox)) return;
      final clock = now ?? DateTime.now();
      final current = pendingChanges(drive: drive);
      final coveredChanges = includedChanges ?? current;
      final remaining = current > coveredChanges ? current - coveredChanges : 0;
      await _settings.putAll({
        (drive ? driveLastBackupAtKey : lastBackupAtKey):
            clock.millisecondsSinceEpoch,
        (drive ? driveChangesKey : savesSinceBackupKey): remaining,
        if (drive || _settings.get(driveEmailKey) == null) snoozeUntilKey: null,
      });
    } catch (_) {}
  }

  /// Defers the banner ([snoozeFor] from now).
  static Future<void> snooze({DateTime? now}) async {
    try {
      if (!Hive.isBoxOpen(HiveConstants.settingsBox)) return;
      final clock = now ?? DateTime.now();
      await _settings.put(
        snoozeUntilKey,
        clock.add(snoozeFor).millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static DateTime? _readDate(String key) {
    final value = _settings.get(key);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}

/// Pure reminder policy, split out for tests.
bool isBackupReminderDue({
  required int savesSinceBackup,
  required DateTime? lastBackupAt,
  required DateTime? snoozeUntil,
  required DateTime now,
}) {
  if (snoozeUntil != null && now.isBefore(snoozeUntil)) return false;
  if (savesSinceBackup == 0) return false;
  if (lastBackupAt == null) {
    // Never backed up: nudge once the app has real usage behind it.
    return savesSinceBackup >= BackupReminder.firstReminderAfterSaves;
  }
  return now.difference(lastBackupAt) >= BackupReminder.remindAfter ||
      savesSinceBackup >= BackupReminder.remindAfterSaves;
}
