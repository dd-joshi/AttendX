import 'dart:convert';
import 'dart:io';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/data/backup_reminder.dart';
import 'package:attendx/data/drive_authorization.dart';
import 'package:attendx/data/drive_backup_service.dart';
import 'package:attendx/widgets/backup_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Authorization implements DriveAuthorizationClient {
  int calls = 0;

  @override
  Future<String> authorize(String? email) async {
    calls++;
    return 'token';
  }

  @override
  Future<void> disconnect(String email) async {}
}

class _DriveListService extends DriveBackupService {
  @override
  bool get isAuthorized => true;

  @override
  Future<List<DriveBackup>> listBackups() async => [
    DriveBackup(
      id: 'backup-1',
      createdAt: DateTime(2026, 10, 8, 16, 53),
      size: 2048,
      checksum: 'checksum',
      classes: 1,
      records: 2,
    ),
  ];
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('attendx_drive_ui_');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(HiveConstants.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('Drive backup displays disclosure before Google authorization', (
    tester,
  ) async {
    final authorization = _Authorization();
    final service = DriveBackupService(
      authorization: authorization,
      client: MockClient((request) async {
        if (request.url.path == '/drive/v3/about') {
          return http.Response(
            jsonEncode({
              'user': {'emailAddress': 'teacher@example.com'},
            }),
            200,
          );
        }
        return http.Response('unexpected request', 500);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BackupBottomSheet(driveService: service)),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Connect Google Drive'));
    await tester.pumpAndSettle();
    expect(find.text('Enable Google Drive backup?'), findsOneWidget);
    expect(authorization.calls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(authorization.calls, 0);
    expect(BackupReminder.hasDriveConsent, isFalse);
  });

  testWidgets('Drive restore presents backups as selectable rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await BackupReminder.grantDriveConsent();
      await Hive.box<dynamic>(HiveConstants.settingsBox)
          .put(BackupReminder.driveEmailKey, 'teacher@example.com');
    });
    final service = _DriveListService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BackupBottomSheet(driveService: service)),
      ),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Change Google account'), findsNothing);
    expect(find.byTooltip('Google Drive options'), findsOneWidget);

    await tester.tap(find.text('Restore backup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Restore from Google Drive'), findsOneWidget);
    expect(find.text('1 class · 2 records'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    final backupRow = find.ancestor(
      of: find.text('8 Oct 2026'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(backupRow).height, lessThan(72));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('8 Oct 2026'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Restore selected backup?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Restore cancelled.'), findsOneWidget);
  });
}
