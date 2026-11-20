/// Build-time configuration for KhataBook cloud backup & sync (B5).
///
/// Reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from `--dart-define`
/// compile-time environment variables. Contains no real URLs or keys in source
/// code: when either define is absent or blank, [isConfigured] is `false` and
/// the app stays cleanly in local-only mode.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

final class CloudConfig {
  const CloudConfig({
    required this.url,
    required this.publishableKey,
    this.redirectTo = defaultRedirectTo,
  });

  /// Reads `--dart-define=SUPABASE_URL=...` and
  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`, defaulting both to `''` when
  /// omitted.
  const CloudConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      redirectTo = defaultRedirectTo;

  /// Native OAuth callback registered in Supabase (`null` on web so the
  /// browser redirects back to the current page).
  static const String? defaultRedirectTo = kIsWeb
      ? null
      : 'in.keshab.khatabook://login-callback';

  final String url;
  final String publishableKey;
  final String? redirectTo;

  /// `true` only when both [url] and [publishableKey] are non-blank and [url]
  /// parses as an `http` or `https` URI with a host.
  bool get isConfigured {
    final String trimmedUrl = url.trim();
    final String trimmedKey = publishableKey.trim();
    if (trimmedUrl.isEmpty || trimmedKey.isEmpty) return false;
    final Uri? parsed = Uri.tryParse(trimmedUrl);
    if (parsed == null || !parsed.hasAuthority || parsed.host.isEmpty) {
      return false;
    }
    return parsed.scheme == 'https' || parsed.scheme == 'http';
  }
}
