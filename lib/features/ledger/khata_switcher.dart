// Flutter material migration is tracked separately.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'data/local_ledger.dart';

/// One radius for the sheet and for every row inside it.
const double _sheetRadius = 24;
const double _rowRadius = 14;

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
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  strings.text(AppString.chooseKhata),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
          for (final khata in khatas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                key: Key('khata-${khata.id}'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rowRadius),
                ),
                tileColor: khata.id == activeId
                    ? AppColors.lightGreen
                    : AppColors.creamBackground.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: khata.id == activeId
                        ? AppColors.primaryGreen
                        : AppColors.warmIvory,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: khata.id == activeId
                          ? AppColors.primaryGreen
                          : AppColors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    khata.id == activeId
                        ? Icons.check_rounded
                        : Icons.book_rounded,
                    size: 16,
                    color: khata.id == activeId
                        ? AppColors.onPrimary
                        : AppColors.softText,
                  ),
                ),
                title: Text(
                  khata.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    letterSpacing: -0.1,
                    fontWeight: khata.id == activeId
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: khata.id == activeId
                        ? AppColors.primaryGreen
                        : AppColors.darkText,
                  ),
                ),
                trailing: khata.id == activeId
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      )
                    : null,
                onTap: () => Navigator.pop(context, khata.id),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 4),
          ListTile(
            key: const Key('new-khata'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rowRadius),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.onPrimary,
                size: 18,
              ),
            ),
            title: Text(
              strings.text(AppString.newKhata),
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            onTap: () => Navigator.pop(context, '__new__'),
          ),
          if (onManage != null)
            ListTile(
              key: const Key('manage-khatas'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_rowRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.creamBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.softText,
                  size: 16,
                ),
              ),
              title: Text(
                strings.text(AppString.manageKhatas),
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.softText,
                size: 20,
              ),
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

  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty || name.runes.length > 40) {
      return _strings.text(AppString.nameUpTo40);
    }
    return null;
  }

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_sheetRadius - 4),
      ),
      title: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 16,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.text(AppString.newKhata),
              style: const TextStyle(
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                key: const Key('khata-name'),
                controller: _name,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: strings.text(AppString.khataName),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(
                    Icons.book_outlined,
                    size: 18,
                    color: AppColors.softText,
                  ),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const Key('khata-opening'),
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: strings.text(AppString.openingBalanceInput),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: AppColors.softText,
                  ),
                  prefixText: '₹ ',
                ),
                validator: _validateOpening,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.expenseRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.expenseRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppColors.expenseRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.expenseRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
