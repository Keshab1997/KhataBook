/// Immutable sync state snapshot surfaced to Profile and sync indicators.
///
/// The four states match the B5 brief and S5 Profile spec:
/// * [SyncStateKind.signedOut] — local-only mode, no account linked;
/// * [SyncStateKind.idle] — signed in, carrying [lastSyncedAt] and
///   [pendingCount] (plus [isOffline] or [requiresAccountSwitchConfirmation]
///   when a sync was skipped safely without failing);
/// * [SyncStateKind.syncing] — background push/pull in progress;
/// * [SyncStateKind.error] — last sync attempt failed with [errorReason] and
///   still-waiting [pendingCount].
library;

enum SyncStateKind { signedOut, idle, syncing, error }

final class SyncStatus {
  const SyncStatus._({
    required this.kind,
    this.userEmail,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.errorReason,
    this.isOffline = false,
    this.requiresAccountSwitchConfirmation = false,
    this.previousAccountId,
  });

  /// Device is in local-only mode (no signed-in account).
  const SyncStatus.signedOut({int pendingCount = 0})
    : this._(kind: SyncStateKind.signedOut, pendingCount: pendingCount);

  /// Signed in and not currently syncing or in an error state.
  SyncStatus.idle({
    String? userEmail,
    DateTime? lastSyncedAt,
    int pendingCount = 0,
    bool isOffline = false,
    bool requiresAccountSwitchConfirmation = false,
    String? previousAccountId,
  }) : this._(
         kind: SyncStateKind.idle,
         userEmail: userEmail,
         lastSyncedAt: lastSyncedAt?.toUtc(),
         pendingCount: pendingCount,
         isOffline: isOffline,
         requiresAccountSwitchConfirmation: requiresAccountSwitchConfirmation,
         previousAccountId: previousAccountId,
       );

  /// Background push/pull is currently running.
  SyncStatus.syncing({
    String? userEmail,
    DateTime? lastSyncedAt,
    int pendingCount = 0,
  }) : this._(
         kind: SyncStateKind.syncing,
         userEmail: userEmail,
         lastSyncedAt: lastSyncedAt?.toUtc(),
         pendingCount: pendingCount,
       );

  /// Most recent sync failed; local data is untouched and [pendingCount] rows
  /// remain queued for retry.
  SyncStatus.error({
    required String reason,
    String? userEmail,
    DateTime? lastSyncedAt,
    int pendingCount = 0,
  }) : this._(
         kind: SyncStateKind.error,
         userEmail: userEmail,
         lastSyncedAt: lastSyncedAt?.toUtc(),
         pendingCount: pendingCount,
         errorReason: reason,
       );

  final SyncStateKind kind;
  final String? userEmail;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final String? errorReason;
  final bool isOffline;
  final bool requiresAccountSwitchConfirmation;
  final String? previousAccountId;

  bool get isSignedOut => kind == SyncStateKind.signedOut;
  bool get isIdle => kind == SyncStateKind.idle;
  bool get isSyncing => kind == SyncStateKind.syncing;
  bool get isError => kind == SyncStateKind.error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          other.kind == kind &&
          other.userEmail == userEmail &&
          other.lastSyncedAt == lastSyncedAt &&
          other.pendingCount == pendingCount &&
          other.errorReason == errorReason &&
          other.isOffline == isOffline &&
          other.requiresAccountSwitchConfirmation ==
              requiresAccountSwitchConfirmation &&
          other.previousAccountId == previousAccountId;

  @override
  int get hashCode => Object.hash(
    kind,
    userEmail,
    lastSyncedAt,
    pendingCount,
    errorReason,
    isOffline,
    requiresAccountSwitchConfirmation,
    previousAccountId,
  );

  @override
  String toString() =>
      'SyncStatus(kind: ${kind.name}, pendingCount: $pendingCount, '
      'lastSyncedAt: $lastSyncedAt, errorReason: $errorReason, '
      'isOffline: $isOffline, '
      'requiresAccountSwitchConfirmation: $requiresAccountSwitchConfirmation)';
}
