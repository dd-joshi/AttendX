import 'models/class_entry.dart';

/// Returns the next scheduled start at hour precision.
///
/// Keep a class current throughout its starting hour. Per-day start minutes
/// still determine ordering within that hour.
DateTime? nextClassOccurrence(ClassEntry classEntry, DateTime now) {
  final weekdays = classEntry.weekdays.where((day) => day >= 0 && day <= 6);
  if (weekdays.isEmpty) return null;

  final reference = DateTime(now.year, now.month, now.day, now.hour);
  final currentWeekday = reference.weekday - 1;
  DateTime? next;

  for (final weekday in weekdays.toSet()) {
    var daysAhead = (weekday - currentWeekday + 7) % 7;
    var candidate = DateTime(
      reference.year,
      reference.month,
      reference.day + daysAhead,
      classEntry.hourForWeekday(weekday),
      classEntry.minuteForWeekday(weekday),
    );

    if (candidate.isBefore(reference)) {
      daysAhead += 7;
      candidate = DateTime(
        reference.year,
        reference.month,
        reference.day + daysAhead,
        classEntry.hourForWeekday(weekday),
        classEntry.minuteForWeekday(weekday),
      );
    }

    if (next == null || candidate.isBefore(next)) next = candidate;
  }

  return next;
}

/// Orders classes by the next time faculty can expect to teach them.
/// Unscheduled/invalid legacy classes stay visible at the end.
List<ClassEntry> sortClassesByNextOccurrence(
  Iterable<ClassEntry> classes,
  DateTime now,
) {
  final ordered = classes.toList();
  final occurrences = {
    for (final entry in ordered) entry: nextClassOccurrence(entry, now),
  };
  ordered.sort((a, b) {
    final aNext = occurrences[a];
    final bNext = occurrences[b];

    if (aNext == null && bNext == null) {
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }
    if (aNext == null) return 1;
    if (bNext == null) return -1;

    final byTime = aNext.compareTo(bNext);
    if (byTime != 0) return byTime;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return ordered;
}
