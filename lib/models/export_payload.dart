class ExportPayload {
  final List<Map<String, dynamic>> snapshots;
  final String classTitle;

  ExportPayload({
    required this.snapshots,
    required this.classTitle,
  });
}