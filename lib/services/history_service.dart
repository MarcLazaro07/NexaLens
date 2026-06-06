import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';

class HistoryService {
  static const _key = 'nexalens_history';
  static List<HistoryEntry> _cache = [];
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null && data.isNotEmpty) {
      _cache = HistoryEntry.decode(data);
    }
    _loaded = true;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, HistoryEntry.encode(_cache));
  }

  static Future<List<HistoryEntry>> getEntries({String? filter}) async {
    await _ensureLoaded();
    var result = List<HistoryEntry>.from(_cache);

    if (filter != null && filter != 'Todos') {
      result = result.where((e) => e.type == filter).toList();
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  static Future<void> addEntry({
    required String type,
    required String originalText,
    required String translatedText,
    required String srcLang,
    required String tgtLang,
  }) async {
    await _ensureLoaded();
    _cache.add(
      HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        originalText: originalText,
        translatedText: translatedText,
        srcLang: srcLang,
        tgtLang: tgtLang,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
  }

  static Future<void> deleteEntry(String id) async {
    await _ensureLoaded();
    _cache.removeWhere((e) => e.id == id);
    await _save();
  }

  static Future<void> clearAll() async {
    _cache.clear();
    _loaded = true;
    await _save();
  }
}
