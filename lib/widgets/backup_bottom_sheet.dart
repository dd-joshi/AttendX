import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/snapshot_storage.dart';
import '../data/backup_reminder.dart';
import '../data/backup_service.dart';
import '../data/drive_backup_service.dart';
import 'app_ui.dart';

/// Lets the teacher keep a JSON file or make a user-requested Drive backup.
class BackupBottomSheet extends StatefulWidget {
  const BackupBottomSheet({super.key, this.driveService});

  /// Injectable for tests. The sheet owns a service it creates itself.
  final DriveBackupService? driveService;

  @override
  State<BackupBottomSheet> createState() => _BackupBottomSheetState();
}

class _BackupBottomSheetState extends State<BackupBottomSheet> {
  late final DriveBackupService _drive;
  late final bool _ownsDrive;
  bool _busy = false;
  String? _status;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _ownsDrive = widget.driveService == null;
    _drive = widget.driveService ?? DriveBackupService();
  }

  @override
  void dispose() {
    if (_ownsDrive) {
      _drive.close();
    }
    super.dispose();
  }

  void _showStatus(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _isError = error;
    });
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? fallbackError,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } catch (error) {
      _showStatus(
        fallbackError != null && error is! FormatException
            ? fallbackError
            : driveErrorMessage(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String action = 'Continue',
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _allowDrive() async {
    if (BackupReminder.hasDriveConsent) return true;
    final accepted = await _confirm(
      'Enable Google Drive backup?',
      'AttendX will save your classes, student names and roll numbers, and '
          'attendance to a private folder in the Google account you choose. '
          'Backups run only when you tap Back up now. Up to five copies are kept.',
      action: 'Enable',
    );
    if (accepted) {
      await BackupReminder.grantDriveConsent();
    }
    return accepted;
  }

  Future<void> _connectDrive({bool chooseAccount = false}) async {
    if (!await _allowDrive()) return;
    if (_drive.isAuthorized && !chooseAccount) return;
    await _drive.connect(
      chooseAccount: chooseAccount || DriveBackupService.email == null,
    );
  }

  Future<void> _saveBackupFile() => _run(() async {
    await openSnapshotBox();
    final includedChanges = BackupReminder.pendingChanges();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final destination = await FilePicker.saveFile(
      fileName: 'AttendX_backup_$stamp.json',
      bytes: utf8.encode(BackupService.buildBackupJson()),
      mimeType: 'application/json',
    );
    if (destination == null) {
      _showStatus('Backup cancelled. No file was saved.');
      return;
    }
    await BackupReminder.recordBackupSaved(includedChanges: includedChanges);
    _showStatus(
      'Backup saved to your chosen location. Keep a copy outside this phone.',
    );
  }, fallbackError: 'Could not create the backup file.');

  Future<void> _restoreBackupFile() async {
    if (_busy ||
        !await _confirm(
          'Restore from backup?',
          'The backup will be merged with data on this device. Matching classes '
              'and attendance will be replaced.',
          action: 'Choose file',
        )) {
      return;
    }
    await _run(() async {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) {
        _showStatus('Restore cancelled.');
        return;
      }
      final result = await BackupService.restoreFromJson(
        utf8.decode(await file.readAsBytes()),
      );
      await BackupReminder.recordDataChange();
      _showStatus(
        'Restored ${_countLabel(result.classes, 'class', 'classes')} and '
        '${_countLabel(result.snapshots, 'attendance record', 'attendance records')}.',
      );
    }, fallbackError: 'Could not restore the backup file.');
  }

  Future<void> _backUpToDrive() => _run(() async {
    await _connectDrive();
    if (!_drive.isAuthorized) return;
    final cleaned = await _drive.upload();
    _showStatus(
      cleaned
          ? 'Backup saved to Google Drive.'
          : 'Backup saved. Older backups will be cleaned up next time.',
    );
  });

  Future<void> _restoreFromDrive() => _run(() async {
    await _connectDrive();
    if (!_drive.isAuthorized) return;
    final backups = await _drive.listBackups();
    if (backups.isEmpty) {
      _showStatus('No AttendX backups found in this Google account.');
      return;
    }
    if (!mounted) return;
    final chosen = await showDialog<DriveBackup>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Restore from Google Drive',
          style: Theme.of(dialogContext).textTheme.titleMedium,
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(dialogContext).colorScheme.outlineVariant,
              ),
              itemBuilder: (_, index) {
                final backup = backups[index];
                return _BackupTile(
                  backup: backup,
                  onTap: () => Navigator.of(dialogContext).pop(backup),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (chosen == null) {
      _showStatus('Restore cancelled.');
      return;
    }
    if (!await _confirm(
      'Restore selected backup?',
      'The backup will be merged with data on this device. Matching classes '
          'and attendance will be replaced.',
      action: 'Restore',
    )) {
      _showStatus('Restore cancelled.');
      return;
    }
    final result = await _drive.restore(chosen);
    _showStatus(
      'Restored ${_countLabel(result.classes, 'class', 'classes')} and '
      '${_countLabel(result.snapshots, 'attendance record', 'attendance records')}.',
    );
  });

  Future<void> _deleteDriveBackups() async {
    if (_busy ||
        !await _confirm(
          'Delete Google Drive backups?',
          'Permanently delete all AttendX backups from Google Drive? Data on '
              'this device will stay.',
          action: 'Delete backups',
          destructive: true,
        )) {
      return;
    }
    await _run(() async {
      await _connectDrive();
      if (!_drive.isAuthorized) return;
      await _drive.deleteBackups();
      _showStatus('All AttendX backups were deleted from Google Drive.');
    });
  }

  Future<void> _disconnectDrive() async {
    if (_busy ||
        !await _confirm(
          'Disconnect Google Drive?',
          'AttendX will stop using this Google account. Existing backups will '
              'remain in Google Drive.',
          action: 'Disconnect',
        )) {
      return;
    }
    await _run(() async {
      await _drive.disconnect();
      _showStatus('Google Drive disconnected. Existing Drive backups remain.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = DriveBackupService.email;
    final uploaded = DriveBackupService.lastUploadedAt;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Backup & restore',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Back up to Google Drive or save a file.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_status != null) ...[
              InlineMessage(isError: _isError, child: Text(_status!)),
              const SizedBox(height: 12),
            ],
            _DriveSection(
              email: email,
              uploaded: uploaded,
              busy: _busy,
              onBackUp: _backUpToDrive,
              onRestore: _restoreFromDrive,
              onConnect: () => _run(() => _connectDrive(chooseAccount: true)),
              onChangeAccount: () =>
                  _run(() => _connectDrive(chooseAccount: true)),
              onDisconnect: _disconnectDrive,
              onDelete: _deleteDriveBackups,
            ),
            const SizedBox(height: 20),
            Text('Backup file', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Save or restore a backup file on this device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.tonal(
                onPressed: _busy ? null : _saveBackupFile,
                child: const Text('Save backup file'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _busy ? null : _restoreBackupFile,
                child: const Text('Restore from file'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({required this.backup, required this.onTap});

  final DriveBackup backup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      label:
          '${DateFormat('d MMM yyyy, h:mm a').format(backup.createdAt)}, '
          '${_countLabel(backup.classes, 'class', 'classes')}, '
          '${_countLabel(backup.records, 'attendance record', 'attendance records')}, '
          '${_fileSize(backup.size)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('d MMM yyyy').format(backup.createdAt),
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('h:mm a').format(backup.createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_countLabel(backup.classes, 'class', 'classes')} · '
                            '${_countLabel(backup.records, 'record', 'records')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fileSize(backup.size),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _countLabel(int count, String singular, String plural) =>
    '$count ${count == 1 ? singular : plural}';

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _DriveSection extends StatelessWidget {
  const _DriveSection({
    required this.email,
    required this.uploaded,
    required this.busy,
    required this.onBackUp,
    required this.onRestore,
    required this.onConnect,
    required this.onChangeAccount,
    required this.onDisconnect,
    required this.onDelete,
  });

  final String? email;
  final DateTime? uploaded;
  final bool busy;
  final VoidCallback onBackUp;
  final VoidCallback onRestore;
  final VoidCallback onConnect;
  final VoidCallback onChangeAccount;
  final VoidCallback onDisconnect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final account = email;
    final lastBackup = uploaded;
    final connected = account != null;
    return AppSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Google Drive',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (connected)
                PopupMenuButton<_DriveAction>(
                  enabled: !busy,
                  tooltip: 'Google Drive options',
                  onSelected: (action) {
                    switch (action) {
                      case _DriveAction.changeAccount:
                        onChangeAccount();
                      case _DriveAction.disconnect:
                        onDisconnect();
                      case _DriveAction.deleteBackups:
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _DriveAction.changeAccount,
                      child: _DriveMenuItem(
                        icon: Icons.manage_accounts_outlined,
                        label: 'Change account',
                      ),
                    ),
                    PopupMenuItem(
                      value: _DriveAction.disconnect,
                      child: _DriveMenuItem(
                        icon: Icons.link_off_outlined,
                        label: 'Disconnect',
                      ),
                    ),
                    PopupMenuItem(
                      value: _DriveAction.deleteBackups,
                      child: _DriveMenuItem(
                        icon: Icons.delete_outline,
                        label: 'Delete Drive backups',
                        destructive: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Backups are private to your Google account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (connected)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (lastBackup != null)
                        Text(
                          'Last backup ${DateFormat('d MMM yyyy, h:mm a').format(lastBackup)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            )
          else
            Text('Not connected', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (!connected)
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: busy ? null : onConnect,
                icon: const Icon(Icons.add_to_drive_outlined),
                label: const Text('Connect Google Drive'),
              ),
            )
          else ...[
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: busy ? null : onBackUp,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Back up now'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRestore,
                icon: const Icon(Icons.restore),
                label: const Text('Restore backup'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DriveAction { changeAccount, disconnect, deleteBackups }

class _DriveMenuItem extends StatelessWidget {
  const _DriveMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
