import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/class_entry.dart';
import '../providers/roster_ingestion_notifier.dart';
import '../widgets/app_ui.dart';

class RosterIngestionScreen extends ConsumerStatefulWidget {
  const RosterIngestionScreen({super.key, required this.classEntry});

  final ClassEntry classEntry;

  @override
  ConsumerState<RosterIngestionScreen> createState() =>
      _RosterIngestionScreenState();
}

class _RosterIngestionScreenState extends ConsumerState<RosterIngestionScreen> {
  late final TextEditingController _pasteController;
  late final String _initialText;
  bool _saved = false;

  bool get _isInitialRoster => !widget.classEntry.hasRoster;
  bool get _isDirty => _pasteController.text != _initialText && !_saved;

  @override
  void initState() {
    super.initState();
    _initialText = widget.classEntry.orderedRolls
        .map((roll) => widget.classEntry.students[roll] ?? '')
        .join('\n');
    _pasteController = TextEditingController(text: _initialText);
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    final isSaving = ref
        .read(rosterIngestionNotifier(widget.classEntry))
        .isSaving;
    if (isSaving) return false;
    if (!_isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard roster changes?'),
            content: const Text('The pasted roster has not been saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _previewRoster() {
    // Dismiss the keyboard so the preview list is fully visible.
    FocusScope.of(context).unfocus();
    ref
        .read(rosterIngestionNotifier(widget.classEntry).notifier)
        .parsePaste(_pasteController.text);
  }

  Future<void> _saveRoster() async {
    try {
      FocusScope.of(context).unfocus();
      final updated = await ref
          .read(rosterIngestionNotifier(widget.classEntry).notifier)
          .confirmAndSave();
      if (!mounted) return;
      _saved = true;
      unawaited(HapticFeedback.mediumImpact());
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      final error = ref
          .read(rosterIngestionNotifier(widget.classEntry))
          .errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Could not save roster')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rosterIngestionNotifier(widget.classEntry));
    final previewNames = _isInitialRoster ? state.parsedNames : state.newNames;
    final startingRoll = _isInitialRoster
        ? 1
        : widget.classEntry.rosterSize + 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!await _confirmDiscard() || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isInitialRoster ? 'Add roster' : 'Update roster'),
              Text(
                widget.classEntry.title,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              _isInitialRoster
                  ? 'Paste one student name per line. Roll numbers are assigned automatically.'
                  : 'Existing students stay locked in sequence. Append new names at the bottom.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pasteController,
              enabled: !state.isSaving,
              minLines: 8,
              maxLines: 14,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                ref
                    .read(rosterIngestionNotifier(widget.classEntry).notifier)
                    .invalidatePreview();
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: _isInitialRoster ? 'Student names' : 'Full roster',
                hintText: 'Aarav Patel\nDiya Shah\nKabir Singh',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (state.hasParsed) ...[
              const SizedBox(height: 20),
              if (state.errorMessage != null)
                InlineMessage(isError: true, child: Text(state.errorMessage!))
              else ...[
                Text(
                  _isInitialRoster
                      ? 'Roster preview \u00B7 ${previewNames.length} students'
                      : 'New students \u00B7 ${previewNames.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _RosterPreview(names: previewNames, startingRoll: startingRoll),
                if (!state.canSave && !state.isSaving) ...[
                  const SizedBox(height: 12),
                  InlineMessage(
                    child: Text(
                      _isInitialRoster
                          ? 'Add at least one student name to continue.'
                          : 'Append at least one new student name to continue.',
                    ),
                  ),
                ],
                if (!_isInitialRoster) ...[
                  const SizedBox(height: 12),
                  const InlineMessage(
                    child: Text(
                      'These students will appear in attendance from today onward. Saved attendance stays unchanged.',
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          onPressed: state.isSaving
              ? null
              : state.hasParsed
              ? (state.canSave ? _saveRoster : null)
              : _previewRoster,
          child: state.isSaving
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('Saving...'),
                  ],
                )
              : state.hasParsed
              ? Text(
                  '${_isInitialRoster ? 'Add roster' : 'Update roster'}'
                  '${state.canSave ? ' (${previewNames.length})' : ''}',
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.preview_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Preview changes'),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RosterPreview extends StatelessWidget {
  const _RosterPreview({required this.names, required this.startingRoll});

  final List<String> names;
  final int startingRoll;

  @override
  Widget build(BuildContext context) {
    final height = math.min(280.0, math.max(56.0, names.length * 56.0));
    return AppSurface(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: names.length,
          separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final roll = (startingRoll + index).toString().padLeft(2, '0');
            return ListTile(
              minTileHeight: 55,
              leading: SizedBox(width: 36, child: Text(roll)),
              title: Text(
                names[index],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    );
  }
}
