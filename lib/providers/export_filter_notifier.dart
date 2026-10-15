import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/hive_constants.dart';
import '../core/snapshot_storage.dart';
import '../data/models/class_entry.dart';
import '../data/models/snapshot_entry.dart';
import '../export/build_csv_matrix.dart';
import '../export/export_file_name.dart';

class ExportFilterState {
  ExportFilterState({
    this.selectedClassId,
    DateTime? fromDate,
    DateTime? toDate,
    this.isExporting = false,
    this.exportError,
  }) : fromDate = fromDate ?? _defaultFrom(),
       toDate = toDate ?? _defaultTo();

  static DateTime _defaultFrom() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(const Duration(days: 30));
  }

  static DateTime _defaultTo() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  final String? selectedClassId;
  final DateTime fromDate;
  final DateTime toDate;
  final bool isExporting;
  final String? exportError;

  ExportFilterState copyWith({
    String? selectedClassId,
    DateTime? fromDate,
    DateTime? toDate,
    bool? isExporting,
    String? exportError,
    bool clearError = false,
  }) {
    return ExportFilterState(
      selectedClassId: selectedClassId ?? this.selectedClassId,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      isExporting: isExporting ?? this.isExporting,
      exportError: clearError ? null : (exportError ?? this.exportError),
    );
  }
}

class ExportFilterNotifier extends StateNotifier<ExportFilterState> {
  ExportFilterNotifier() : super(ExportFilterState());

  void reset() {
    state = ExportFilterState();
  }

  void setClass(String? id) {
    state = ExportFilterState(
      selectedClassId: id,
      fromDate: state.fromDate,
      toDate: state.toDate,
      isExporting: state.isExporting,
    );
  }

  void setFromDate(DateTime date) {
    state = state.copyWith(
      fromDate: DateTime(date.year, date.month, date.day),
      clearError: true,
    );
  }

  void setToDate(DateTime date) {
    state = state.copyWith(
      toDate: DateTime(date.year, date.month, date.day, 23, 59, 59, 999),
      clearError: true,
    );
  }

  Future<void> runExport() async {
    if (state.isExporting) return;
    final classId = state.selectedClassId;
    if (classId == null) {
      state = state.copyWith(exportError: 'Select a class');
      return;
    }
    if (state.fromDate.isAfter(state.toDate)) {
      state = state.copyWith(
        exportError: 'From date must be before or equal to To date',
      );
      return;
    }

    state = state.copyWith(isExporting: true, clearError: true);
    final from = DateTime(
      state.fromDate.year,
      state.fromDate.month,
      state.fromDate.day,
    );
    final to = DateTime(
      state.toDate.year,
      state.toDate.month,
      state.toDate.day,
    );

    try {
      final snapshotBox = await openSnapshotBox();
      if (!mounted) return;
      final classBox = Hive.box<ClassEntry>(HiveConstants.classBox);
      final classEntry = classBox.get(classId);
      if (classEntry == null) {
        state = state.copyWith(
          isExporting: false,
          exportError: 'Selected class could not be found',
        );
        return;
      }

      final canonicalByDate = <String, SnapshotEntry>{};
      for (final snapshot in snapshotBox.values) {
        if (snapshot.classId != classId) continue;
        final date = snapshot.effectiveAttendanceDate;
        if (date.isBefore(from) || date.isAfter(to)) continue;

        final key =
            '${date.year}-${date.month}-${date.day}|${snapshot.effectiveSessionType}';
        final current = canonicalByDate[key];
        if (current == null || snapshot.timestamp.isAfter(current.timestamp)) {
          canonicalByDate[key] = snapshot;
        }
      }

      final filtered = canonicalByDate.values;
      if (filtered.isEmpty) {
        state = state.copyWith(
          isExporting: false,
          exportError: 'No data for selected range',
        );
        return;
      }

      final serialized = filtered.map<Map<String, dynamic>>((snapshot) {
        return <String, dynamic>{
          'timestamp': snapshot.timestamp,
          'attendanceDate': snapshot.effectiveAttendanceDate,
          'sessionType': snapshot.effectiveSessionType,
          'topic': snapshot.topic,
          'snapshotData': snapshot.snapshotData,
        };
      }).toList();

      final csv = await compute(buildCsvMatrix, serialized);
      if (!mounted) return;

      final directory = await getTemporaryDirectory();
      if (!mounted) return;
      final percent = attendancePercentOf(
        filtered.map((snapshot) => snapshot.snapshotData),
      );
      final file = File(
        '${directory.path}/'
        '${buildExportFileName(classTitle: classEntry.title, from: from, to: to, percent: percent)}',
      );
      // Help Excel recognize UTF-8 names and topics.
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Attendance export \u2014 ${classEntry.title}',
        ),
      );

      if (mounted) state = state.copyWith(isExporting: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isExporting: false,
        exportError: 'Could not export attendance. Try again.',
      );
    }
  }
}

final exportFilterNotifier =
    StateNotifierProvider.autoDispose<ExportFilterNotifier, ExportFilterState>(
      (ref) => ExportFilterNotifier(),
    );
