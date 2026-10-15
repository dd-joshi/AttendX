import 'package:intl/intl.dart';

final _csvSpecialCharacters = RegExp('[,"\\n\\r]');
final _formulaPrefix = RegExp(r'^\s*[=+@-]');

String _csvCell(String value) {
  // A quoted CSV cell can still be interpreted as a spreadsheet formula.
  if (_formulaPrefix.hasMatch(value)) value = "'$value";
  if (!_csvSpecialCharacters.hasMatch(value)) return value;
  return '"${value.replaceAll('"', '""')}"';
}

DateTime _asDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  throw ArgumentError('Invalid export date');
}

/// Isolate entry. Visit each row once to collect marks and the latest name.
String buildCsvMatrix(List<Map<String, dynamic>> records) {
  if (records.isEmpty) return 'Roll,Name\n';

  final dateFormat = DateFormat('yyyy-MM-dd');
  final snapshots = [...records]
    ..sort(
      (a, b) =>
          _asDateTime(a['timestamp']).compareTo(_asDateTime(b['timestamp'])),
    );
  final columns = <String, Map<int, String>>{};
  final names = <int, String>{};
  final topics = <String, String>{};

  for (final snapshot in snapshots) {
    final date = _asDateTime(
      snapshot['attendanceDate'] ?? snapshot['timestamp'],
    );
    final key =
        '${dateFormat.format(date)}${snapshot['sessionType'] == 'lab' ? ' Lab' : ''}';
    // Replace the entire column for legacy duplicates, including its roster.
    final marks = <int, String>{};
    columns[key] = marks;
    topics[key] = (snapshot['topic'] as String? ?? '').trim();
    for (final row in snapshot['snapshotData'] as List<dynamic>? ?? const []) {
      final roll = int.parse(row['roll'] as String);
      names[roll] = row['name'] as String? ?? '';
      marks[roll] = row['isAbsent'] == true ? 'A' : 'P';
    }
  }

  final dates = columns.keys.toList()..sort();
  final rolls = names.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('Roll,Name,${dates.join(',')}')
    ..writeln(
      'Topic,,${dates.map((date) => _csvCell(topics[date]!)).join(',')}',
    );
  for (final roll in rolls) {
    buffer.write(
      '${roll.toString().padLeft(2, '0')},${_csvCell(names[roll]!)}',
    );
    for (final date in dates) {
      buffer.write(',${columns[date]![roll] ?? '-'}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}
