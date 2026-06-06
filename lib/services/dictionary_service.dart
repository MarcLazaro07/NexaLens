import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_word.dart';

class DictionaryService {
  static const _key = 'nexalens_dictionary';
  static List<SavedWord> _cache = [];
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null && data.isNotEmpty) {
      _cache = SavedWord.decode(data);
    }
    _loaded = true;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, SavedWord.encode(_cache));
  }

  static Future<List<SavedWord>> getWords({
    String? category,
    String? search,
  }) async {
    await _ensureLoaded();
    var result = List<SavedWord>.from(_cache);

    if (category != null && category != 'Todos') {
      result = result.where((w) => w.category == category).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where(
            (w) =>
                w.original.toLowerCase().contains(q) ||
                w.translated.toLowerCase().contains(q),
          )
          .toList();
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  static Future<void> saveWord({
    required String original,
    required String translated,
    required String srcLang,
    required String tgtLang,
    required String category,
  }) async {
    await _ensureLoaded();

    // Avoid duplicates
    final exists = _cache.any(
      (w) =>
          w.original.toLowerCase() == original.toLowerCase() &&
          w.srcLang == srcLang &&
          w.tgtLang == tgtLang,
    );
    if (exists) return;

    _cache.add(
      SavedWord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        original: original,
        translated: translated,
        srcLang: srcLang,
        tgtLang: tgtLang,
        category: category,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
  }

  static Future<void> deleteWord(String id) async {
    await _ensureLoaded();
    _cache.removeWhere((w) => w.id == id);
    await _save();
  }

  static Future<void> clearAll() async {
    _cache.clear();
    _loaded = true;
    await _save();
  }

  static Future<int> count() async {
    await _ensureLoaded();
    return _cache.length;
  }
}
