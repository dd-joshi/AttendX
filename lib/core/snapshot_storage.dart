import 'package:hive_flutter/hive_flutter.dart';

import '../data/models/snapshot_entry.dart';
import 'hive_constants.dart';

Future<Box<SnapshotEntry>>? _openingSnapshotBox;

/// Opens attendance history once, even when multiple screens need it at once.
Future<Box<SnapshotEntry>> openSnapshotBox() {
  final opening = _openingSnapshotBox;
  if (opening != null) return opening;
  if (Hive.isBoxOpen(HiveConstants.snapshotBox)) {
    return Future.value(Hive.box<SnapshotEntry>(HiveConstants.snapshotBox));
  }
  return _openingSnapshotBox =
      Hive.openBox<SnapshotEntry>(HiveConstants.snapshotBox).whenComplete(() {
        _openingSnapshotBox = null;
      });
}
