import 'package:flutter/material.dart';

import '../data/class_roster_service.dart';

/// Owns its text controller for the full dialog-route lifetime, including the
/// closing animation.
class StudentNameEditDialog extends StatefulWidget {
  const StudentNameEditDialog({
    super.key,
    required this.rollLabel,
    required this.initialName,
  });

  final String rollLabel;
  final String initialName;

  @override
  State<StudentNameEditDialog> createState() => _StudentNameEditDialogState();
}

class _StudentNameEditDialogState extends State<StudentNameEditDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = normalizeStudentName(_controller.text);
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a student name');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit name · ${widget.rollLabel}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Student name',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
