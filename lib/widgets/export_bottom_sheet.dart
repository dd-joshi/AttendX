import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';
import '../providers/export_filter_notifier.dart';
import 'app_ui.dart';

class ExportBottomSheet extends ConsumerWidget {
  const ExportBottomSheet({super.key});

  Future<void> _pickFrom(BuildContext context, WidgetRef ref) async {
    final state = ref.read(exportFilterNotifier);
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: state.fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (date == null || !context.mounted) return;
    ref.read(exportFilterNotifier.notifier).setFromDate(date);
  }

  Future<void> _pickTo(BuildContext context, WidgetRef ref) async {
    final state = ref.read(exportFilterNotifier);
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: state.toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (date == null || !context.mounted) return;
    ref.read(exportFilterNotifier.notifier).setToDate(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(exportFilterNotifier);
    final dateFormat = MaterialLocalizations.of(context);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: ValueListenableBuilder<Box<ClassEntry>>(
          valueListenable: Hive.box<ClassEntry>(HiveConstants.classBox)
              .listenable(),
          builder: (context, box, _) {
            final classes = box.values.toList(growable: false);
            final selectedClassId =
                classes.any((entry) => entry.classId == filter.selectedClassId)
                ? filter.selectedClassId
                : null;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Export CSV',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose one class and attendance date range.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (classes.isEmpty)
                  const InlineMessage(
                    child: Text('Create a class before exporting attendance.'),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: classes.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.classId,
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: filter.isExporting
                        ? null
                        : (value) => ref
                              .read(exportFilterNotifier.notifier)
                              .setClass(value),
                  ),
                const SizedBox(height: 12),
                AppSurface(
                  radius: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        minTileHeight: 64,
                        title: const Text('From'),
                        subtitle: Text(
                          dateFormat.formatFullDate(filter.fromDate),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: filter.isExporting
                            ? null
                            : () => _pickFrom(context, ref),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        minTileHeight: 64,
                        title: const Text('To'),
                        subtitle: Text(
                          dateFormat.formatFullDate(filter.toDate),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: filter.isExporting
                            ? null
                            : () => _pickTo(context, ref),
                      ),
                    ],
                  ),
                ),
                if (filter.exportError != null) ...[
                  const SizedBox(height: 12),
                  InlineMessage(
                    isError: true,
                    child: Text(filter.exportError!),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: filter.isExporting || selectedClassId == null
                        ? null
                        : () async {
                            await ref
                                .read(exportFilterNotifier.notifier)
                                .runExport();
                            if (!context.mounted) return;
                            final error = ref
                                .read(exportFilterNotifier)
                                .exportError;
                            if (error == null) Navigator.of(context).pop();
                          },
                    child: filter.isExporting
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Exporting...'),
                            ],
                          )
                        : const Text('Export CSV'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
