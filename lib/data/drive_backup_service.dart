import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../core/hive_constants.dart';
import '../core/snapshot_storage.dart';
import 'backup_reminder.dart';
import 'backup_service.dart';
import 'drive_authorization.dart';
import 'models/class_entry.dart';
import 'models/snapshot_entry.dart';

class DriveBackupException implements Exception {
  const DriveBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DriveBackup {
  const DriveBackup({
    required this.id,
    required this.createdAt,
    required this.size,
    required this.checksum,
    required this.classes,
    required this.records,
  });

  final String id;
  final DateTime createdAt;
  final int size;
  final String checksum;
  final int classes;
  final int records;

  factory DriveBackup.fromJson(Map<String, dynamic> json) {
    final properties = json['appProperties'];
    final appProperties = properties is Map<String, dynamic>
        ? properties
        : const <String, dynamic>{};
    final id = json['id'];
    final created = json['createdTime'];
    final size = json['size'];
    final checksum = json['md5Checksum'];
    if (id is! String ||
        created is! String ||
        size is! String ||
        checksum is! String) {
      throw const FormatException('Google Drive returned an invalid backup.');
    }
    return DriveBackup(
      id: id,
      createdAt: DateTime.parse(created).toLocal(),
      size: int.parse(size),
      checksum: checksum,
      classes:
          int.tryParse(
            appProperties['classes'] is String
                ? appProperties['classes'] as String
                : '',
          ) ??
          0,
      records:
          int.tryParse(
            appProperties['records'] is String
                ? appProperties['records'] as String
                : '',
          ) ??
          0,
    );
  }
}

/// User-initiated requests only. Tokens exist only for this screen's lifetime.
/// Immutable uploads preserve previous copies until the new one is verified.
class DriveBackupService {
  DriveBackupService({
    http.Client? client,
    DriveAuthorizationClient? authorization,
  }) : _client = client ?? http.Client(),
       _authorization = authorization ?? const DriveAuthorization();

  static const retainedCopies = 5;
  static const maxBackupBytes = 64 * 1024 * 1024;
  static const _fields = 'id,createdTime,size,md5Checksum,appProperties';
  final http.Client _client;
  final DriveAuthorizationClient _authorization;
  String? _accessToken;
  String? _authorizedEmail;
  bool _closed = false;

  static Box<dynamic> get _settings =>
      Hive.box<dynamic>(HiveConstants.settingsBox);
  static String? get email {
    final value = _settings.get(BackupReminder.driveEmailKey);
    return value is String && value.isNotEmpty ? value : null;
  }

