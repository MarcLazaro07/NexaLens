import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Service that handles translation via Google ML Kit (On-Device).
/// No API keys, no rate limits, works offline.
class TranslationService {
  static final _modelManager = OnDeviceTranslatorModelManager();

  // Cache of translators
  static final Map<String, OnDeviceTranslator> _translators = {};

  /// Language code mapping
  static const langMapping = {
    'ES': TranslateLanguage.spanish,
    'EN': TranslateLanguage.english,
    'FR': TranslateLanguage.french,
    'DE': TranslateLanguage.german,
    'PT': TranslateLanguage.portuguese,
    'IT': TranslateLanguage.italian,
    'JA': TranslateLanguage.japanese,
    'KO': TranslateLanguage.korean,
    'ZH': TranslateLanguage.chinese,
    'RU': TranslateLanguage.russian,
    'AR': TranslateLanguage.arabic,
    'HI': TranslateLanguage.hindi,
  };

  /// BCP-47 Tag mapping for model management
  static const bcpMapping = {
    TranslateLanguage.spanish: 'es',
    TranslateLanguage.english: 'en',
    TranslateLanguage.french: 'fr',
    TranslateLanguage.german: 'de',
    TranslateLanguage.portuguese: 'pt',
    TranslateLanguage.italian: 'it',
    TranslateLanguage.japanese: 'ja',
    TranslateLanguage.korean: 'ko',
    TranslateLanguage.chinese: 'zh', // ML Kit Chinese often just 'zh'
    TranslateLanguage.russian: 'ru',
    TranslateLanguage.arabic: 'ar',
    TranslateLanguage.hindi: 'hi',
  };

  /// Translates [text] from [srcLang] to [tgtLang] using on-device ML Kit.
  static Future<String> translate({
    required String text,
    required String srcLang,
    required String tgtLang,
  }) async {
    if (text.trim().isEmpty) return '';

    final source = langMapping[srcLang] ?? TranslateLanguage.spanish;
    final target = langMapping[tgtLang] ?? TranslateLanguage.english;

    final srcBcp = bcpMapping[source] ?? 'es';
    final tgtBcp = bcpMapping[target] ?? 'en';

    final key = '$srcBcp|$tgtBcp';

    try {
      // 1. Ensure models are downloaded (only if not already)
      if (!await _modelManager.isModelDownloaded(srcBcp)) {
        await _modelManager.downloadModel(srcBcp);
      }
      if (!await _modelManager.isModelDownloaded(tgtBcp)) {
        await _modelManager.downloadModel(tgtBcp);
      }

      // 2. Get or create translator
      final translator = _translators[key] ??= OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );

      return await translator.translateText(text);
    } catch (e) {
      return text; // Fallback to original
    }
  }

  static void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}
