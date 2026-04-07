import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/class_list_provider.dart';
import '../providers/export_filter_notifier.dart';

class ExportBottomSheet extends ConsumerStatefulWidget {
  const ExportBottomSheet({super.key, this.preselectedClassId});

  final String? preselectedClassId;

  @override
  ConsumerState<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends ConsumerState<ExportBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.preselectedClassId != null) {
        ref.read(exportFilterNotifier.notifier).setClass(widget.preselectedClassId);
      }
    });
  }

  Future<void> _pickFrom(BuildContext context) async {
    final s = ref.read(exportFilterNotifier);
    final d = await showDatePicker(
      context: context,
      initialDate: s.fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      ref.read(exportFilterNotifier.notifier).setFromDate(d);
    }
  }

  Future<void> _pickTo(BuildContext context) async {
    final s = ref.read(exportFilterNotifier);
    final d = await showDatePicker(
      context: context,
      initialDate: s.toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      ref.read(exportFilterNotifier.notifier).setToDate(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classListProvider);
    final filter = ref.watch(exportFilterNotifier);
    final fmt = MaterialLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: classesAsync.when(
        data: (classes) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Export CSV',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: classes.any((c) => c.classId == filter.selectedClassId)
                    ? filter.selectedClassId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All classes'),
                  ),
                  ...classes.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.classId,
                      child: Text(c.title),
                    ),
                  ),
                ],
                onChanged: (v) =>
                    ref.read(exportFilterNotifier.notifier).setClass(v),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('From'),
                subtitle: Text(fmt.formatFullDate(filter.fromDate)),
                onTap: () => _pickFrom(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('To'),
                subtitle: Text(fmt.formatFullDate(filter.toDate)),
                onTap: () => _pickTo(context),
              ),
              if (filter.exportError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    filter.exportError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: filter.isExporting
                    ? null
                    : () async {
                        await ref
                            .read(exportFilterNotifier.notifier)
                            .runExport();
                        if (!context.mounted) return;
                        final err = ref.read(exportFilterNotifier).exportError;
                        if (err == null) Navigator.of(context).pop();
                      },
                child: filter.isExporting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Export CSV'),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }
}