  static DateTime? get lastUploadedAt {
    final value = _settings.get(BackupReminder.driveLastBackupAtKey) as int?;
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  bool get isAuthorized =>
      _accessToken != null &&
      _authorizedEmail != null &&
      _authorizedEmail!.toLowerCase() == email?.toLowerCase();

  Future<void> connect({bool chooseAccount = false}) async {
    if (_settings.get(BackupReminder.driveConsentKey) != true) {
      throw const DriveBackupException(
        'Enable Google Drive backup to continue.',
      );
    }
    final previous = email;
    _accessToken = await _authorization.authorize(
      chooseAccount ? null : previous,
    );
    final response = await _request(
      'GET',
      _uri('/drive/v3/about', {'fields': 'user(emailAddress)'}),
    );
    final user = _json(response)['user'];
    final selected = user is Map<String, dynamic>
        ? user['emailAddress'] as String?
        : null;
    if (selected == null ||
        selected.isEmpty ||
        (!chooseAccount &&
            previous != null &&
            selected.toLowerCase() != previous.toLowerCase())) {
      _accessToken = null;
      throw const DriveBackupException(
        'Could not confirm your Google account. Choose the account again.',
      );
    }
    final accountChanged = previous?.toLowerCase() != selected.toLowerCase();
    _authorizedEmail = selected;
    await _settings.putAll({
      BackupReminder.driveEmailKey: selected,
      if (accountChanged) ...{
        BackupReminder.driveLastBackupAtKey: null,
        BackupReminder.driveChangesKey: 1,
        BackupReminder.snoozeUntilKey: null,
      },
    });
  }

  /// Returns whether old-copy cleanup also completed. Upload success is separate.
  Future<bool> upload() async {
    _requireAccount();
    await openSnapshotBox();
    final classes = Hive.box<ClassEntry>(HiveConstants.classBox);
    if (classes.isEmpty) {
      throw const DriveBackupException(
        'There are no classes to back up. Use Restore to recover a previous backup.',
      );
    }
    final includedChanges = BackupReminder.pendingChanges(drive: true);
    final bytes = utf8.encode(BackupService.buildBackupJson());
    if (bytes.length > maxBackupBytes) {
      throw const DriveBackupException(
        'This backup exceeds 64 MB. Save a backup file instead.',
      );
    }
    final metadata = {
      'name':
          'AttendX_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json',
      'mimeType': 'application/json',
      'parents': ['appDataFolder'],
      'appProperties': {
        'attendxBackup': '1',
        'classes': '${classes.length}',
        'records':
            '${Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).length}',
      },
    };
    final started = await _request(
      'POST',
      _uri('/upload/drive/v3/files', {
        'uploadType': 'resumable',
        'fields': _fields,
      }),
      body: utf8.encode(jsonEncode(metadata)),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'application/json',
        'X-Upload-Content-Length': '${bytes.length}',
      },
    );
    final location = Uri.tryParse(started.headers['location'] ?? '');
    if (location == null ||
        location.scheme != 'https' ||
        location.host != 'www.googleapis.com' ||
        !location.path.startsWith('/upload/drive/v3/files')) {
      throw const DriveBackupException(
        'Google Drive did not start the upload. Try again.',
      );
    }
    final completed = await _request(
      'PUT',
      location,
      body: bytes,
      headers: {'Content-Type': 'application/json'},
    );
    final backup = DriveBackup.fromJson(_json(completed));
    if (backup.size != bytes.length ||
        backup.checksum != md5.convert(bytes).toString()) {
      throw const DriveBackupException(
        'Google Drive could not confirm the complete backup. Previous backups are kept.',
      );
    }
    await BackupReminder.recordBackupSaved(
      drive: true,
      includedChanges: includedChanges,
    );

    // Never remove an older backup before the new upload is acknowledged.
    try {
      final backups = await listBackups();
      for (final old in backups.skip(retainedCopies)) {
        await _request(
          'DELETE',
          _uri('/drive/v3/files/${Uri.encodeComponent(old.id)}'),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<DriveBackup>> listBackups() async {
    _requireAccount();
    final backups = <DriveBackup>[];
    String? page;
    do {
      final response = await _request(
        'GET',
        _uri('/drive/v3/files', {
          'spaces': 'appDataFolder',
          'q': "trashed = false and appProperties has { key='attendxBackup' and value='1' }",
          'orderBy': 'createdTime desc',
          'pageSize': '100',
          'fields': 'nextPageToken,files($_fields)',
          if (page != null) 'pageToken': page,
        }),
      );
      final data = _json(response);
      for (final file in data['files'] as List<dynamic>? ?? const []) {
        // Ignore incomplete or malformed entries.
        final size = file is Map<String, dynamic> ? file['size'] : null;
        if (file is! Map<String, dynamic> ||
            file['md5Checksum'] == null ||
            size is! String ||
            int.tryParse(size) == null) {
          continue;
        }
        backups.add(DriveBackup.fromJson(file));
      }
      page = data['nextPageToken'] is String
          ? data['nextPageToken'] as String
          : null;
    } while (page != null);
    return backups;
  }

  Future<BackupRestoreResult> restore(DriveBackup backup) async {
    _requireAccount();
    if (backup.size > maxBackupBytes) {
      throw const DriveBackupException(
        'This backup exceeds the supported 64 MB size.',
      );
    }
    final response = await _request(
      'GET',
      _uri('/drive/v3/files/${Uri.encodeComponent(backup.id)}', {
        'alt': 'media',
      }),
      maxResponseBytes: maxBackupBytes,
    );
    if (response.bodyBytes.length != backup.size ||
        md5.convert(response.bodyBytes).toString() != backup.checksum) {
      throw const DriveBackupException(
        'The downloaded backup is incomplete. Your local data has not been changed.',
      );
    }
    final result = await BackupService.restoreFromJson(
      utf8.decode(response.bodyBytes),
    );
    await BackupReminder.recordDataChange();
    return result;
  }

  Future<void> deleteBackups() async {
    _requireAccount();
    final backups = await listBackups();
    for (final backup in backups) {
      await _request(
        'DELETE',
        _uri('/drive/v3/files/${Uri.encodeComponent(backup.id)}'),
      );
    }
    // Clear the displayed status only after every deletion is confirmed.
    await _settings.putAll({
      BackupReminder.driveLastBackupAtKey: null,
      BackupReminder.driveChangesKey: 1,
      BackupReminder.snoozeUntilKey: null,
    });
  }

  Future<void> disconnect() async {
    final connected = email;
    Object? revocationFailure;
    try {
      if (connected != null) {
        await _authorization.disconnect(connected);
      }
    } catch (error) {
      revocationFailure = error;
    } finally {
      _accessToken = null;
      _authorizedEmail = null;
      await _settings.putAll({
        BackupReminder.driveEmailKey: null,
        BackupReminder.driveLastBackupAtKey: null,
        BackupReminder.driveConsentKey: false,
      });
    }
    if (revocationFailure != null) {
      throw const DriveBackupException(
        'AttendX was disconnected on this phone, but Google could not revoke access. Remove AttendX from your Google Account connections when you are online.',
      );
    }
  }

  void _requireAccount() {
    if (_accessToken == null ||
        _authorizedEmail == null ||
        _authorizedEmail!.toLowerCase() != email?.toLowerCase()) {
      throw const DriveBackupException('Connect your Google account first.');
    }
  }

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.https('www.googleapis.com', path, query);

  static Map<String, dynamic> _json(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Google Drive returned an invalid response.');
    }
    return data;
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    List<int>? body,
    Map<String, String> headers = const {},
    int maxResponseBytes = 2 * 1024 * 1024,
  }) async {
    if (_closed) {
      throw const DriveBackupException('Backup screen closed. Try again.');
    }
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({'Authorization': 'Bearer $_accessToken', ...headers});
    if (body != null) request.bodyBytes = body;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 90),
    )) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const DriveBackupException(
          'Google Drive returned a file that is too large.',
        );
      }
      bytes.add(chunk);
    }
    final result = http.Response.bytes(
      bytes.takeBytes(),
      response.statusCode,
      headers: response.headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DriveBackupException(switch (response.statusCode) {
        401 => 'Google access expired. Tap the action again to reconnect.',
        403 => 'Google Drive denied access. Check account permissions and available Drive storage, then try again.',
        404 => 'This backup is no longer available in Google Drive.',
        429 => 'Google Drive is busy. Wait a moment and try again.',
        _ => 'Google Drive could not complete the request. Try again. Previous backups are kept.',
      });
    }
    return result;
  }

  void close() {
    _closed = true;
    _accessToken = null;
    _client.close();
  }
}

String driveErrorMessage(Object error) {
  if (error is DriveBackupException) return error.message;
  if (error is FormatException) return error.message;
  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return 'Could not reach Google Drive. Check your internet connection and try again. No backup was confirmed.';
  }
  if (error is PlatformException) {
    return switch (error.code) {
      'cancelled' => 'Google Drive connection cancelled.',
      'configuration' => 'Google Drive is not configured for this app build. Contact the app developer.',
      'network' => 'Connect to the internet and try again.',
      'permission' => 'Allow AttendX backup access to continue.',
      _ =>
        'Could not connect Google Drive. Try again or choose another account.',
    };
  }
  return 'Could not complete the Google Drive action. Try again.';
}
