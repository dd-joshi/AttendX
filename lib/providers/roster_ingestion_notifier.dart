import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/class_roster_service.dart';
import '../data/models/class_entry.dart';

class RosterIngestionState {
  const RosterIngestionState({
    this.parsedNames = const <String>[],
    this.newNames = const <String>[],
    this.hasParsed = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final List<String> parsedNames;
  final List<String> newNames;
  final bool hasParsed;
  final bool isSaving;
  final String? errorMessage;

  bool get canSave =>
      hasParsed && !isSaving && errorMessage == null && newNames.isNotEmpty;

  RosterIngestionState copyWith({
    List<String>? parsedNames,
    List<String>? newNames,
    bool? hasParsed,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RosterIngestionState(
      parsedNames: parsedNames ?? this.parsedNames,
      newNames: newNames ?? this.newNames,
      hasParsed: hasParsed ?? this.hasParsed,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RosterIngestionNotifier extends StateNotifier<RosterIngestionState> {
  RosterIngestionNotifier(this.classEntry)
    : existingNames = rosterNamesInOrder(classEntry),
      super(const RosterIngestionState());

  final ClassEntry classEntry;
  final List<String> existingNames;

  bool get isInitialRoster => existingNames.isEmpty;

  void invalidatePreview() {
    if (!state.hasParsed || state.isSaving) return;
    state = const RosterIngestionState();
  }

  void parsePaste(String raw) {
    final names = parseRosterNames(raw);
    final error = validateAppendOnlyRoster(
      existingNames: existingNames,
      proposedNames: names,
    );
    final additions = names.length > existingNames.length
        ? names.sublist(existingNames.length)
        : const <String>[];

    state = RosterIngestionState(
      parsedNames: names,
      newNames: additions,
      hasParsed: true,
      errorMessage: error,
    );
  }

  Future<ClassEntry> confirmAndSave({DateTime? now}) async {
    if (!state.canSave) {
      throw RosterValidationException(
        state.errorMessage ?? 'Preview the roster before saving.',
      );
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      return await appendRoster(
        classId: classEntry.classId,
        proposedNames: state.parsedNames,
        now: now,
      );
    } on RosterValidationException catch (error) {
      if (mounted) state = state.copyWith(errorMessage: error.message);
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }
}

final rosterIngestionNotifier = StateNotifierProvider.autoDispose
    .family<RosterIngestionNotifier, RosterIngestionState, ClassEntry>(
      (ref, classEntry) => RosterIngestionNotifier(classEntry),
    );
