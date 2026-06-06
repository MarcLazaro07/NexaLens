import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static SharedPreferences? _prefs;

  static const String _keyAutoSaveAR = 'auto_save_ar';
  static const String _keyHaptic = 'haptic_feedback';
  static const String _keyCamQuality = 'cam_quality';
  static const String _keyAppLang = 'app_lang';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Getters ---
  static bool get autoSaveAR => _prefs?.getBool(_keyAutoSaveAR) ?? false;
  static bool get hapticFeedback => _prefs?.getBool(_keyHaptic) ?? true;
  static String get cameraQuality =>
      _prefs?.getString(_keyCamQuality) ?? 'High';
  static String get appLanguage => _prefs?.getString(_keyAppLang) ?? 'Español';

  // --- Setters ---
  static Future<void> setAutoSaveAR(bool value) async {
    await _prefs?.setBool(_keyAutoSaveAR, value);
  }

  static Future<void> setHapticFeedback(bool value) async {
    await _prefs?.setBool(_keyHaptic, value);
  }

  static Future<void> setCameraQuality(String value) async {
    await _prefs?.setString(_keyCamQuality, value);
  }

  static Future<void> setAppLanguage(String value) async {
    await _prefs?.setString(_keyAppLang, value);
  }

  // --- Actions ---
  static Future<void> resetAll() async {
    await _prefs?.clear();
  }
}
