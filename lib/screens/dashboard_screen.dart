import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';
import '../providers/class_list_provider.dart';
import 'about_screen.dart';
import 'attendance_history_screen.dart';

String _dayLabel(int d) {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[d.clamp(0, 6)];
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClasses = ref.watch(classListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AttendX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: asyncClasses.when(
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 96,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes yet. Tap + to add one.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final currentWeekday = now.weekday - 1;
          final currentHour = now.hour;

          final suggested = classes.where((c) {
            if (!c.weekdays.contains(currentWeekday)) return false;
            return (currentHour - c.startHour).abs() <= 2;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (suggested.isNotEmpty) ...[
                Text(
                  'Now / Upcoming',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: suggested
                          .map(
                            (c) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(c.title),
                              subtitle: Text(
                                '${c.totalStudents} students',
                              ),
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  '/grid',
                                  arguments: c,
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'All classes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...classes.map((c) {
                final sub =
                    '${c.totalStudents} students \u00B7 ${c.weekdays.map(_dayLabel).join(', ')}';
                return ListTile(
                  title: Text(c.title),
                  subtitle: Text(sub),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AttendanceHistoryScreen(classEntry: c),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Class?'),
                              content: Text(
                                "This will permanently delete '${c.title}'\n"
                                'and all its attendance history.\n'
                                'This cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && context.mounted) {
                            await Hive.box<ClassEntry>(HiveConstants.classBox)
                                .delete(c.classId);
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      '/grid',
                      arguments: c,
                    );
                  },
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/ingest');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
