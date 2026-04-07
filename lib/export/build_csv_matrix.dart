import 'package:intl/intl.dart';

import '../data/models/export_payload.dart';

/// Top-level isolate entry — must stay a top-level function for [compute].
String buildCsvMatrix(ExportPayload payload) {
  final snapshots = payload.snapshots;
  if (snapshots.isEmpty) {
    return 'Roll,Name\n';
  }

  final dateFmt = DateFormat('yyyy-MM-dd');

  DateTime asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    throw ArgumentError('timestamp');
  }

  final dateSet = <DateTime>{};
  final rollSet = <String>{};

  for (final snap in snapshots) {
    final ts = asDateTime(snap['timestamp']);
    final day = DateTime(ts.year, ts.month, ts.day);
    dateSet.add(day);

    final data = snap['snapshotData'] as List<dynamic>? ?? const [];
    for (final row in data) {
      final m = Map<String, dynamic>.from(row as Map);
      final roll = m['roll'] as String? ?? '';
      if (roll.isNotEmpty) rollSet.add(roll);
    }
  }

  final dates = dateSet.toList()..sort();
  final dateKeys = dates.map(dateFmt.format).toList();

  final rolls = rollSet.toList()
    ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

  final lookup = <String, Map<String, String>>{};
  for (final r in rolls) {
    lookup[r] = <String, String>{};
  }

  final sortedSnaps = List<Map<String, dynamic>>.from(snapshots);
  sortedSnaps.sort((a, b) {
    final ta = asDateTime(a['timestamp']);
    final tb = asDateTime(b['timestamp']);
    return ta.compareTo(tb);
  });

  final latestName = <String, String>{};
  for (final snap in sortedSnaps) {
    final data = snap['snapshotData'] as List<dynamic>? ?? const [];
    for (final row in data) {
      final m = Map<String, dynamic>.from(row as Map);
      final roll = m['roll'] as String? ?? '';
      final name = m['name'] as String? ?? '';
      latestName[roll] = name;
    }
  }

  for (final snap in sortedSnaps) {
    final ts = asDateTime(snap['timestamp']);
    final day = DateTime(ts.year, ts.month, ts.day);
    final dKey = dateFmt.format(day);

    final data = snap['snapshotData'] as List<dynamic>? ?? const [];
    for (final row in data) {
      final m = Map<String, dynamic>.from(row as Map);
      final roll = m['roll'] as String? ?? '';
      if (roll.isEmpty) continue;
      final absent = m['isAbsent'] as bool? ?? false;
      lookup.putIfAbsent(roll, () => <String, String>{});
      lookup[roll]![dKey] = absent ? 'A' : 'P';
    }
  }

  final buffer = StringBuffer()
    ..write('Roll,Name,')
    ..writeln(dateKeys.join(','));

  for (final roll in rolls) {
    buffer.write(roll);
    buffer.write(',');
    buffer.write(latestName[roll] ?? '');
    for (final dk in dateKeys) {
      buffer.write(',');
      buffer.write(lookup[roll]?[dk] ?? '-');
    }
    buffer.writeln();
  }

  return buffer.toString();
}
