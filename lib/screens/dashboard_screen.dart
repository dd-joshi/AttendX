import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_theme.dart';
import '../core/hive_constants.dart';
import '../data/backup_reminder.dart';
import '../data/class_schedule.dart';
import '../data/delete_class_data.dart';
import '../data/models/class_entry.dart';
import '../widgets/app_ui.dart';
import '../widgets/backup_bottom_sheet.dart';
import '../widgets/export_bottom_sheet.dart';
import 'about_screen.dart';

String _dayLabel(int day) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[day.clamp(0, 6)];
}

/// Compresses consecutive weekdays into runs, e.g. [0, 1, 2, 4] -> "Mon–Wed Thu".
String _dayRunsLabel(List<int> days) {
  if (days.isEmpty) return '';
  final sorted = [...days]..sort();
  final parts = <String>[];
  var start = sorted.first;
  var end = sorted.first;
  for (var i = 1; i <= sorted.length; i++) {
    final day = i < sorted.length ? sorted[i] : -1;
    if (day == end + 1) {
      end = day;
      continue;
    }
    parts.add(
      end - start >= 2
          ? '${_dayLabel(start)}\u2013${_dayLabel(end)}'
          : end > start
          ? '${_dayLabel(start)} ${_dayLabel(end)}'
          : _dayLabel(start),
    );
    if (day >= 0) {
      start = day;
      end = day;
    }
  }
  return parts.join(' ');
}

void _openSheet(BuildContext context, Widget sheet) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => sheet,
  );
}

void _openClass(BuildContext context, ClassEntry classEntry) {
  Navigator.of(context).pushNamed(
    classEntry.hasRoster ? '/grid' : '/roster',
    arguments: classEntry,
  );
}

Future<void> _confirmDeleteClass(
  BuildContext context,
  ClassEntry classEntry,
) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete class?'),
      content: Text(
        "This permanently deletes '${classEntry.title}' and all of its "
        'attendance. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.absent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (shouldDelete != true) return;
  try {
    await deleteClassData(classEntry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("'${classEntry.title}' deleted")));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not delete class')));
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AttendX',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'export') {
                _openSheet(context, const ExportBottomSheet());
              } else if (value == 'backup') {
                _openSheet(context, const BackupBottomSheet());
              } else if (value == 'about') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 21),
                    SizedBox(width: 12),
                    Text('Export CSV'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.settings_backup_restore, size: 21),
                    SizedBox(width: 12),
                    Text('Backup & restore'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 21),
                    SizedBox(width: 12),
                    Text('About'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<ClassEntry>>(
        valueListenable: Hive.box<ClassEntry>(HiveConstants.classBox)
            .listenable(),
        builder: (context, box, _) {
          final classes = box.values.toList(growable: false);
          if (classes.isEmpty) return const _EmptyDashboard();

          final now = DateTime.now();
          final orderedClasses = sortClassesByNextOccurrence(classes, now);
          final currentWeekday = now.weekday - 1;
          final currentHour = now.hour;
          final suggested = orderedClasses.where((classEntry) {
            return classEntry.weekdays.contains(currentWeekday) &&
                (currentHour - classEntry.hourForWeekday(currentWeekday))
                        .abs() <=
                    2;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const _BackupReminderBanner(),
              if (suggested.isNotEmpty) ...[
                const _SectionTitle('Now / Upcoming'),
                const SizedBox(height: 8),
                _ClassGroup(
                  classes: suggested,
                  color: AppColors.primarySoft,
                  showMenu: false,
                ),
                const SizedBox(height: 28),
              ],
              const _SectionTitle('All classes'),
              const SizedBox(height: 8),
              _ClassGroup(classes: orderedClasses, showMenu: true),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/create'),
        tooltip: 'Create class',
        icon: const Icon(Icons.add),
        label: const Text('New class'),
      ),
    );
  }
}

class _BackupReminderBanner extends StatelessWidget {
  const _BackupReminderBanner();

  @override
  Widget build(BuildContext context) {
    // Purely informational; never fail when the settings box is unavailable.
    if (!Hive.isBoxOpen(HiveConstants.settingsBox)) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: Hive.box<dynamic>(HiveConstants.settingsBox)
          .listenable(),
      builder: (context, box, _) {
        if (!BackupReminder.isDue()) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: AppSurface(
            color: AppColors.primarySoft,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.settings_backup_restore,
                      size: 21,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Time for a backup',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep a current copy of your classes and attendance.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () =>
                          _openSheet(context, const BackupBottomSheet()),
                      child: const Text('Back up now'),
                    ),
                    const SizedBox(width: 8),
                    const TextButton(
                      onPressed: BackupReminder.snooze,
                      child: Text('Later'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _ClassGroup extends StatelessWidget {
  const _ClassGroup({
    required this.classes,
    required this.showMenu,
    this.color = AppColors.surface,
  });

  final List<ClassEntry> classes;
  final bool showMenu;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(classes.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const Divider(indent: 16, endIndent: 16);
          }
          final classEntry = classes[index ~/ 2];
          return _ClassTile(classEntry: classEntry, showMenu: showMenu);
        }),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.classEntry, required this.showMenu});

  final ClassEntry classEntry;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    String timeLabel(int day) => TimeOfDay(
      hour: classEntry.hourForWeekday(day),
      minute: classEntry.minuteForWeekday(day),
    ).format(context);

    final days = classEntry.weekdays;
    final distinctTimes = days.map(timeLabel).toSet();
    final schedule = days.isEmpty
        ? ''
        : distinctTimes.length == 1
        ? '${_dayRunsLabel(days)} \u00B7 ${distinctTimes.first}'
        : days
              .map((day) => '${_dayLabel(day)} ${timeLabel(day)}')
              .join(' \u00B7 ');
    final type = classEntry.effectiveClassType;
    final isLab = type == ClassTypes.lab;
    final isLecture = type == ClassTypes.lecture;
    final iconColor = isLab
        ? AppColors.lab
        : isLecture
        ? AppColors.primary
        : AppColors.textSecondary;

    return ListTile(
      minTileHeight: 68,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          isLab ? Icons.science_outlined : Icons.menu_book_outlined,
          size: 21,
          color: iconColor,
        ),
      ),
      title: Text(
        classEntry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 17),
      ),
      subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            classEntry.hasRoster
                ? '${classEntry.classTypeLabel} \u00B7 '
                      '${classEntry.rosterSize} students'
                : '${classEntry.classTypeLabel} \u00B7 '
                      '${classEntry.rosterSize} students \u00B7 Add roster',
          ),
          const SizedBox(height: 2),
          Text(schedule, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: showMenu
          ? PopupMenuButton<String>(
              tooltip: 'Class options',
              onSelected: (value) {
                if (value == 'manage') {
                  Navigator.of(context)
                      .pushNamed('/manage', arguments: classEntry);
                } else if (value == 'delete') {
                  unawaited(_confirmDeleteClass(context, classEntry));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'manage',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 21),
                      SizedBox(width: 12),
                      Text('Manage class'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 21,
                        color: AppColors.absent,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Delete class',
                        style: TextStyle(color: AppColors.absent),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Icon(
              classEntry.hasRoster
                  ? Icons.chevron_right
                  : Icons.person_add_alt_1_outlined,
              color: classEntry.hasRoster
                  ? AppColors.textDisabled
                  : AppColors.primary,
            ),
      onTap: () => _openClass(context, classEntry),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.class_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create your first class',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add class details and its roster.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
