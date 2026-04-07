/// Isolate message for [compute] — no Flutter / Hive types.
class ExportPayload {
  ExportPayload({
    required this.snapshots,
    required this.classTitle,
  });

  final List<Map<String, dynamic>> snapshots;
  final String classTitle;
}
