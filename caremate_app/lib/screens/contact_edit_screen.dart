import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';

/// 編輯聯絡人嘅結果：contact = 新資料；deleted = 刪除
class ContactEditResult {
  final EmergencyContact? contact;
  final bool deleted;
  const ContactEditResult.saved(EmergencyContact this.contact)
    : deleted = false;
  const ContactEditResult.deleted() : contact = null, deleted = true;
}

/// 新增／修改緊急聯絡人（實際儲存由 SettingsScreen 負責）
class ContactEditScreen extends StatefulWidget {
  final EmergencyContact? contact; // null = 新增

  const ContactEditScreen({super.key, this.contact});

  @override
  State<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends State<ContactEditScreen> {
  // 同後端一致：可選 +，8–16 位數字或空格，例如 +852 9123 4567
  static final _phonePattern = RegExp(r'^\+?[0-9 ]{8,16}$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _relation;

  bool get _isNew => widget.contact == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.contact?.name ?? '');
    _phone = TextEditingController(text: widget.contact?.phone ?? '');
    _relation = TextEditingController(text: widget.contact?.relation ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ContactEditResult.saved(
        EmergencyContact(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          relation: _relation.text.trim(),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('"${widget.contact!.name}" will be removed.'),
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
    if (ok == true && mounted) {
      Navigator.of(context).pop(const ContactEditResult.deleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Contact' : 'Edit Contact'),
        actions: [
          if (!_isNew)
            IconButton(
              iconSize: 32,
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
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
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. +852 9123 4567',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _phonePattern.hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Please enter a valid phone number',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _relation,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                  hintText: 'e.g. Son, Daughter, Social worker',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
