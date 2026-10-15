import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/data/backup_reminder.dart';
import 'package:attendx/data/drive_authorization.dart';
import 'package:attendx/data/drive_backup_service.dart';
import 'package:attendx/data/models/class_entry.dart';
import 'package:attendx/data/models/snapshot_entry.dart';

class _Authorization implements DriveAuthorizationClient {
  final String token = 'token';
  int authorizeCalls = 0;
  String? requestedEmail;
  int disconnectCalls = 0;

  @override
  Future<String> authorize(String? email) async {
    authorizeCalls++;
    requestedEmail = email;
    return token;
  }

  @override
  Future<void> disconnect(String email) async {
    disconnectCalls++;
  }
}

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'attendx_drive_test_',
    );
    Hive.init(hiveDirectory.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ClassEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SnapshotEntryAdapter());
    }
    await Hive.openBox<ClassEntry>(HiveConstants.classBox);
    await Hive.openBox<SnapshotEntry>(HiveConstants.snapshotBox);
    await Hive.openBox<dynamic>(HiveConstants.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  Future<void> seedClass({String title = 'SE Electrical A'}) {
    return Hive.box<ClassEntry>(HiveConstants.classBox).put(
      'class-1',
      ClassEntry(
        classId: 'class-1',
        title: title,
        weekdays: const [0],
        startHour: 9,
        totalStudents: 1,
        students: const {'01': 'Aditi'},
      ),
    );
  }

  Future<void> connect(DriveBackupService service) async {
    await BackupReminder.grantDriveConsent();
    await service.connect(chooseAccount: true);
  }

  Map<String, dynamic> fileJson(
    String id, {
    int size = 2,
    String checksum = 'd41d8cd98f00b204e9800998ecf8427e',
  }) {
    return {
      'id': id,
      'createdTime': '2026-10-07T10:00:00.000Z',
      'size': '$size',
      'md5Checksum': checksum,
      'appProperties': {'classes': '1', 'records': '0'},
    };
  }

  test('does not authorize or call Drive before explicit consent', () async {
    final authorization = _Authorization();
    final requests = <http.Request>[];
    final service = DriveBackupService(
      authorization: authorization,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 500);
      }),
    );

    await expectLater(service.connect(), throwsA(isA<DriveBackupException>()));

    expect(authorization.authorizeCalls, 0);
    expect(requests, isEmpty);
  });

  test('lists every Drive result page and ignores malformed entries', () async {
    final authorization = _Authorization();
    var listCalls = 0;
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
        if (request.url.path == '/drive/v3/files') {
          listCalls++;
          if (request.url.queryParameters['pageToken'] == 'page-2') {
            return http.Response(
              jsonEncode({
                'files': [fileJson('second')],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'nextPageToken': 'page-2',
              'files': [
                fileJson('first'),
                {'id': 'incomplete'},
              ],
            }),
            200,
          );
        }
        return http.Response('unexpected request', 500);
      }),
    );

    await connect(service);
    final backups = await service.listBackups();

    expect(listCalls, 2);
    expect(backups.map((backup) => backup.id), ['first', 'second']);
  });

  test(
    'verified upload keeps recent copies and preserves changes made mid-upload',
    () async {
      await seedClass();
      await BackupReminder.recordDataChange();
      final authorization = _Authorization();
      final deleted = <String>[];
      Map<String, dynamic>? metadata;
      late List<int> uploadedBytes;
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
          if (request.method == 'POST') {
            metadata = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '',
              200,
              headers: {
                'location': 'https://www.googleapis.com/upload/drive/v3/files?upload_id=1',
              },
            );
          }
          if (request.method == 'PUT') {
            uploadedBytes = request.bodyBytes;
            await BackupReminder.recordDataChange();
            return http.Response(
              jsonEncode(
                fileJson(
                  'new',
                  size: uploadedBytes.length,
                  checksum: md5.convert(uploadedBytes).toString(),
                ),
              ),
              200,
            );
          }
          if (request.method == 'GET' &&
              request.url.path == '/drive/v3/files') {
            return http.Response(
              jsonEncode({
                'files': [
                  fileJson('new'),
                  fileJson('one'),
                  fileJson('two'),
                  fileJson('three'),
                  fileJson('four'),
                  fileJson('oldest'),
                ],
              }),
              200,
            );
          }
          if (request.method == 'DELETE') {
            deleted.add(request.url.pathSegments.last);
            return http.Response('', 204);
          }
          return http.Response('unexpected request', 500);
        }),
      );

      await connect(service);
      expect(await service.upload(), isTrue);

      expect(metadata!['parents'], ['appDataFolder']);
      expect(metadata!['appProperties']['attendxBackup'], '1');
      expect(utf8.decode(uploadedBytes), contains('"backupVersion": 1'));
      expect(deleted, ['oldest']);
      expect(DriveBackupService.lastUploadedAt, isNotNull);
      expect(BackupReminder.pendingChanges(drive: true), 1);
    },
  );

  test('failed upload verification never clears pending changes or deletes old copies', () async {
    await seedClass();
    await BackupReminder.recordDataChange();
    final authorization = _Authorization();
    final requests = <http.Request>[];
    final service = DriveBackupService(
      authorization: authorization,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/drive/v3/about') {
          return http.Response(
            jsonEncode({
              'user': {'emailAddress': 'teacher@example.com'},
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          return http.Response(
            '',
            200,
            headers: {
              'location': 'https://www.googleapis.com/upload/drive/v3/files?upload_id=1',
            },
          );
        }
        if (request.method == 'PUT') {
          return http.Response(jsonEncode(fileJson('new', size: 1)), 200);
        }
        return http.Response('unexpected request', 500);
      }),
    );

    await connect(service);
    await expectLater(service.upload(), throwsA(isA<DriveBackupException>()));

    expect(requests.where((request) => request.method == 'DELETE'), isEmpty);
    expect(DriveBackupService.lastUploadedAt, isNull);
    expect(BackupReminder.pendingChanges(drive: true), greaterThan(0));
  });

  test('corrupt Drive restore leaves existing local data unchanged', () async {
    await seedClass(title: 'Keep this class');
    final bytes = utf8.encode('{not valid json');
    final checksum = md5.convert(bytes).toString();
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
        if (request.url.path == '/drive/v3/files/backup-1') {
          return http.Response.bytes(bytes, 200);
        }
        return http.Response('unexpected request', 500);
      }),
    );
    await connect(service);
    final backup = DriveBackup(
      id: 'backup-1',
      createdAt: DateTime(2026, 10, 7),
      size: bytes.length,
      checksum: checksum,
      classes: 1,
      records: 0,
    );

    await expectLater(service.restore(backup), throwsFormatException);

    expect(
      Hive.box<ClassEntry>(HiveConstants.classBox).get('class-1')!.title,
      'Keep this class',
    );
  });

  test(
    'failed deletion leaves the last verified-backup status intact',
    () async {
      final authorization = _Authorization();
      final now = DateTime(2026, 10, 7, 12).millisecondsSinceEpoch;
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
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'files': [fileJson('first'), fileJson('second')],
              }),
              200,
            );
          }
          if (request.method == 'DELETE' &&
              request.url.pathSegments.last == 'first') {
            return http.Response('', 204);
          }
          return http.Response('server error', 500);
        }),
      );
      await connect(service);
      await Hive.box<dynamic>(HiveConstants.settingsBox).putAll({
        BackupReminder.driveLastBackupAtKey: now,
        BackupReminder.driveChangesKey: 0,
      });

      await expectLater(
        service.deleteBackups(),
        throwsA(isA<DriveBackupException>()),
      );

      expect(
        Hive.box<dynamic>(HiveConstants.settingsBox)
            .get(BackupReminder.driveLastBackupAtKey),
        now,
      );
    },
  );
}
