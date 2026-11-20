import 'dart:typed_data';
import 'dart:ui' as ui;

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'profile_photo_picker.dart';
import 'profile_store.dart';
import 'settings_screen.dart';

String _profileText(AppLanguage language, String en, String bn) =>
    language == AppLanguage.bn ? bn : en;

/// The one soft shadow (blur 14, offset 0/4) every card on this screen uses.
/// `theme.md` allows exactly one low-opacity shadow, never layered ones.
List<BoxShadow> _cardShadow() => <BoxShadow>[
  BoxShadow(
    color: AppColors.darkText.withValues(alpha: 0.05),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

/// S5 - Profile, docs/spec/screens.md#s5--profile.
///
/// The honest, offline-first profile for this build. There is no signed-in
/// user, no avatar upload and no cloud backup yet, so the screen shows none of
/// them: no seeded name, no e-mail address and no "last synced" date. What it
/// does show is the state that is actually true - the khata lives on this
/// device and nothing is uploaded - plus a working route into App Settings.
///
/// Only controls that do something are enabled:
///   * [SettingsScreen], wired through [Navigator] so back works;
///   * the open-source licence page, rendered by Flutter itself;
///   * wallet summary and Android offline backup when the shell provides them.
///
/// Unavailable features, including sign-in, are visibly marked
/// *Not available yet* and is not tappable, rather than pretending to work.
///
/// Visual system: one warm-ivory card at radius 20 with the 1 dp beige border
/// and the single soft shadow from `theme.md`, 40 dp rounded-square icon
/// containers, a 4 dp green rule above every section title, and 24 dp between
/// sections / 10 dp between a title and its card. Every colour is an
/// [AppColors] token.
///
/// Layout is one scrolling list with no fixed heights, so a 320 dp screen at
/// 200% text scale wraps instead of overflowing.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.onWalletSummary,
    this.onBackup,
    this.onCloudBackup,
    this.language = AppLanguage.en,
    this.onLanguageChanged,
    this.profileStore,
    this.onPickAvatar,
  });

  final AppLanguage language;
  final Future<bool> Function(AppLanguage)? onLanguageChanged;
  final ProfileStore? profileStore;
  final Future<Uint8List?> Function()? onPickAvatar;
  final VoidCallback? onWalletSummary;
  final VoidCallback? onBackup;

  /// Opens the cloud backup & sync screen; `null` in the web preview.
  final VoidCallback? onCloudBackup;

  /// Static build label, kept in step with `pubspec.yaml` by hand: this build
  /// ships no package-info dependency, so the number is stated, not read.
  static const String versionLabel = '1.0.0 (build 1)';

  /// Opens App Settings above the shell so its back arrow returns here.
  void _openSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => SettingsScreen(
          language: language,
          onLanguageChanged: onLanguageChanged,
        ),
      ),
    );
  }

  /// Flutter's own licence registry - real content, no network, no new file.
  void _openLicences(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'KhataBook',
      applicationVersion: versionLabel,
      applicationLegalese: _profileText(
        language,
        'Offline-first personal khata. Data stays on this device.',
        'অফলাইন ব্যক্তিগত খাতা। তথ্য এই ডিভাইসেই থাকে।',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_profileText(language, 'Profile', 'প্রোফাইল')),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _IconBadge(
                        icon: Icons.info_outline,
                        size: 56,
                        radius: 18,
                        iconSize: 28,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profileText(
                          language,
                          'Web design preview only. Local ledger storage and backup are not available on the web.',
                          'শুধু ওয়েব ডিজাইন প্রিভিউ। ওয়েবে স্থানীয় খাতা ও ব্যাকআপ নেই।',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.softText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => _openSettings(context),
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(
                          _profileText(
                            language,
                            'App Settings',
                            'অ্যাপ সেটিংস',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        // One line with ellipsis: at 200% text scale a wrapping title would
        // overflow the fixed AppBar height.
        title: Text(
          _profileText(language, 'Profile', 'প্রোফাইল'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          // Fixed 48 dp box keeps this icon-only control a 44 dp+ target at
          // every text scale.
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              key: const Key('profile-app-settings-gear'),
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.onPrimary,
              tooltip: _profileText(language, 'App settings', 'অ্যাপ সেটিংস'),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: <Widget>[
            if (profileStore == null)
              _IdentityCard(language: language)
            else
              _EditableIdentityCard(
                store: profileStore!,
                language: language,
                pickPhoto: onPickAvatar ?? pickProfilePhoto,
              ),
            const SizedBox(height: 14),
            _OfflineNotice(language: language),
            const SizedBox(height: 24),
            _SectionTitle(
              _profileText(
                language,
                'Account & backup',
                'অ্যাকাউন্ট ও ব্যাকআপ',
              ),
            ),
            const SizedBox(height: 10),
            _MenuCard(
              children: <Widget>[
                _MenuRow(
                  key: const Key('profile-app-settings-row'),
                  icon: Icons.settings_outlined,
                  title: _profileText(language, 'App Settings', 'অ্যাপ সেটিংস'),
                  subtitle: _profileText(
                    language,
                    'Currency, theme, language and backup.',
                    'মুদ্রা, থিম, ভাষা ও ব্যাকআপ।',
                  ),
                  onTap: () => _openSettings(context),
                ),
                const _MenuDivider(),
                _MenuRow(
                  key: const Key('profile-wallet-row'),
                  icon: Icons.account_balance_wallet_outlined,
                  title: _profileText(
                    language,
                    'My Wallet Summary',
                    'আমার ওয়ালেটের সারাংশ',
                  ),
                  subtitle: _profileText(
                    language,
                    'Opening balance, income and expense for each khata.',
                    'প্রতিটি খাতার প্রারম্ভিক ব্যালেন্স, আয় ও ব্যয়।',
                  ),
                  status: onWalletSummary == null
                      ? _profileText(
                          language,
                          'Not available yet',
                          'এখনও উপলব্ধ নয়',
                        )
                      : null,
                  onTap: onWalletSummary,
                ),
                const _MenuDivider(),
                _MenuRow(
                  key: const Key('profile-backup-row'),
                  icon: Icons.file_upload_outlined,
                  title: _profileText(
                    language,
                    'Offline backup / restore',
                    'অফলাইন ব্যাকআপ / পুনরুদ্ধার',
                  ),
                  subtitle: _profileText(
                    language,
                    'Save or restore an unencrypted local backup file.',
                    'এনক্রিপ্ট না করা স্থানীয় ব্যাকআপ সংরক্ষণ বা পুনরুদ্ধার করুন।',
                  ),
                  status: onBackup == null
                      ? _profileText(
                          language,
                          'Not available yet',
                          'এখনও উপলব্ধ নয়',
                        )
                      : null,
                  onTap: onBackup,
                ),
                const _MenuDivider(),
                _MenuRow(
                  key: const Key('profile-sign-in-row'),
                  icon: Icons.cloud_outlined,
                  title: _profileText(
                    language,
                    'Cloud backup & sync',
                    'ক্লাউড ব্যাকআপ ও সিঙ্ক',
                  ),
                  subtitle: _profileText(
                    language,
                    'Sign in with Google to back up khatas and sync across phones.',
                    'গুগল দিয়ে সাইন ইন করে খাতা ব্যাকআপ করুন ও অন্য ফোনে সিঙ্ক করুন।',
                  ),
                  status: onCloudBackup == null
                      ? _profileText(
                          language,
                          'Not available yet',
                          'এখনও উপলব্ধ নয়',
                        )
                      : null,
                  onTap: onCloudBackup,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              _profileText(language, 'About KhataBook', 'খাতাবুক সম্পর্কে'),
            ),
            const SizedBox(height: 10),
            _MenuCard(
              children: <Widget>[
                _InfoRow(
                  key: const Key('profile-version'),
                  icon: Icons.info_outline,
                  label: _profileText(language, 'Version', 'সংস্করণ'),
                  value: versionLabel,
                ),
                const _MenuDivider(),
                _InfoRow(
                  icon: Icons.smartphone_outlined,
                  label: _profileText(
                    language,
                    'Where your data lives',
                    'তথ্য কোথায় থাকে',
                  ),
                  value: _profileText(
                    language,
                    'This device only',
                    'শুধু এই ডিভাইসে',
                  ),
                ),
                const _MenuDivider(),
                _InfoRow(
                  icon: Icons.currency_rupee,
                  label: _profileText(language, 'Money', 'মুদ্রা'),
                  value: _profileText(
                    language,
                    'Indian rupees (INR), Indian digit grouping',
                    'ভারতীয় রুপি (INR), ভারতীয় সংখ্যা বিন্যাস',
                  ),
                ),
                const _MenuDivider(),
                _InfoRow(
                  icon: Icons.light_mode_outlined,
                  label: _profileText(language, 'Theme', 'থিম'),
                  value: _profileText(language, 'Light only', 'শুধু হালকা'),
                ),
                const _MenuDivider(),
                _MenuRow(
                  key: const Key('profile-licences-row'),
                  icon: Icons.description_outlined,
                  title: _profileText(
                    language,
                    'Open-source licences',
                    'ওপেন সোর্স লাইসেন্স',
                  ),
                  subtitle: _profileText(
                    language,
                    'Software KhataBook is built with.',
                    'খাতাবুকে ব্যবহৃত সফটওয়্যার।',
                  ),
                  onTap: () => _openLicences(context),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'KhataBook · Plan · Track · Save',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.softText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableIdentityCard extends StatefulWidget {
  const _EditableIdentityCard({
    required this.store,
    required this.language,
    required this.pickPhoto,
  });

  final ProfileStore store;
  final AppLanguage language;
  final Future<Uint8List?> Function() pickPhoto;

  @override
  State<_EditableIdentityCard> createState() => _EditableIdentityCardState();
}

class _EditableIdentityCardState extends State<_EditableIdentityCard> {
  LocalProfile? _profile;
  bool _busy = false;

  String _text(String en, String bn) =>
      widget.language == AppLanguage.bn ? bn : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.store.load();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) {
        setState(() => _profile = LocalProfile());
        _message(_text('Could not load profile.', 'প্রোফাইল লোড করা যায়নি।'));
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(LocalProfile profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.save(profile);
      final saved = await widget.store.load();
      if (mounted) setState(() => _profile = saved);
    } catch (_) {
      if (mounted) {
        _message(
          _text('Could not save profile.', 'প্রোফাইল সংরক্ষণ করা যায়নি।'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _profile!.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_text('Edit name', 'নাম পরিবর্তন')),
        content: TextField(controller: controller, maxLength: 60),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_text('Cancel', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_text('Save', 'সংরক্ষণ')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && mounted) {
      await _save(LocalProfile(name: name, avatarBytes: _profile!.avatarBytes));
    }
  }

  Future<void> _choosePhoto() async {
    try {
      final bytes = await widget.pickPhoto();
      if (!mounted) return;
      if (bytes == null) {
        _message(
          _text(
            'Photo selection cancelled.',
            'ছবি নির্বাচন বাতিল হয়েছে।',
          ),
        );
        return;
      }
      if (!ProfileStore.isSupportedAvatar(bytes)) {
        throw const FormatException('Unsupported image');
      }
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (!mounted) return;
      await _save(LocalProfile(name: _profile!.name, avatarBytes: bytes));
    } catch (_) {
      if (mounted) {
        _message(_text('Could not set the photo.', 'ছবি সেট করা যায়নি।'));
      }
    }
  }

  Widget _avatar(LocalProfile profile) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: <Widget>[
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.18),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: profile.avatarBytes == null
                ? const Icon(
                    Icons.person,
                    size: 46,
                    color: AppColors.primaryGreen,
                  )
                : Image.memory(
                    profile.avatarBytes!,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                          Icons.person,
                          size: 46,
                          color: AppColors.primaryGreen,
                        ),
                  ),
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2),
          ),
          child: const Icon(
            Icons.camera_alt,
            size: 15,
            color: AppColors.onPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final bool hasName = profile.name.isNotEmpty;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
        child: Column(
          children: <Widget>[
            _avatar(profile),
            const SizedBox(height: 12),
            Text(
              hasName
                  ? profile.name
                  : _text('Local profile', 'স্থানীয় প্রোফাইল'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            _StatusChip(label: _text('Not signed in', 'সাইন ইন করা হয়নি')),
            const SizedBox(height: 6),
            Text(
              _text(
                'Saved on this device only. Add a name and a photo if you like - nothing is uploaded.',
                'শুধু এই ডিভাইসে সংরক্ষিত। চাইলে নাম ও ছবি যোগ করুন - কিছু আপলোড হয় না।',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.softText,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: AppColors.outline),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _busy ? null : _editName,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(_text('Edit name', 'নাম পরিবর্তন')),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _choosePhoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(_text('Choose photo', 'ছবি বাছুন')),
                ),
                if (profile.avatarBytes != null)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _save(LocalProfile(name: profile.name)),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.expenseRed,
                    ),
                    label: Text(
                      _text('Remove photo', 'ছবি সরান'),
                      style: const TextStyle(color: AppColors.darkText),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Golden avatar circle with no personal data: a placeholder, not a fake user.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Image.asset(
                    'assets/illustrations/home_wallet.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                          color: AppColors.lightGreen,
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 34,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 2),
                  Text(
                    _profileText(
                      language,
                      'Local profile',
                      'স্থানীয় প্রোফাইল',
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusChip(
                    label: _profileText(
                      language,
                      'Not signed in',
                      'সাইন ইন করা হয়নি',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profileText(
                      language,
                      'No account is linked to KhataBook. Everything you enter stays in the local database on this device.',
                      'খাতাবুকে কোনো অ্যাকাউন্ট যুক্ত নেই। আপনার সব তথ্য এই ডিভাইসের ডেটাবেসে থাকে।',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.softText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The truthful sync state, given its own card so it cannot be missed.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: _profileText(
        language,
        'Offline and local-only. KhataBook works without internet. Entries are saved on this device only, and nothing is uploaded.',
        'অফলাইন এবং স্থানীয়। খাতাবুক ইন্টারনেট ছাড়াই চলে। এন্ট্রি শুধু এই ডিভাইসে থাকে; কিছু আপলোড হয় না।',
      ),
      // Semantics has no const constructor; everything below it is const.
      child: ExcludeSemantics(
        child: _Card(
          key: const Key('profile-offline-status'),
          background: AppColors.lightGreen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    size: 21,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _profileText(
                          language,
                          'Offline & local-only',
                          'অফলাইন ও শুধু স্থানীয়',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profileText(
                          language,
                          'KhataBook works without internet. Entries are written to this device only - nothing is uploaded, and there is no cloud copy to restore.',
                          'খাতাবুক ইন্টারনেট ছাড়া চলে। এন্ট্রি শুধু এই ডিভাইসে থাকে; কিছু আপলোড হয় না এবং পুনরুদ্ধারের জন্য ক্লাউড কপি নেই।',
                        ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
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
      ),
    );
  }
}

/// Section heading above a card: a 4 dp green rule, then the title.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded warm-ivory surface with the 1 dp beige border from theme.md.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.child, this.background});

  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: _cardShadow(),
      ),
      child: child,
    );
  }
}

/// A card holding menu rows; a Material so enabled rows can ripple.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow(),
      ),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 66,
      endIndent: 14,
      color: AppColors.outline,
    );
  }
}

/// The 40 dp rounded-square icon container every row and notice shares.
class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    this.enabled = true,
    this.size = 40,
    this.radius = 12,
    this.iconSize = 20,
  });

  final IconData icon;
  final bool enabled;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.lightGreen
            : AppColors.beige.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: enabled ? AppColors.primaryGreen : AppColors.softText,
      ),
    );
  }
}

/// One menu row.
///
/// With an [onTap] the row is a real 56 dp+ target with a chevron. Without
/// one the row is read-only: no ink, no tap handler, and a [status] chip that
/// says why it cannot be used.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final bool available = onTap != null;
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _IconBadge(icon: icon, enabled: available),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 1),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.softText,
                    ),
                  ),
                  if (status != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _StatusChip(label: status!),
                  ],
                ],
              ),
            ),
            if (available) ...<Widget>[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!available) {
      return content;
    }
    return InkWell(onTap: onTap, child: content);
  }
}

/// Static label/value line used by the About card. Stacked, so long values and
/// 200% text scale wrap rather than collide.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _IconBadge(icon: icon, size: 36, radius: 10, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.softText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill used for "Not signed in" and "Not available yet".
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.creamBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.softText,
        ),
      ),
    );
  }
}
