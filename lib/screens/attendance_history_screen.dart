import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';
import '../data/models/snapshot_entry.dart';
import '../widgets/export_bottom_sheet.dart';
import 'attendance_grid_screen.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key, required this.classEntry});

  final ClassEntry classEntry;

  @override
  Widget build(BuildContext context) {
    final snapshotBox = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox);

    return Scaffold(
      appBar: AppBar(
        title: Text(classEntry.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => ExportBottomSheet(
                  preselectedClassId: classEntry.classId,
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<SnapshotEntry>>(
        valueListenable: snapshotBox.listenable(),
        builder: (context, box, _) {
          final snapshots = box.values
              .where((snapshot) => snapshot.classId == classEntry.classId)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (snapshots.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text('No attendance recorded yet'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: snapshots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final snapshot = snapshots[index];
              final absentCount = snapshot.snapshotData
                  .where((row) => row['isAbsent'] == true)
                  .length;
              final presentCount = snapshot.snapshotData.length - absentCount;

              return ListTile(
                title: Text(
                  DateFormat(
                    'EEE, dd MMM yyyy \u00B7 h:mm a',
                  ).format(snapshot.timestamp),
                ),
                subtitle: Text(
                  'Present: $presentCount  |  Absent: $absentCount',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AttendanceGridScreen(
                          classEntry: classEntry,
                          existingSnapshot: snapshot,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
