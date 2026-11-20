import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// Where the chosen UI language is kept. It is a device setting: not part of a
/// ledger backup and never synced.
const String kLanguagePreferenceKey = 'app_language';

/// The saved language, or English when nothing is saved or the store is not
/// available. A missing preference must never block start-up.
Future<AppLanguage> loadLanguagePreference() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppLanguage.fromCode(prefs.getString(kLanguagePreferenceKey));
  } catch (_) {
    return AppLanguage.en;
  }
}

/// Saves [language]; true only once the store confirms the write.
Future<bool> saveLanguagePreference(AppLanguage language) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.setString(kLanguagePreferenceKey, language.name);
}
