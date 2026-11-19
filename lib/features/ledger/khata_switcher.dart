// Flutter material migration is tracked separately.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import 'data/local_ledger.dart';

/// Choosing a khata is session-only; ledger contents always remain on device.
///
/// [language] localizes the switcher, its rows and the create dialog. Khata
/// names are the user's own text and are always shown verbatim; English stays
/// the default so an unwired call site reads exactly as before.
Future<LocalKhata?> showKhataSwitcher(
  BuildContext context,
  LocalLedger ledger,
  List<LocalKhata> khatas,
  String activeId, {
  AppLanguage language = AppLanguage.en,
  Future<void> Function()? onManage,
}) async {
  final AppStrings strings = AppStrings(language);
  final String? choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          ListTile(title: Text(strings.text(AppString.chooseKhata))),
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
            title: Text(strings.text(AppString.newKhata)),
            onTap: () => Navigator.pop(context, '__new__'),
          ),
          if (onManage != null)
            ListTile(
              key: const Key('manage-khatas'),
              leading: const Icon(Icons.manage_accounts_outlined),
              title: Text(strings.text(AppString.manageKhatas)),
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
    builder: (_) => _CreateKhata(ledger: ledger, language: language),
  );
}

class _CreateKhata extends StatefulWidget {
  const _CreateKhata({required this.ledger, required this.language});

  final LocalLedger ledger;
  final AppLanguage language;

  @override
  State<_CreateKhata> createState() => _CreateKhataState();
}

class _CreateKhataState extends State<_CreateKhata> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController(text: '0');
  bool _saving = false;
  String? _error;

  AppStrings get _strings => AppStrings(widget.language);

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  /// 1-40 characters after trimming, with the message in the active language.
  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty || name.runes.length > 40) {
      return _strings.text(AppString.nameUpTo40);
    }
    return null;
  }

  /// 0 to 999999999.99 with at most two decimals, in the active language.
  String? _validateOpening(String? value) {
    if (_paise(value ?? '') == null) {
      return _strings.text(AppString.openingBalanceRange);
    }
    return null;
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
          _error = _strings.text(AppString.createKhataFailed);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = _strings;
    return AlertDialog(
      title: Text(strings.text(AppString.newKhata)),
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
                decoration: InputDecoration(
                  labelText: strings.text(AppString.khataName),
                ),
                validator: _validateName,
              ),
              TextFormField(
                key: const Key('khata-opening'),
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: strings.text(AppString.openingBalanceInput),
                ),
                validator: _validateOpening,
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
          child: Text(strings.text(AppString.cancel)),
        ),
        FilledButton(
          key: const Key('create-khata'),
          onPressed: _saving ? null : _save,
          child: Text(strings.text(AppString.create)),
        ),
      ],
    );
  }
}
