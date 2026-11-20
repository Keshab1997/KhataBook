// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'note_counter_store.dart';

/// Local en/bn pairs for the sheet. `app_strings.dart` belongs to the shared
/// core and is not edited here.
class _Copy {
  const _Copy(this.language);

  final AppLanguage language;

  bool get _bn => language == AppLanguage.bn;

  String get title => _bn ? 'সংরক্ষিত গণনা' : 'Saved sessions';

  String get empty =>
      _bn ? 'এখনো কোনো সংরক্ষিত গণনা নেই' : 'No saved counts yet';

  String get emptyHelp => _bn
      ? 'শূন্য নয় এমন গণনা "সংরক্ষণ করুন" দিয়ে রাখলে এখানে দেখা যাবে'
      : 'Save a non-zero count and it will show up here';

  String get loadFailed =>
      _bn ? 'সংরক্ষিত গণনা লোড করা যায়নি' : 'Could not load the saved counts';

  String get restore => _bn ? 'ফিরিয়ে আনুন' : 'Restore';

  String get restoreConfirmTitle =>
      _bn ? 'এই সংরক্ষিত গণনা ফিরিয়ে আনবেন?' : 'Restore this saved count?';

  String get restoreConfirmBody => _bn
      ? 'স্ক্রিনের বর্তমান গণনা বদলে যাবে। সংরক্ষিত গণনাটি তালিকায় থেকে যাবে।'
      : 'The count on this screen will be replaced. The saved session stays in the list.';

  String get deleteConfirmTitle =>
      _bn ? 'এই সংরক্ষিত গণনাটি মুছে ফেলবেন?' : 'Delete this saved count?';

  String get deleteConfirmBody => _bn
      ? 'এটি এই ডিভাইসের এই খাতা থেকে সরানো হবে। বর্তমান গণনা অক্ষত থাকবে।'
      : 'It will be removed from this khata on this device. The current count is not touched.';

  String get deleteFailed => _bn
      ? 'সংরক্ষিত গণনা মুছা যায়নি। আবার চেষ্টা করুন।'
      : 'Could not delete the saved count. Try again.';

  String get backupNote => _bn
      ? 'সংরক্ষিত গণনা ব্যাকআপ ফাইলের সাথে যায়'
      : 'Saved counts travel in the backup file';
}

/// The saved sessions of one khata, newest first.
///
/// Tapping a session restores it; when the count on screen is not empty the
/// user confirms first, because restoring replaces what they see. A session
/// can be deleted from the row itself. Restoring never writes a transaction -
/// it hands the chosen snapshot back to the caller via [onRestore], which
/// applies it to the current session.
///
/// The sheet is modal. Every visible string follows [language]; money and
/// digits go through [AppStrings].
class SavedSessionsSheet extends StatefulWidget {
  const SavedSessionsSheet({
    super.key,
    required this.store,
    required this.khataId,
    required this.currentTotalPaise,
    required this.onRestore,
    this.language = AppLanguage.en,
  });

  final NoteCounterStore store;
  final String khataId;

  /// Grand Total of the count on screen when the sheet opened. Decides
  /// whether a restore needs a confirmation.
  final int currentTotalPaise;

  /// Called after the user confirms a restore (or taps one straight away
  /// when the current count is empty). The caller applies the snapshot.
  final Future<void> Function(SavedNoteCount session) onRestore;

  final AppLanguage language;

  @override
  State<SavedSessionsSheet> createState() => _SavedSessionsSheetState();
}

enum _SheetPhase { loading, ready, failed }

class _SavedSessionsSheetState extends State<SavedSessionsSheet> {
  _SheetPhase _phase = _SheetPhase.loading;
  List<SavedNoteCount> _sessions = const <SavedNoteCount>[];
  final Set<String> _deleting = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _phase = _SheetPhase.loading);
    try {
      final List<SavedNoteCount> sessions = await widget.store.listSessions(
        widget.khataId,
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _phase = _SheetPhase.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _SheetPhase.failed);
    }
  }

  Future<void> _restore(SavedNoteCount session) async {
    final AppStrings strings = AppStrings(widget.language);
    final _Copy copy = _Copy(widget.language);
    if (widget.currentTotalPaise > 0) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(copy.restoreConfirmTitle),
          content: Text(copy.restoreConfirmBody),
          actions: <Widget>[
            TextButton(
              key: const Key('saved-sessions-restore-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.text(AppString.cancel)),
            ),
            FilledButton(
              key: const Key('saved-sessions-restore-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(copy.restore),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await widget.onRestore(session);
  }

  Future<void> _delete(SavedNoteCount session) async {
    final AppStrings strings = AppStrings(widget.language);
    final _Copy copy = _Copy(widget.language);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(copy.deleteConfirmTitle),
        content: Text(copy.deleteConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('saved-sessions-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.text(AppString.cancel)),
          ),
          FilledButton(
            key: const Key('saved-sessions-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expenseRed,
            ),
            child: Text(strings.text(AppString.delete)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting.add(session.id));
    try {
      await widget.store.deleteSession(widget.khataId, session.id);
      if (!mounted) return;
      setState(() {
        _sessions = _sessions
            .where((SavedNoteCount s) => s.id != session.id)
            .toList(growable: false);
        _deleting.remove(session.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting.remove(session.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(copy.deleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings(widget.language);
    final _Copy copy = _Copy(widget.language);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          // Keep clear of the keyboard/home indicator without hiding the list.
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.beige,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_outline,
                    size: 19,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                // Expanded so a long or scaled-up title wraps instead of
                // overflowing a narrow phone.
                Expanded(
                  child: Text(
                    copy.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.beige),
            const SizedBox(height: 8),
            Flexible(child: _buildBody(strings, copy)),
            const SizedBox(height: 10),
            Text(
              copy.backupNote,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.softText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppStrings strings, _Copy copy) {
    switch (_phase) {
      case _SheetPhase.loading:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      case _SheetPhase.failed:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                copy.loadFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.darkText),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('saved-sessions-retry'),
                onPressed: _reload,
                child: Text(strings.text(AppString.retry)),
              ),
            ],
          ),
        );
      case _SheetPhase.ready:
        if (_sessions.isEmpty) {
          return Padding(
            key: const Key('saved-sessions-empty'),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_border,
                    size: 30,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  copy.empty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy.emptyHelp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.softText,
                  ),
                ),
              ],
            ),
          );
        }
        // Each session is its own rounded card rather than a row separated
        // by rule lines: the list is short, and cards read faster.
        return ListView.separated(
          key: const Key('saved-sessions-list'),
          shrinkWrap: true,
          itemCount: _sessions.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            final SavedNoteCount session = _sessions[index];
            final DateTime local = session.savedAt.toLocal();
            return Material(
              color: AppColors.warmIvory,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                side: const BorderSide(color: AppColors.beige),
              ),
              child: ListTile(
                key: Key('saved-session-${session.id}'),
                onTap: () => _restore(session),
                contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_toggle_off,
                    size: 19,
                    color: AppColors.primaryGreen,
                  ),
                ),
                title: Text(
                  strings.dateTime(local),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                subtitle: Text(
                  '${strings.text(AppString.grandTotal)}: '
                  '${strings.money(session.totalPaise)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.softText,
                  ),
                ),
                trailing: IconButton(
                  key: Key('saved-session-delete-${session.id}'),
                  tooltip: strings.text(AppString.delete),
                  onPressed: _deleting.contains(session.id)
                      ? null
                      : () => _delete(session),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.expenseRed,
                  ),
                ),
              ),
            );
          },
        );
    }
  }
}
