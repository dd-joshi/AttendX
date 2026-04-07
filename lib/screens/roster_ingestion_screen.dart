import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/roster_ingestion_notifier.dart';

class RosterIngestionScreen extends ConsumerStatefulWidget {
  const RosterIngestionScreen({super.key});

  @override
  ConsumerState<RosterIngestionScreen> createState() =>
      _RosterIngestionScreenState();
}

class _RosterIngestionScreenState extends ConsumerState<RosterIngestionScreen> {
  final _pasteCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  int _startHour = 9;
  final List<int> _weekdays = [];

  Future<bool> _onWillPop() async {
    final state = ref.read(rosterIngestionNotifier);
    final shouldWarn = state.parsedNames.isNotEmpty && !state.isConfirmed;
    if (!shouldWarn) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard New Class?'),
        content: const Text('Student roster has been parsed but not saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startHour, minute: 0),
    );
    if (t != null) {
      setState(() => _startHour = t.hour);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rosterIngestionNotifier);
    final parsed = state.parsedNames;
    final showPreview = parsed.isNotEmpty || state.errorMessage != null;
    final hour = _startHour % 12 == 0 ? 12 : _startHour % 12;
    final period = _startHour < 12 ? 'AM' : 'PM';

    final canConfirm = parsed.isNotEmpty && _titleCtrl.text.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _onWillPop();
        if (!context.mounted || !shouldDiscard) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New class')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _pasteCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste student names from Excel here...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                ref
                    .read(rosterIngestionNotifier.notifier)
                    .parsePaste(_pasteCtrl.text);
                final n = ref.read(rosterIngestionNotifier).parsedNames.length;
                setState(() => _totalCtrl.text = '$n');
              },
              child: const Text('Parse'),
            ),
            if (showPreview) ...[
              const SizedBox(height: 24),
              if (state.errorMessage != null && parsed.isEmpty)
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (parsed.isNotEmpty) ...[
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: parsed.length,
                    itemBuilder: (context, i) {
                      final roll = (i + 1).toString().padLeft(2, '0');
                      return Text('[$roll] ${parsed[i]}');
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Class title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Text(
                  'Weekdays',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ToggleButtons(
                  isSelected: List<bool>.generate(
                    7,
                    (i) => _weekdays.contains(i),
                  ),
                  onPressed: (index) {
                    setState(() {
                      if (_weekdays.contains(index)) {
                        _weekdays.remove(index);
                      } else {
                        _weekdays.add(index);
                      }
                      _weekdays.sort();
                    });
                  },
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('M')),
                    Padding(padding: EdgeInsets.all(8), child: Text('T')),
                    Padding(padding: EdgeInsets.all(8), child: Text('W')),
                    Padding(padding: EdgeInsets.all(8), child: Text('T')),
                    Padding(padding: EdgeInsets.all(8), child: Text('F')),
                    Padding(padding: EdgeInsets.all(8), child: Text('S')),
                    Padding(padding: EdgeInsets.all(8), child: Text('S')),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start time (hour)'),
                  subtitle: Text('$hour:00 $period'),
                  trailing: const Icon(Icons.schedule),
                  onTap: _pickTime,
                ),
                TextFormField(
                  controller: _totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total students',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: canConfirm
                      ? () async {
                          final total = int.tryParse(_totalCtrl.text.trim());
                          if (total == null || total < 1) return;
                          await ref
                              .read(rosterIngestionNotifier.notifier)
                              .confirmAndSave(
                                title: _titleCtrl.text.trim(),
                                weekdays: List<int>.from(_weekdays),
                                startHour: _startHour,
                                totalStudents: total,
                              );
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Confirm Mapping & Lock'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
