import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';

class RosterIngestionState {
  const RosterIngestionState({
    this.rawPaste = '',
    this.parsedNames = const <String>[],
    this.isConfirmed = false,
    this.errorMessage,
  });

  final String rawPaste;
  final List<String> parsedNames;
  final bool isConfirmed;
  final String? errorMessage;

  RosterIngestionState copyWith({
    String? rawPaste,
    List<String>? parsedNames,
    bool? isConfirmed,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RosterIngestionState(
      rawPaste: rawPaste ?? this.rawPaste,
      parsedNames: parsedNames ?? this.parsedNames,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RosterIngestionNotifier extends StateNotifier<RosterIngestionState> {
  RosterIngestionNotifier() : super(const RosterIngestionState());

  static const _uuid = Uuid();

  void parsePaste(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\t+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\n]'), '');

    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      state = state.copyWith(
        parsedNames: const <String>[],
        errorMessage: 'No names found. Paste a list with one name per line.',
      );
      return;
    }

    state = state.copyWith(
      rawPaste: raw,
      parsedNames: lines,
      clearError: true,
    );
  }

  Future<void> confirmAndSave({
    required String title,
    required List<int> weekdays,
    required int startHour,
    required int totalStudents,
  }) async {
    final parsedNames = state.parsedNames;
    final students = <String, String>{};
    for (var i = 0; i < parsedNames.length; i++) {
      final roll = (i + 1).toString().padLeft(2, '0');
      students[roll] = parsedNames[i];
    }

    final entry = ClassEntry(
      classId: _uuid.v4(),
      title: title,
      weekdays: List<int>.from(weekdays)..sort(),
      startHour: startHour,
      totalStudents: totalStudents,
      students: students,
    );

    final box = Hive.box<ClassEntry>(HiveConstants.classBox);
    await box.put(entry.classId, entry);
    state = state.copyWith(isConfirmed: true);
  }
}

final rosterIngestionNotifier =
    StateNotifierProvider<RosterIngestionNotifier, RosterIngestionState>(
  (ref) => RosterIngestionNotifier(),
);
