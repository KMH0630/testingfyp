import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/api_service.dart';

/// 新增／修改藥物。儲存或刪除成功時 pop(true)。
class MedicationEditScreen extends StatefulWidget {
  final Medication? medication; // null = 新增
  final ApiService? api;

  const MedicationEditScreen({super.key, this.medication, this.api});

  @override
  State<MedicationEditScreen> createState() => _MedicationEditScreenState();
}

class _MedicationEditScreenState extends State<MedicationEditScreen> {
  static const maxTimes = 6;

  late final ApiService _api = widget.api ?? ApiService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _instructions;
  late List<String> _times;
  bool _saving = false;

  bool get _isNew => widget.medication == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.medication?.name ?? '');
    _instructions = TextEditingController(
      text: widget.medication?.instructions ?? '',
    );
    _times = [...?widget.medication?.times];
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parse(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// index = null 代表新增時間
  Future<void> _pickTime([int? index]) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: index == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : _parse(_times[index]),
      helpText: 'Select time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final value = _format(picked);
    setState(() {
      if (index == null) {
        if (!_times.contains(value)) _times.add(value);
      } else {
        _times[index] = value;
      }
      _times = _times.toSet().toList()..sort();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      _showMessage('Please add at least one time');
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.saveMedication(
        Medication(
          id: widget.medication?.id,
          name: _name.text.trim(),
          times: _times,
          instructions: _instructions.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('save medication error: $e');
      _showMessage('Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete medication?'),
        content: Text('"${widget.medication!.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await _api.deleteMedication(widget.medication!.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('delete medication error: $e');
      _showMessage('Could not delete. Please try again.');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Medication' : 'Edit Medication'),
        actions: [
          if (!_isNew)
            IconButton(
              iconSize: 32,
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Medicine name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter the medicine name'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _instructions,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Instructions (optional)',
                  hintText: 'e.g. After meals',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Times', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_times.isEmpty)
                Text(
                  'No time yet',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < _times.length; i++)
                    InputChip(
                      avatar: const Icon(Icons.alarm),
                      label: Text(
                        _times[i],
                        style: const TextStyle(fontSize: 22),
                      ),
                      padding: const EdgeInsets.all(8),
                      onPressed: () => _pickTime(i),
                      onDeleted: () => setState(() => _times.removeAt(i)),
                      deleteButtonTooltipMessage: 'Remove',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _times.length >= maxTimes ? null : () => _pickTime(),
                icon: const Icon(Icons.add_alarm, size: 28),
                label: const Text('Add Time'),
              ),
              const SizedBox(height: 32),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
