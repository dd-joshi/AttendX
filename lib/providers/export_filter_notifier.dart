import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';
import '../data/models/export_payload.dart';
import '../data/models/snapshot_entry.dart';
import '../export/build_csv_matrix.dart';

class ExportFilterState {
  ExportFilterState({
    this.selectedClassId,
    DateTime? fromDate,
    DateTime? toDate,
    this.isExporting = false,
    this.exportError,
  })  : fromDate = fromDate ?? _defaultFrom(),
        toDate = toDate ?? _defaultTo();

  static DateTime _defaultFrom() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return today.subtract(const Duration(days: 30));
  }

  static DateTime _defaultTo() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 23, 59, 59, 999);
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

  void setClass(String? id) {
    state = ExportFilterState(
      selectedClassId: id,
      fromDate: state.fromDate,
      toDate: state.toDate,
      isExporting: state.isExporting,
      exportError: null,
    );
  }

  void setFromDate(DateTime d) {
    state = state.copyWith(fromDate: DateTime(d.year, d.month, d.day));
  }

  void setToDate(DateTime d) {
    state = state.copyWith(
        toDate: DateTime(d.year, d.month, d.day, 23, 59, 59, 999));
  }

  Future<void> runExport() async {
    state = state.copyWith(isExporting: true, clearError: true);

    try {
      final snapshotBox = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox);
      final classBox = Hive.box<ClassEntry>(HiveConstants.classBox);

      final from = state.fromDate;
      final to = state.toDate;
      final classIdFilter = state.selectedClassId;

      final filtered = snapshotBox.values.where((s) {
        if (classIdFilter != null && s.classId != classIdFilter) {
          return false;
        }
        final t = s.timestamp;
        return !t.isBefore(from) && !t.isAfter(to);
      }).toList();

      if (filtered.isEmpty) {
        state = state.copyWith(
          isExporting: false,
          exportError: 'No data for selected range',
        );
        return;
      }

      String classTitle;
      if (classIdFilter != null) {
        classTitle = classBox.get(classIdFilter)?.title ?? 'Unknown class';
      } else {
        classTitle = 'All classes';
      }

      final serialized = filtered.map<Map<String, dynamic>>((s) {
        return <String, dynamic>{
          'snapshotId': s.snapshotId,
          'timestamp': s.timestamp,
          'classId': s.classId,
          'classTitle': s.classTitle,
          'snapshotData': s.snapshotData,
        };
      }).toList();

      final payload = ExportPayload(
        snapshots: serialized,
        classTitle: classTitle,
      );

      final csv = await compute(buildCsvMatrix, payload);

      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('ddMMMyyyy').format(DateTime.now());
      final file = File('${dir.path}/AttendX_${classTitle}_$stamp.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance export — $classTitle',
      );

      state = state.copyWith(isExporting: false);
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        exportError: e.toString(),
      );
    }
  }
}

final exportFilterNotifier =
    StateNotifierProvider<ExportFilterNotifier, ExportFilterState>(
  (ref) => ExportFilterNotifier(),
);
