import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';

final classListProvider = StreamProvider<List<ClassEntry>>((ref) async* {
  final box = Hive.box<ClassEntry>(HiveConstants.classBox);
  yield box.values.toList();
  await for (final _ in box.watch()) {
    yield box.values.toList();
  }
});
