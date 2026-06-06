import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_colors.dart';
import '../services/dictionary_service.dart';
import '../models/saved_word.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _searchCtrl = TextEditingController();

  List<SavedWord> _words = [];
  String _selectedCat = 'Todos';
  bool _isLoading = true;

  static const _categories = ['Todos', 'AR', 'Conversación', 'Foto', 'Manual'];

  static const _ttsLangs = {
    'ES': 'es-ES',
    'EN': 'en-US',
    'FR': 'fr-FR',
    'DE': 'de-DE',
    'PT': 'pt-BR',
    'IT': 'it-IT',
    'JA': 'ja-JP',
    'KO': 'ko-KR',
    'ZH': 'zh-CN',
    'RU': 'ru-RU',
  };

  static const _langNames = {
    'ES': 'Español',
    'EN': 'English',
    'FR': 'Français',
    'DE': 'Deutsch',
    'PT': 'Português',
    'IT': 'Italiano',
    'JA': '日本語',
    'KO': '한국어',
    'ZH': '中文',
    'RU': 'Русский',
  };

  static const _catColors = {
    'Todos': AppColors.primaryCyan,
    'AR': AppColors.moduleTranslate,
    'Conversación': AppColors.moduleOCR,
    'Foto': AppColors.moduleDocument,
    'Manual': AppColors.accentPurple,
  };

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(0.4);
    _loadWords();
    _searchCtrl.addListener(_loadWords);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final words = await DictionaryService.getWords(
      category: _selectedCat,
      search: _searchCtrl.text,
    );
    if (mounted)
      setState(() {
        _words = words;
        _isLoading = false;
      });
  }

  Future<void> _deleteWord(SavedWord word) async {
    await DictionaryService.deleteWord(word.id);
    _loadWords();
  }

  Future<void> _speakWord(String text, String lang) async {
    await _tts.setLanguage(_ttsLangs[lang] ?? 'en-US');
    await _tts.speak(text);
  }

  Future<void> _addManualWord() async {
    final origCtrl = TextEditingController();
    final transCtrl = TextEditingController();
    String srcLang = 'EN';
    String tgtLang = 'ES';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Agregar Palabra',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: origCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Palabra original',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: transCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Traducción',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dlgLangDropdown(
                      srcLang,
                      (v) => setDlgState(() => srcLang = v),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: _dlgLangDropdown(
                      tgtLang,
                      (v) => setDlgState(() => tgtLang = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: AppColors.primaryCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        origCtrl.text.isNotEmpty &&
        transCtrl.text.isNotEmpty) {
      await DictionaryService.saveWord(
        original: origCtrl.text.trim(),
        translated: transCtrl.text.trim(),
        srcLang: srcLang,
        tgtLang: tgtLang,
        category: 'Manual',
      );
      _loadWords();
    }
  }

  Widget _dlgLangDropdown(String val, ValueChanged<String> onChanged) {
    return DropdownButton<String>(
      value: val,
      isExpanded: true,
      dropdownColor: AppColors.darkBgSecondary,
      underline: const SizedBox(),
      style: const TextStyle(color: AppColors.primaryCyan, fontSize: 13),
      items: _langNames.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              const SizedBox(height: 8),
              _buildCategories(),
              const SizedBox(height: 8),
              Expanded(child: _buildWordList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryCyan,
        onPressed: _addManualWord,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Diccionario',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_words.length}',
              style: const TextStyle(
                color: AppColors.primaryCyan,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Buscar en mi diccionario...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
            icon: Icon(Icons.search_rounded, color: AppColors.primaryCyan),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCat == cat;
          final color = _catColors[cat] ?? AppColors.primaryCyan;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCat = cat);
              _loadWords();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color.withOpacity(0.5) : Colors.white12,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? color : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryCyan),
      );
    }

    if (_words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: AppColors.primaryCyan.withOpacity(0.15),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu diccionario está vacío',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Las palabras se guardan automáticamente\ndesde el traductor AR, conversaciones y fotos',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
      itemCount: _words.length,
      itemBuilder: (context, index) => _buildWordCard(_words[index]),
    );
  }

  Widget _buildWordCard(SavedWord word) {
    final catColor = _catColors[word.category] ?? AppColors.primaryCyan;

    return Dismissible(
      key: Key(word.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => _deleteWord(word),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.original,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    word.translated,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${word.srcLang}→${word.tgtLang}',
                    style: TextStyle(
                      color: catColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _speakWord(word.original, word.srcLang),
                      child: Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white30,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _speakWord(word.translated, word.tgtLang),
                      child: Icon(
                        Icons.record_voice_over_rounded,
                        color: catColor.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
