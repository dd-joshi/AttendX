import 'package:intl/intl.dart';

/// Overall present-percentage across every saved mark in the exported range.
///
/// [sessions] holds one `snapshotData` row list per saved session. Returns
/// null when no marks exist, so callers can leave the figure out entirely.
int? attendancePercentOf(Iterable<List<Map<String, dynamic>>> sessions) {
  var present = 0;
  var total = 0;
  for (final rows in sessions) {
    for (final row in rows) {
      total += 1;
      if (row['isAbsent'] != true) present += 1;
    }
  }
  if (total == 0) return null;
  return (present * 100 / total).round();
}

/// CSV file name carrying the class title, the exported date range, and the
/// overall attendance percentage when one can be computed.
///
/// Example: `AttendX_Class A_2026-07-10_to_2026-08-09_85pct.csv`
String buildExportFileName({
  required String classTitle,
  required DateTime from,
  required DateTime to,
  int? percent,
}) {
  final safeTitle = classTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  final dateFmt = DateFormat('yyyy-MM-dd');
  final range = '${dateFmt.format(from)}_to_${dateFmt.format(to)}';
  final percentPart = percent == null ? '' : '_${percent}pct';
  return 'AttendX_'
      '${safeTitle.isEmpty ? 'Class' : safeTitle}'
      '_$range$percentPart.csv';
}
