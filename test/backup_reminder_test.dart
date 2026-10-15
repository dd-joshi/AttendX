import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/data/backup_reminder.dart';

void main() {
  group('backup reminder policy', () {
    final now = DateTime(2026, 10, 7, 9);

    test('never-backed-up devices nag only after real usage', () {
      expect(
        isBackupReminderDue(
          savesSinceBackup: BackupReminder.firstReminderAfterSaves - 1,
          lastBackupAt: null,
          snoozeUntil: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        isBackupReminderDue(
          savesSinceBackup: BackupReminder.firstReminderAfterSaves,
          lastBackupAt: null,
          snoozeUntil: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('snooze defers the reminder for one day, then it returns', () {
      final snoozeUntil = now.add(const Duration(days: 1));
      expect(
        isBackupReminderDue(
          savesSinceBackup: 50,
          lastBackupAt: null,
          snoozeUntil: snoozeUntil,
          now: now,
        ),
        isFalse,
      );
      expect(
        isBackupReminderDue(
          savesSinceBackup: 50,
          lastBackupAt: null,
          snoozeUntil: snoozeUntil,
          now: snoozeUntil.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('a recent backup keeps the banner away until the next day', () {
      expect(
        isBackupReminderDue(
          savesSinceBackup: 1,
          lastBackupAt: now.subtract(const Duration(hours: 23)),
          snoozeUntil: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        isBackupReminderDue(
          savesSinceBackup: 1,
          lastBackupAt: now.subtract(const Duration(days: 1)),
          snoozeUntil: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('heavy save activity triggers the reminder before the next day', () {
      expect(
        isBackupReminderDue(
          savesSinceBackup: BackupReminder.remindAfterSaves - 1,
          lastBackupAt: now,
          snoozeUntil: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        isBackupReminderDue(
          savesSinceBackup: BackupReminder.remindAfterSaves,
          lastBackupAt: now,
          snoozeUntil: null,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('BackupReminder settings storage', () {
    late Directory hiveDirectory;

    setUp(() async {
      hiveDirectory = await Directory.systemTemp.createTemp(
        'attendx_reminder_test_',
      );
      Hive.init(hiveDirectory.path);
      await Hive.openBox<dynamic>(HiveConstants.settingsBox);
    });

    tearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    test('changed data counts up and a backup resets the state', () async {
      final now = DateTime(2026, 10, 7, 9);

      await BackupReminder.recordDataChange();
      expect(BackupReminder.isDue(now: now), isTrue);

      await BackupReminder.recordBackupSaved(now: now);
      expect(BackupReminder.isDue(now: now), isFalse);

      await BackupReminder.recordDataChange();
      expect(BackupReminder.isDue(now: now), isFalse);

      final later = now.add(const Duration(days: 1));
      expect(BackupReminder.isDue(now: later), isTrue);
    });

    test('snooze is stored and expires', () async {
      final now = DateTime(2026, 10, 7, 9);
      for (var i = 0; i < BackupReminder.firstReminderAfterSaves; i++) {
        await BackupReminder.recordDataChange();
      }
      expect(BackupReminder.isDue(now: now), isTrue);

      await BackupReminder.snooze(now: now);
      expect(BackupReminder.isDue(now: now), isFalse);
      expect(
        BackupReminder.isDue(now: now.add(const Duration(days: 1, seconds: 1))),
        isTrue,
      );
    });

    test('backup clears an active snooze', () async {
      final now = DateTime(2026, 10, 7, 9);
      for (var i = 0; i < BackupReminder.firstReminderAfterSaves; i++) {
        await BackupReminder.recordDataChange();
      }
      await BackupReminder.snooze(now: now);
      await BackupReminder.recordBackupSaved(now: now);

      final settings = Hive.box<dynamic>(HiveConstants.settingsBox);
      expect(settings.get(BackupReminder.snoozeUntilKey), isNull);
      expect(settings.get(BackupReminder.savesSinceBackupKey), 0);
    });
  });
}
