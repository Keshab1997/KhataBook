import 'dart:typed_data';
import 'dart:ui' as ui;

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'profile_photo_picker.dart';
import 'profile_store.dart';
import 'settings_screen.dart';

String _profileText(AppLanguage language, String en, String bn) =>
    language == AppLanguage.bn ? bn : en;

/// S5 - Profile, docs/spec/screens.md#s5--profile.
///
/// The honest, offline-first profile for this build, aligned with the S5
/// reference layout (`docs/design/ui-preview.png`): branded account header,
/// identity card (avatar with existing artwork, display name and a neutral
/// local-profile line), offline-first notice, and the reference action order:
///   1. My Wallet Summary (`profile-wallet-row`)
///   2. Offline backup / restore (`profile-backup-row`) + Cloud backup & sync
///      (`profile-sign-in-row`)
///   3. App Settings (`profile-app-settings-row`)
///   4. About App (`profile-about-row`)
///   5. Logout (`profile-logout-row`)
/// followed by the static `About KhataBook` facts and open-source licences
/// (`profile-licences-row`).
///
/// Every row reuses [AccountRow] from `settings_screen.dart` so leading tiles
/// and trailing chevrons stay aligned to the first line while titles and
/// subtitles wrap across the full remaining width at 320 dp / 200% text scale.
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

  /// Opens the cloud backup & sync screen, where the live sign-in and sync
  /// status lives; `null` leaves the row honestly unavailable. This screen
  /// receives no account state, so it never asserts one itself.
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
    final AppStrings strings = AppStrings(language);
    final String notAvailable = strings.text(AppString.notAvailable);
    final String headerSubtitle = _profileText(
      language,
      'Profile on this device',
      'এই ডিভাইসের প্রোফাইল',
    );

    // One screen on every platform, web included: the host opens the real
    // browser ledger and supplies the same callbacks, so each row simply
    // enables what it was given and labels the rest unavailable. Browser
    // storage is never described as a durable cloud backup.
    return Scaffold(
      body: Column(
        children: <Widget>[
          AccountPageHeader(
            key: const Key('profile-header'),
            title: strings.text(AppString.profile),
            subtitle: headerSubtitle,
            icon: Icons.person_outline,
            action: _SettingsGear(
              language: language,
              onPressed: () => _openSettings(context),
            ),
          ),
          Expanded(
            child: SafeArea(
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
                  const SizedBox(height: 20),
                  AccountSectionPanel(
                    heading: strings.text(AppString.accountAndBackup),
                    children: <Widget>[
                      AccountRow(
                        key: const Key('profile-wallet-row'),
                        icon: Icons.account_balance_wallet_outlined,
                        title: strings.text(AppString.myWalletSummary),
                        subtitle: _profileText(
                          language,
                          'Opening balance, income and expense for each khata.',
                          'প্রতিটি খাতার প্রারম্ভিক ব্যালেন্স, আয় ও ব্যয়।',
                        ),
                        status: onWalletSummary == null ? notAvailable : null,
                        onTap: onWalletSummary,
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        key: const Key('profile-backup-row'),
                        icon: Icons.file_upload_outlined,
                        title: strings.text(AppString.offlineBackupRestore),
                        subtitle: _profileText(
                          language,
                          'Save or restore an unencrypted local backup file.',
                          'এনক্রিপ্ট না করা স্থানীয় ব্যাকআপ সংরক্ষণ বা পুনরুদ্ধার করুন।',
                        ),
                        status: onBackup == null ? notAvailable : null,
                        onTap: onBackup,
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        key: const Key('profile-sign-in-row'),
                        icon: Icons.cloud_outlined,
                        title: _profileText(
                          language,
                          'Cloud backup & sync',
                          'ক্লাউড ব্যাকআপ ও সিঙ্ক',
                        ),
                        subtitle: _profileText(
                          language,
                          'Open the Cloud Backup screen for sign-in, backup and sync status.',
                          'সাইন-ইন, ব্যাকআপ ও সিঙ্কের অবস্থা দেখতে ক্লাউড ব্যাকআপ পর্দা খুলুন।',
                        ),
                        status: onCloudBackup == null ? notAvailable : null,
                        onTap: onCloudBackup,
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        key: const Key('profile-app-settings-row'),
                        icon: Icons.settings_outlined,
                        title: strings.text(AppString.appSettings),
                        subtitle: strings.text(AppString.settingsDescription),
                        onTap: () => _openSettings(context),
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        key: const Key('profile-about-row'),
                        icon: Icons.info_outline,
                        title: _profileText(
                          language,
                          'About App',
                          'অ্যাপ সম্পর্কে',
                        ),
                        subtitle: _profileText(
                          language,
                          'Dedicated about screen; version and licences are listed below.',
                          'আলাদা পরিচিতি পাতা; নিচে সংস্করণ ও লাইসেন্স দেওয়া আছে।',
                        ),
                        status: notAvailable,
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        key: const Key('profile-logout-row'),
                        icon: Icons.logout,
                        title: _profileText(language, 'Logout', 'লগ আউট'),
                        subtitle: _profileText(
                          language,
                          'Sign-in and sign-out are managed on the Cloud Backup screen.',
                          'সাইন-ইন ও সাইন-আউট ক্লাউড ব্যাকআপ পর্দা থেকে পরিচালিত হয়।',
                        ),
                        status: notAvailable,
                        destructive: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AccountSectionPanel(
                    heading: strings.text(AppString.about),
                    children: <Widget>[
                      Padding(
                        key: const Key('profile-footer-tagline'),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Text(
                          _profileText(
                            language,
                            'KhataBook · Plan · Track · Save',
                            'খাতাবুক · পরিকল্পনা · হিসাব · সঞ্চয়',
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: AppColors.softText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 14,
                        endIndent: 14,
                        color: AppColors.outline,
                      ),
                      AccountRow(
                        key: const Key('profile-version'),
                        icon: Icons.info_outline,
                        eyebrow: strings.text(AppString.version),
                        title: versionLabel,
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        icon: Icons.smartphone_outlined,
                        eyebrow: _profileText(
                          language,
                          'Where your data lives',
                          'তথ্য কোথায় থাকে',
                        ),
                        title: _profileText(
                          language,
                          'Saved on this device first',
                          'আগে এই ডিভাইসে সংরক্ষিত',
                        ),
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        icon: Icons.currency_rupee,
                        eyebrow: strings.text(AppString.money),
                        title: _profileText(
                          language,
                          'Indian rupees (INR), Indian digit grouping',
                          'ভারতীয় রুপি (INR), ভারতীয় সংখ্যা বিন্যাস',
                        ),
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        icon: Icons.light_mode_outlined,
                        eyebrow: strings.text(AppString.theme),
                        title: _profileText(
                          language,
                          'Light only',
                          'শুধু হালকা',
                        ),
                      ),
                      const AccountRowDivider(),
                      AccountRow(
                        key: const Key('profile-licences-row'),
                        icon: Icons.description_outlined,
                        title: strings.text(AppString.licences),
                        subtitle: _profileText(
                          language,
                          'Software KhataBook is built with.',
                          'খাতাবুকে ব্যবহৃত সফটওয়্যার।',
                        ),
                        onTap: () => _openLicences(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
      final LocalProfile profile = await widget.store.load();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) {
        setState(() => _profile = LocalProfile());
        _message(_text('Could not load profile.', 'প্রোফাইল লোড করা যায়নি।'));
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(LocalProfile profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.save(profile);
      final LocalProfile saved = await widget.store.load();
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
    final TextEditingController controller = TextEditingController(
      text: _profile!.name,
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_text('Edit name', 'নাম পরিবর্তন')),
        content: TextField(controller: controller, maxLength: 60),
        actions: <Widget>[
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
      final Uint8List? bytes = await widget.pickPhoto();
      if (!mounted) return;
      if (bytes == null) {
        _message(
          _text('Photo selection cancelled.', 'ছবি নির্বাচন বাতিল হয়েছে।'),
        );
        return;
      }
      if (!ProfileStore.isSupportedAvatar(bytes)) {
        throw const FormatException('Unsupported image');
      }
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
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
      key: const Key('profile-avatar'),
      alignment: Alignment.bottomRight,
      children: <Widget>[
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.golden, width: 2.5),
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
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => const Icon(
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
            color: AppColors.golden,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2),
          ),
          child: const Icon(
            Icons.camera_alt,
            size: 15,
            color: AppColors.headerGreen,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final LocalProfile? profile = _profile;
    if (profile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final bool hasName = profile.name.isNotEmpty;
    return AccountSurfaceCard(
      key: const Key('profile-identity-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IdentityBanner(caption: _text('KHATABOOK', 'খাতাবুক')),
          // Keep the brand caption and the avatar in separate vertical space.
          // A negative overlap hides the caption behind an opaque profile photo.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: _avatar(profile)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Column(
              children: <Widget>[
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
                AccountStatusChip(
                  label: _text('On this device', 'এই ডিভাইসে'),
                ),
                const SizedBox(height: 6),
                Text(
                  _text(
                    'Saved on this device. Add a name and a photo if you like. For cloud copy status, open Cloud Backup below.',
                    'এই ডিভাইসে সংরক্ষিত। চাইলে নাম ও ছবি যোগ করুন। ক্লাউড কপির অবস্থা জানতে নিচে ক্লাউড ব্যাকআপ খুলুন।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.softText,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.outline,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 0,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: _busy ? null : _editName,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(_text('Edit name', 'নাম পরিবর্তন')),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _choosePhoto,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                        ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Local identity header card with the existing wallet artwork, display
/// name, and neutral on-device line stacked vertically so 320 dp / 200% text
/// gets the full card width instead of wrapping beside a fixed image.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return AccountSurfaceCard(
      key: const Key('profile-identity-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IdentityBanner(
            caption: _profileText(language, 'KHATABOOK', 'খাতাবুক'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.golden, width: 2.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/illustrations/home_wallet.png',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) => const ColoredBox(
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              children: <Widget>[
                Text(
                  _profileText(language, 'Local profile', 'স্থানীয় প্রোফাইল'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                AccountStatusChip(
                  label: _profileText(language, 'On this device', 'এই ডিভাইসে'),
                ),
                const SizedBox(height: 8),
                Text(
                  _profileText(
                    language,
                    'This is a local profile stored on this device. KhataBook works offline first; for sign-in and cloud copy status, open Cloud Backup below.',
                    'এটি এই ডিভাইসে সংরক্ষিত একটি স্থানীয় প্রোফাইল। খাতাবুক আগে অফলাইনে কাজ করে; সাইন-ইন ও ক্লাউড কপির বর্তমান অবস্থা জানতে নিচে ক্লাউড ব্যাকআপ খুলুন।',
                  ),
                  textAlign: TextAlign.center,
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
    );
  }
}

/// The offline-first behaviour, given its own card so it cannot be missed.
/// It describes what this screen knows - entries land on this device first -
/// and points at Cloud Backup for the live cloud state it cannot know.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: _profileText(
        language,
        'Works without internet. KhataBook works offline first, and entries are saved on this device first. Cloud Backup shows whether a cloud copy is set up and up to date.',
        'ইন্টারনেট ছাড়াই চলে। খাতাবুক আগে অফলাইনে কাজ করে, আর লেনদেন আগে এই ডিভাইসে সংরক্ষিত হয়। ক্লাউড কপি সেট আপ করা আছে কি না ও তা হালনাগাদ কি না, ক্লাউড ব্যাকআপে দেখা যায়।',
      ),
      child: ExcludeSemantics(
        child: AccountSurfaceCard(
          key: const Key('profile-offline-status'),
          background: AppColors.lightGreen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AccountIconBadge(
                  icon: Icons.cloud_sync_outlined,
                  size: 40,
                  radius: 12,
                  iconSize: 21,
                  background: AppColors.surface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _profileText(
                          language,
                          'Works without internet',
                          'ইন্টারনেট ছাড়াই চলে',
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
                          'KhataBook works offline first, and entries are saved on this device first. Cloud Backup shows whether a cloud copy is set up and up to date - open it below for the current status.',
                          'খাতাবুক আগে অফলাইনে কাজ করে, আর লেনদেন আগে এই ডিভাইসে সংরক্ষিত হয়। ক্লাউড কপি সেট আপ করা আছে কি না ও তা হালনাগাদ কি না জানতে নিচে ক্লাউড ব্যাকআপ খুলুন।',
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

/// The settings gear used by both profile branches: a fixed 48 dp target with
/// its test key, ripple and tooltip intact.
class _SettingsGear extends StatelessWidget {
  const _SettingsGear({required this.language, required this.onPressed});

  final AppLanguage language;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: IconButton(
          key: const Key('profile-app-settings-gear'),
          onPressed: onPressed,
          icon: const Icon(Icons.settings_outlined),
          color: AppColors.onPrimary,
          tooltip: _profileText(language, 'App settings', 'অ্যাপ সেটিংস'),
        ),
      ),
    );
  }
}

/// The light-green caption band on top of the identity card: the same brand
/// caption idiom the rest of the app uses, scaled to a card.
class _IdentityBanner extends StatelessWidget {
  const _IdentityBanner({required this.caption});

  final String caption;

  /// Fixed height so the avatar space below it is deterministic.
  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.menu_book_outlined,
            size: 15,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
