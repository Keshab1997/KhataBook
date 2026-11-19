// Flutter material migration is tracked separately.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'data/local_ledger.dart';

/// Choosing a khata is session-only; ledger contents always remain on device.
Future<LocalKhata?> showKhataSwitcher(
  BuildContext context,
  LocalLedger ledger,
  List<LocalKhata> khatas,
  String activeId, {
  Future<void> Function()? onManage,
}) async {
  final String? choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(title: Text('Choose Khata')),
          for (final khata in khatas)
            ListTile(
              key: Key('khata-${khata.id}'),
              title: Text(khata.name),
              trailing: khata.id == activeId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, khata.id),
            ),
          ListTile(
            key: const Key('new-khata'),
            leading: const Icon(Icons.add),
            title: const Text('New Khata'),
            onTap: () => Navigator.pop(context, '__new__'),
          ),
          if (onManage != null)
            ListTile(
              key: const Key('manage-khatas'),
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Manage Khatas'),
              onTap: () => Navigator.pop(context, '__manage__'),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == '__manage__') {
    await onManage?.call();
    return null;
  }
  if (choice != '__new__') return khatas.firstWhere((k) => k.id == choice);
  return showDialog<LocalKhata>(
    context: context,
    builder: (_) => _CreateKhata(ledger: ledger),
  );
}

class _CreateKhata extends StatefulWidget {
  const _CreateKhata({required this.ledger});
  final LocalLedger ledger;
  @override
  State<_CreateKhata> createState() => _CreateKhataState();
}

class _CreateKhataState extends State<_CreateKhata> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController(text: '0');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  int? _paise(String input) {
    final match = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(input);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final khata = await widget.ledger.createKhata(
        name: _name.text,
        openingBalancePaise: _paise(_opening.text)!,
      );
      if (mounted) Navigator.pop(context, khata);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not create khata. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New Khata'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('khata-name'),
              controller: _name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Khata name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty || v.trim().runes.length > 40)
                  ? 'Enter a name of up to 40 characters'
                  : null,
            ),
            TextFormField(
              key: const Key('khata-opening'),
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Opening balance (₹)',
              ),
              validator: (v) =>
                  _paise(v ?? '') == null ? 'Enter 0 to 999999999.99' : null,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('create-khata'),
        onPressed: _saving ? null : _save,
        child: const Text('Create'),
      ),
    ],
  );
}
