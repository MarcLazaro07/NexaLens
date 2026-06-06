import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../services/translation_service.dart';
import '../services/history_service.dart';
import '../services/dictionary_service.dart';

class TextTranslatorScreen extends StatefulWidget {
  const TextTranslatorScreen({super.key});

  @override
  State<TextTranslatorScreen> createState() => _TextTranslatorScreenState();
}

class _TextTranslatorScreenState extends State<TextTranslatorScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  String _translatedText = '';
  bool _isTranslating = false;

  String _srcLang = 'EN';
  String _tgtLang = 'ES';

  static const _langs = {
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

  Future<void> _translate() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      final result = await TranslationService.translate(
        text: text,
        srcLang: _srcLang,
        tgtLang: _tgtLang,
      );

      setState(() {
        _translatedText = result;
        _isTranslating = false;
      });

      // Log to history
      HistoryService.addEntry(
        type: 'Texto',
        originalText: text,
        translatedText: result,
        srcLang: _srcLang,
        tgtLang: _tgtLang,
      );
    } catch (e) {
      setState(() => _isTranslating = false);
      _showSnack('Error al traducir', AppColors.error);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _swapLangs() {
    setState(() {
      final t = _srcLang;
      _srcLang = _tgtLang;
      _tgtLang = t;
      if (_translatedText.isNotEmpty) {
        _inputCtrl.text = _translatedText;
        _translatedText = '';
        _translate();
      }
    });
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
              _buildLanguageBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildInputArea(),
                      const SizedBox(height: 20),
                      if (_translatedText.isNotEmpty || _isTranslating)
                        _buildOutputArea(),
                    ],
                  ),
                ),
              ),
              _buildTranslateButton(),
            ],
          ),
        ),
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
              'Traductor de Texto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLanguageBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _langDropdown(
              _srcLang,
              (v) => setState(() => _srcLang = v!),
              AppColors.accentPurple,
            ),
          ),
          GestureDetector(
            onTap: _swapLangs,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.accentPurple,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: _langDropdown(
              _tgtLang,
              (v) => setState(() => _tgtLang = v!),
              Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _langDropdown(
    String value,
    ValueChanged<String?> onChanged,
    Color color,
  ) {
    return DropdownButton<String>(
      value: value,
      isExpanded: true,
      dropdownColor: AppColors.darkCard,
      underline: const SizedBox(),
      icon: Icon(Icons.expand_more_rounded, color: color, size: 18),
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
      items: _langs.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildInputArea() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Escribe aquí...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  _miniButton(Icons.content_paste_rounded, () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) _inputCtrl.text = data!.text!;
                  }),
                  const SizedBox(width: 8),
                  _miniButton(Icons.close_rounded, () {
                    _inputCtrl.clear();
                    setState(() => _translatedText = '');
                  }),
                ],
              ),
            ],
          ),
          TextField(
            controller: _inputCtrl,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputArea() {
    return Column(
      children: [
        const Icon(
          Icons.keyboard_double_arrow_down_rounded,
          color: Colors.white24,
        ),
        const SizedBox(height: 20),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Resultado',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isTranslating)
                    Row(
                      children: [
                        _miniButton(Icons.copy_rounded, () {
                          Clipboard.setData(
                            ClipboardData(text: _translatedText),
                          );
                          _showSnack('Copiado ✓', AppColors.primaryCyan);
                        }),
                        const SizedBox(width: 8),
                        _miniButton(Icons.bookmark_add_rounded, () {
                          DictionaryService.saveWord(
                            original: _inputCtrl.text,
                            translated: _translatedText,
                            srcLang: _srcLang,
                            tgtLang: _tgtLang,
                            category: 'Texto',
                          );
                          _showSnack(
                            'Guardado en diccionario ✓',
                            AppColors.success,
                          );
                        }),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isTranslating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: Colors.orangeAccent,
                    ),
                  ),
                )
              else
                SelectableText(
                  _translatedText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  Widget _buildTranslateButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: _isTranslating ? null : _translate,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accentPurple, Colors.blueAccent],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPurple.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Traducir Ahora',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
