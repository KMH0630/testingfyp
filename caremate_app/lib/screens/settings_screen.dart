import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';
import '../models/medication.dart';
import '../services/api_service.dart';
import 'contact_edit_screen.dart';
import 'medication_edit_screen.dart';

/// 設定頁：藥物（名稱＋服藥時間）及緊急聯絡人
class SettingsScreen extends StatefulWidget {
  final ApiService? api; // 測試時可以傳入假嘅 ApiService

  const SettingsScreen({super.key, this.api});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const maxContacts = 5;

  late final ApiService _api = widget.api ?? ApiService();

  List<Medication> _meds = [];
  List<EmergencyContact> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.listMedications(),
        _api.listContacts(),
      ]);
      setState(() {
        _meds = results[0] as List<Medication>;
        _contacts = results[1] as List<EmergencyContact>;
      });
    } catch (e) {
      debugPrint('settings load error: $e');
      setState(
        () => _error = 'Could not load settings. Please check the connection.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- 藥物 ----------

  Future<void> _editMedication([Medication? med]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MedicationEditScreen(medication: med, api: _api),
      ),
    );
    if (changed == true) await _load();
  }

  // ---------- 聯絡人 ----------

  Future<void> _editContact([int? index]) async {
    final result = await Navigator.of(context).push<ContactEditResult>(
      MaterialPageRoute(
        builder: (_) =>
            ContactEditScreen(contact: index == null ? null : _contacts[index]),
      ),
    );
    if (result == null) return;

    final updated = [..._contacts];
    if (result.deleted && index != null) {
      updated.removeAt(index);
    } else if (result.contact != null) {
      if (index == null) {
        updated.add(result.contact!);
      } else {
        updated[index] = result.contact!;
      }
    } else {
      return;
    }

    try {
      await _api.saveContacts(updated);
      setState(() => _contacts = updated);
      _showMessage(result.deleted ? 'Contact deleted' : 'Contact saved');
    } catch (e) {
      debugPrint('save contacts error: $e');
      _showMessage('Could not save. Please try again.');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionTitle(icon: Icons.medication, text: 'Medications'),
          if (_meds.isEmpty) const _EmptyHint('No medications yet'),
          for (final med in _meds)
            _ItemCard(
              icon: Icons.medication_outlined,
              title: med.name,
              subtitle: [
                med.times.join('  ·  '),
                if (med.instructions.isNotEmpty) med.instructions,
              ].join('\n'),
              onTap: () => _editMedication(med),
            ),
          const SizedBox(height: 8),
          _BigButton(
            icon: Icons.add,
            label: 'Add Medication',
            onPressed: () => _editMedication(),
          ),
          const SizedBox(height: 32),
          const _SectionTitle(
            icon: Icons.contact_phone,
            text: 'Emergency Contacts',
          ),
          if (_contacts.isEmpty) const _EmptyHint('No contacts yet'),
          for (var i = 0; i < _contacts.length; i++)
            _ItemCard(
              icon: Icons.person_outline,
              title: _contacts[i].name,
              subtitle: [
                if (_contacts[i].relation.isNotEmpty) _contacts[i].relation,
                _contacts[i].phone,
              ].join('  ·  '),
              onTap: () => _editContact(i),
            ),
          const SizedBox(height: 8),
          _BigButton(
            icon: Icons.person_add_alt_1,
            label: _contacts.length >= maxContacts
                ? 'Maximum $maxContacts contacts'
                : 'Add Contact',
            onPressed: _contacts.length >= maxContacts
                ? null
                : () => _editContact(),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: Theme.of(context).hintColor)),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.edit),
        onTap: onTap,
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _BigButton({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(label),
      ),
    );
  }
}
