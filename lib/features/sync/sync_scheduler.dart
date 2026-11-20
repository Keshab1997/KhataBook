/// Debounced, `Timer`-based scheduler with capped exponential backoff for
/// offline-first cloud sync (B5).
///
/// * [kick] coalesces rapid local writes behind [debounce] (default 800 ms) and
///   resets any retry backoff so a fresh user action tries promptly.
/// * When [runSync] reports failure (`false`) or throws, [SyncScheduler]
///   schedules a retry at `baseBackoff * 2^(attempt - 1)`, capped at
///   [maxBackoff].
/// * Zero external dependencies — built purely on `dart:async` [Timer].
library;

import 'dart:async';

typedef SyncRunner = Future<bool> Function();
typedef TimerFactory = Timer Function(Duration delay, void Function() callback);

class SyncScheduler {
  SyncScheduler({
    required SyncRunner runSync,
    this.debounce = const Duration(milliseconds: 800),
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 5),
    TimerFactory? timerFactory,
  }) : _runSync = runSync,
       _timerFactory = timerFactory ?? Timer.new {
    if (debounce.isNegative) {
      throw ArgumentError.value(debounce, 'debounce', 'must not be negative');
    }
    if (baseBackoff <= Duration.zero) {
      throw ArgumentError.value(baseBackoff, 'baseBackoff', 'must be positive');
    }
    if (maxBackoff < baseBackoff) {
      throw ArgumentError.value(
        maxBackoff,
        'maxBackoff',
        'must be >= baseBackoff',
      );
    }
  }

  final SyncRunner _runSync;
  final Duration debounce;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final TimerFactory _timerFactory;

  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _failureCount = 0;
  Duration? _scheduledRetryDelay;
  bool _running = false;
  bool _pendingKickWhileRunning = false;
  bool _disposed = false;

  /// Number of consecutive failed sync attempts currently tracked for backoff.
  int get failureCount => _failureCount;

  /// Delay chosen for the currently armed retry timer, or `null` when no retry
  /// is scheduled.
  Duration? get scheduledRetryDelay => _scheduledRetryDelay;

  /// Whether a retry timer is currently armed.
  bool get hasScheduledRetry => _retryTimer?.isActive ?? false;

  /// Whether a debounce timer is currently armed.
  bool get hasPendingDebounce => _debounceTimer?.isActive ?? false;

  /// Computes the exponential backoff delay for 1-based failure [attempt]:
  /// `baseBackoff * 2^(attempt - 1)`, capped at [maxBackoff].
  Duration backoffForAttempt(int attempt) {
    if (attempt <= 1) return baseBackoff;
    int multiplier = 1;
    final int maxShift = attempt - 1;
    for (int i = 0; i < maxShift; i++) {
      final int candidateMicroseconds = baseBackoff.inMicroseconds * multiplier;
      if (candidateMicroseconds >= maxBackoff.inMicroseconds) {
        return maxBackoff;
      }
      multiplier *= 2;
    }
    final int totalMicroseconds = baseBackoff.inMicroseconds * multiplier;
    if (totalMicroseconds >= maxBackoff.inMicroseconds) {
      return maxBackoff;
    }
    return Duration(microseconds: totalMicroseconds);
  }

  /// Debounces a sync request after a local write or connectivity change.
  ///
  /// Cancels any existing debounce or retry timer and starts a fresh [debounce]
  /// countdown. If a sync is already in flight when the timer fires (or when
  /// [kick] is called), one follow-up sync is queued as soon as it finishes.
  void kick() {
    if (_disposed) return;
    _cancelTimers();
    if (_running) {
      _pendingKickWhileRunning = true;
      return;
    }
    _debounceTimer = _timerFactory(debounce, () {
      _debounceTimer = null;
      unawaited(_execute());
    });
  }

  /// Runs one sync pass immediately (bypassing debounce), updating the retry
  /// schedule based on its outcome.
  Future<bool> triggerNow() async {
    if (_disposed) return false;
    _cancelTimers();
    return _execute();
  }

  /// Records one external sync failure and arms the next capped exponential
  /// retry timer without immediately re-executing [runSync].
  Duration scheduleFailureRetry() {
    if (_disposed) return baseBackoff;
    _cancelTimers();
    _failureCount++;
    final Duration delay = backoffForAttempt(_failureCount);
    _scheduledRetryDelay = delay;
    _retryTimer = _timerFactory(delay, () {
      _retryTimer = null;
      _scheduledRetryDelay = null;
      unawaited(_execute());
    });
    return delay;
  }

  /// Cancels any armed debounce or retry timer without clearing [failureCount].
  void cancelPendingTimers() {
    _cancelTimers();
  }

  /// Clears consecutive failure tracking and cancels any pending timers (for
  /// example after signing out).
  void reset() {
    _cancelTimers();
    _failureCount = 0;
    _pendingKickWhileRunning = false;
  }

  /// Permanently stops all timers. Safe to call multiple times.
  void dispose() {
    _disposed = true;
    reset();
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _scheduledRetryDelay = null;
  }

  Future<bool> _execute() async {
    if (_disposed) return false;
    if (_running) {
      _pendingKickWhileRunning = true;
      return false;
    }
    _running = true;
    bool succeeded = false;
    try {
      succeeded = await _runSync();
    } catch (_) {
      succeeded = false;
    } finally {
      _running = false;
    }

    if (_disposed) return succeeded;

    if (succeeded) {
      _failureCount = 0;
      _scheduledRetryDelay = null;
      if (_pendingKickWhileRunning) {
        _pendingKickWhileRunning = false;
        kick();
      }
      return true;
    }

    _pendingKickWhileRunning = false;
    _failureCount++;
    final Duration delay = backoffForAttempt(_failureCount);
    _scheduledRetryDelay = delay;
    _retryTimer = _timerFactory(delay, () {
      _retryTimer = null;
      _scheduledRetryDelay = null;
      unawaited(_execute());
    });
    return false;
  }
}
