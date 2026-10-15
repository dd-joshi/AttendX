import 'package:flutter_test/flutter_test.dart';

import 'package:attendx/export/export_file_name.dart';

void main() {
  group('buildExportFileName', () {
    final from = DateTime(2026, 7, 10);
    final to = DateTime(2026, 8, 9);

    test('carries class, date range, and percentage', () {
      expect(
        buildExportFileName(
          classTitle: 'Class A',
          from: from,
          to: to,
          percent: 85,
        ),
        'AttendX_Class A_2026-07-10_to_2026-08-09_85pct.csv',
      );
    });

    test('omits the percentage when there are no marks', () {
      expect(
        buildExportFileName(classTitle: 'Class A', from: from, to: to),
        'AttendX_Class A_2026-07-10_to_2026-08-09.csv',
      );
    });

    test('sanitizes path-illegal characters and empty titles', () {
      expect(
        buildExportFileName(
          classTitle: 'Physics/10: "A"',
          from: from,
          to: to,
          percent: 0,
        ),
        'AttendX_Physics_10_ _A__2026-07-10_to_2026-08-09_0pct.csv',
      );
      expect(
        buildExportFileName(classTitle: '  ', from: from, to: to),
        'AttendX_Class_2026-07-10_to_2026-08-09.csv',
      );
    });
  });

  group('attendancePercentOf', () {
    test('averages present marks across sessions and rounds', () {
      final percent = attendancePercentOf([
        [
          {'roll': '01', 'name': 'A', 'isAbsent': false},
          {'roll': '02', 'name': 'B', 'isAbsent': true},
        ],
        [
          {'roll': '01', 'name': 'A', 'isAbsent': false},
          {'roll': '02', 'name': 'B', 'isAbsent': false},
        ],
      ]);
      expect(percent, 75);
    });

    test('returns null without marks and 0 when everyone is absent', () {
      expect(attendancePercentOf([]), isNull);
      expect(
        attendancePercentOf([
          [
            {'roll': '01', 'name': 'A', 'isAbsent': true},
          ],
        ]),
        0,
      );
    });

    test('marks without the isAbsent flag count as present', () {
      expect(
        attendancePercentOf([
          [
            {'roll': '01', 'name': 'A'},
          ],
        ]),
        100,
      );
    });
  });
}
