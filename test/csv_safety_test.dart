import 'package:attendx/export/build_csv_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV preserves Unicode, numeric roll ordering and safe text cells', () {
    final csv = buildCsvMatrix([
      {
        'timestamp': DateTime(2026, 10, 1),
        'topic': '=1+1',
        'snapshotData': [
          {'roll': '100', 'name': 'अदिती', 'isAbsent': false},
          {'roll': '02', 'name': '@SUM(1,2)', 'isAbsent': true},
        ],
      },
    ]);
    expect(csv, contains("Topic,,'=1+1"));
    expect(csv, contains('"\'@SUM(1,2)"'));
    expect(csv.indexOf('02,'), lessThan(csv.indexOf('100,')));
    expect(csv, contains('100,अदिती,P'));
  });
}
