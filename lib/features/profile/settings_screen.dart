// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// The caller owns the committed language. Return true only once the change
/// succeeds, false on cancellation, or throw on failure. Update [SettingsScreen.language]
/// from the caller after success; this screen does not write to storage.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.language = AppLanguage.en,
    this.onLanguageChanged,
  });

  final AppLanguage language;
  final Future<bool> Function(AppLanguage)? onLanguageChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _picking = false;
  bool _busy = false;
  bool _failed = false;

  Future<void> _chooseLanguage(AppStrings strings) async {
    if (_picking || _busy || kIsWeb || widget.onLanguageChanged == null) return;
    _picking = true;
    final AppLanguage? choice = await showDialog<AppLanguage>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(strings.text(AppString.changeLanguage)),
        children: [
          for (final AppLanguage language in AppLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, language),
              child: Semantics(
                selected: widget.language == language,
                child: Text(language.endonym),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.text(AppString.cancel)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _picking = false;
    final callback = widget.onLanguageChanged;
    if (choice == null || choice == widget.language || callback == null) {
      return;
    }

    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      // A false result is cancellation. The committed value belongs to the
      // caller, so neither cancellation nor success is optimistic here.
      await callback(choice);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);
    final text = strings.text;
    final bool canChoose = widget.onLanguageChanged != null;
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            text(AppString.appSettings),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(text(AppString.webSettings)),
          ),
        ),
      );
    }
    return Scaffold(
      key: const Key('settings-screen'),
      appBar: AppBar(
        // One line with ellipsis: at 200% text scale a wrapping title would
        // overflow the fixed AppBar height.
        title: Text(
          text(AppString.appSettings),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            if (!canChoose) _ReadOnlyNotice(strings),
            const SizedBox(height: 20),
            _SectionTitle(text(AppString.preferences)),
            const SizedBox(height: 8),
            _SettingsCard(
              children: <Widget>[
                _SettingRow(
                  key: const Key('settings-currency-row'),
                  icon: Icons.currency_rupee,
                  title: text(AppString.currency),
                  detail: text(AppString.currencyDetail),
                  value: text(AppString.currencyInr),
                  status: text(AppString.fixed),
                ),
                const _CardDivider(),
                _SettingRow(
                  key: const Key('settings-theme-row'),
                  icon: Icons.light_mode_outlined,
                  title: text(AppString.theme),
                  detail: text(AppString.themeDetail),
                  value: text(AppString.light),
                  status: text(AppString.fixed),
                ),
                const _CardDivider(),
                _SettingRow(
                  key: const Key('settings-language-row'),
                  icon: Icons.translate_outlined,
                  title: text(AppString.language),
                  detail: text(
                    canChoose
                        ? AppString.languageDetail
                        : AppString.languageUnavailable,
                  ),
                  value: widget.language.endonym,
                  status: canChoose ? null : text(AppString.notAvailable),
                ),
                if (canChoose)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton(
                          key: const Key('settings-change-language'),
                          onPressed: _busy
                              ? null
                              : () => _chooseLanguage(strings),
                          child: Text(text(AppString.changeLanguage)),
                        ),
                        if (_busy || _failed)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              text(
                                _busy
                                    ? AppString.languagePending
                                    : AppString.languageFailed,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const _CardDivider(),
                _SettingRow(
                  key: const Key('settings-backup-row'),
                  icon: Icons.cloud_off_outlined,
                  title: text(AppString.cloudBackup),
                  detail: text(AppString.cloudDetail),
                  value: text(AppString.off),
                  status: text(AppString.notAvailable),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(text(AppString.storage)),
            const SizedBox(height: 8),
            _SettingsCard(
              children: <Widget>[
                _SettingRow(
                  key: const Key('settings-storage-row'),
                  icon: Icons.smartphone_outlined,
                  title: text(AppString.storageTitle),
                  detail: text(AppString.storageDetail),
                  value: text(AppString.thisDevice),
                  status: text(AppString.localOnly),
                ),
                const _CardDivider(),
                _SettingRow(
                  icon: Icons.wifi_off_outlined,
                  title: text(AppString.internetRequired),
                  detail: text(AppString.internetDetail),
                  value: text(AppString.no),
                  status: text(AppString.offlineFirst),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsCard(
              children: [
                _SettingRow(
                  key: const Key('settings-offline-backup-row'),
                  icon: Icons.save_alt,
                  title: text(AppString.offlineBackupRestore),
                  detail: text(AppString.androidBackupDetail),
                  value: text(AppString.androidBackup),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.buildLabel('1.0.0', 1),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.softText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green-tinted banner naming the state of the screen up front.
class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice(this.strings);

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '${strings.text(AppString.readOnly)}. '
          '${strings.text(AppString.readOnlyDetail)}',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('settings-readonly-notice'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                size: 26,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.text(AppString.readOnly),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.text(AppString.readOnlyDetail),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.softText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.darkText,
      ),
    );
  }
}

/// Warm-ivory rounded card for preference and storage information.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.outline);
  }
}

/// A fixed value: title, plain-language explanation, and the value plus its
/// status chip. Never tappable, and announced as one readable unit.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    this.status,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String value;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: [title, value, ?status, detail].join('. '),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.softText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _ValueChip(label: value, highlighted: true),
                          if (status != null) _ValueChip(label: status!),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Value or status pill. Its text wraps, so a long label never overflows.
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.lightGreen : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: highlighted ? AppColors.primaryGreen : AppColors.softText,
        ),
      ),
    );
  }
}
