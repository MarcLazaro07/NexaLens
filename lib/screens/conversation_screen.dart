import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_colors.dart';
import '../services/translation_service.dart';
import '../services/dictionary_service.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  String _srcLang = 'ES';
  String _tgtLang = 'EN';

  bool _isListening = false;
  bool _isTranslating = false;
  String _currentPartial = '';
  int? _activeMic; // 0 = left (src), 1 = right (tgt)

  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _pulseCtrl;

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

  static const _sttLocales = {
    'ES': 'es_ES',
    'EN': 'en_US',
    'FR': 'fr_FR',
    'DE': 'de_DE',
    'PT': 'pt_BR',
    'IT': 'it_IT',
    'JA': 'ja_JP',
    'KO': 'ko_KR',
    'ZH': 'zh_CN',
    'RU': 'ru_RU',
  };

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

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onError: (e) => setState(() => _isListening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scrollCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _swapLangs() {
    setState(() {
      final t = _srcLang;
      _srcLang = _tgtLang;
      _tgtLang = t;
    });
  }

  Future<void> _startListening(int micSide) async {
    if (_isListening || _isTranslating) return;

    final lang = micSide == 0 ? _srcLang : _tgtLang;
    final locale = _sttLocales[lang] ?? 'en_US';

    setState(() {
      _isListening = true;
      _activeMic = micSide;
      _currentPartial = '';
    });

    if (SettingsService.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    await _speech.listen(
      localeId: locale,
      onResult: (result) {
        setState(() => _currentPartial = result.recognizedWords);
        if (result.finalResult) {
          _onSpeechResult(result.recognizedWords, micSide);
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _activeMic = null;
    });
  }

  Future<void> _onSpeechResult(String text, int micSide) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isListening = false;
      _isTranslating = true;
      _currentPartial = '';
    });

    final fromLang = micSide == 0 ? _srcLang : _tgtLang;
    final toLang = micSide == 0 ? _tgtLang : _srcLang;

    try {
      final translated = await TranslationService.translate(
        text: text,
        srcLang: fromLang,
        tgtLang: toLang,
      );

      if (!mounted) return;

      final msg = _ChatMessage(
        original: text,
        translated: translated,
        fromLang: fromLang,
        toLang: toLang,
        isLeft: micSide == 0,
      );

      setState(() {
        _messages.add(msg);
        _isTranslating = false;
      });

      _scrollToBottom();

      // Save to history
      HistoryService.addEntry(
        type: 'Conversación',
        originalText: text,
        translatedText: translated,
        srcLang: fromLang,
        tgtLang: toLang,
      );

      // Speak the translation
      await _tts.setLanguage(_ttsLangs[toLang] ?? 'en-US');
      await _tts.speak(translated);

      if (SettingsService.hapticFeedback) {
        HapticFeedback.selectionClick();
      }
    } catch (e) {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveToDict(_ChatMessage msg) async {
    await DictionaryService.saveWord(
      original: msg.original,
      translated: msg.translated,
      srcLang: msg.fromLang,
      tgtLang: msg.toLang,
      category: 'Conversación',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Guardado en el diccionario ✓'),
          backgroundColor: AppColors.success.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
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
              Expanded(child: _buildChatArea()),
              if (_isListening) _buildListeningIndicator(),
              if (_isTranslating) _buildTranslatingIndicator(),
              _buildMicControls(),
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
              'Modo Conversación',
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
              (v) => setState(() => _srcLang = v),
              AppColors.primaryCyan,
            ),
          ),
          GestureDetector(
            onTap: _swapLangs,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.primaryCyan,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: _langDropdown(
              _tgtLang,
              (v) => setState(() => _tgtLang = v),
              AppColors.moduleOCR,
            ),
          ),
        ],
      ),
    );
  }

  Widget _langDropdown(
    String value,
    ValueChanged<String> onChanged,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.darkCard,
        underline: const SizedBox(),
        icon: Icon(Icons.expand_more_rounded, color: color, size: 18),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        items: _langs.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_rounded,
              size: 64,
              color: AppColors.primaryCyan.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Toca un micrófono para empezar',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Habla en tu idioma y escucha la traducción',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isLeft = msg.isLeft;
    final color = isLeft ? AppColors.primaryCyan : AppColors.moduleOCR;

    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isLeft ? 4 : 18),
            bottomRight: Radius.circular(isLeft ? 18 : 4),
          ),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${msg.fromLang} → ${msg.toLang}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _saveToDict(msg),
                  child: Icon(
                    Icons.bookmark_add_outlined,
                    color: color.withOpacity(0.5),
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Original text
            Text(
              msg.original,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            // Translated text
            Text(
              msg.translated,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Action buttons
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _bubbleAction(Icons.volume_up_rounded, color, () async {
                  await _tts.setLanguage(_ttsLangs[msg.toLang] ?? 'en-US');
                  await _tts.speak(msg.translated);
                }),
                const SizedBox(width: 8),
                _bubbleAction(Icons.copy_rounded, color, () {
                  Clipboard.setData(ClipboardData(text: msg.translated));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Copiado ✓'),
                      backgroundColor: color.withOpacity(0.9),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color.withOpacity(0.7), size: 16),
      ),
    );
  }

  Widget _buildListeningIndicator() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final color = _activeMic == 0
            ? AppColors.primaryCyan
            : AppColors.moduleOCR;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05 + _pulseCtrl.value * 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.mic_rounded, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentPartial.isEmpty ? 'Escuchando...' : _currentPartial,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _stopListening,
                child: Icon(Icons.stop_circle_rounded, color: color, size: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranslatingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryCyan.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryCyan.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryCyan,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Traduciendo...',
            style: TextStyle(color: AppColors.primaryCyan, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMicControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 16, 30, 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _micButton(0, _srcLang, AppColors.primaryCyan),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.compare_arrows_rounded,
              color: Colors.white38,
              size: 24,
            ),
          ),
          _micButton(1, _tgtLang, AppColors.moduleOCR),
        ],
      ),
    );
  }

  Widget _micButton(int side, String lang, Color color) {
    final isActive = _isListening && _activeMic == side;
    final isDisabled = _isListening && _activeMic != side || _isTranslating;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isDisabled
              ? null
              : () {
                  if (isActive) {
                    _stopListening();
                  } else {
                    _startListening(side);
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withOpacity(0.3)
                  : isDisabled
                  ? Colors.white.withOpacity(0.03)
                  : color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? color
                    : isDisabled
                    ? Colors.white10
                    : color.withOpacity(0.4),
                width: isActive ? 3 : 2,
              ),
              boxShadow: isActive
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)]
                  : null,
            ),
            child: Icon(
              isActive ? Icons.stop_rounded : Icons.mic_rounded,
              color: isDisabled ? Colors.white24 : color,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _langs[lang] ?? lang,
          style: TextStyle(
            color: isDisabled ? Colors.white24 : color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  final String original;
  final String translated;
  final String fromLang;
  final String toLang;
  final bool isLeft;

  _ChatMessage({
    required this.original,
    required this.translated,
    required this.fromLang,
    required this.toLang,
    required this.isLeft,
  });
}
