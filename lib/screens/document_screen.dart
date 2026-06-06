import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../services/translation_service.dart';
import '../services/dictionary_service.dart';
import '../services/history_service.dart';

class PhotoTranslatorScreen extends StatefulWidget {
  const PhotoTranslatorScreen({super.key});

  @override
  State<PhotoTranslatorScreen> createState() => _PhotoTranslatorScreenState();
}

class _PhotoTranslatorScreenState extends State<PhotoTranslatorScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer = TextRecognizer();

  File? _selectedImage;
  String _extractedText = '';
  String _translatedText = '';
  bool _isProcessing = false;
  bool _isTranslating = false;
  bool _hasResult = false;

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

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null) return;

    setState(() {
      _selectedImage = File(xFile.path);
      _hasResult = false;
      _extractedText = '';
      _translatedText = '';
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(xFile.path);
      final recognized = await _recognizer.processImage(inputImage);

      final blocks = recognized.blocks.toList();
      blocks.sort((a, b) {
        final ay = a.boundingBox.top;
        final by = b.boundingBox.top;
        final tol = (a.boundingBox.height + b.boundingBox.height) / 4;
        if ((ay - by).abs() < tol) {
          return a.boundingBox.left.compareTo(b.boundingBox.left);
        }
        return ay.compareTo(by);
      });

      final text = blocks.map((b) => b.text.trim()).join('\n').trim();

      if (!mounted) return;

      if (text.isEmpty) {
        setState(() {
          _isProcessing = false;
          _extractedText = '';
        });
        _showSnack('No se encontró texto en esta imagen', AppColors.warning);
        return;
      }

      setState(() {
        _extractedText = text;
        _isProcessing = false;
      });

      _translateText();
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnack('Error al procesar la imagen', AppColors.error);
      }
    }
  }

  Future<void> _translateText() async {
    if (_extractedText.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      // Translate line by line to maintain structure
      final lines = _extractedText.split('\n');
      final translated = <String>[];

      for (final line in lines) {
        if (line.trim().isEmpty) {
          translated.add('');
          continue;
        }
        final t = await TranslationService.translate(
          text: line,
          srcLang: _srcLang,
          tgtLang: _tgtLang,
        );
        translated.add(t);
      }

      if (!mounted) return;

      final result = translated.join('\n');

      setState(() {
        _translatedText = result;
        _isTranslating = false;
        _hasResult = true;
      });

      // Save to history
      HistoryService.addEntry(
        type: 'Foto',
        originalText: _extractedText.length > 200
            ? '${_extractedText.substring(0, 200)}...'
            : _extractedText,
        translatedText: result.length > 200
            ? '${result.substring(0, 200)}...'
            : result,
        srcLang: _srcLang,
        tgtLang: _tgtLang,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        _showSnack('Error al traducir', AppColors.error);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
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
      _hasResult = false;
      _translatedText = '';
    });
    if (_extractedText.isNotEmpty) _translateText();
  }

  Future<void> _saveAllToDict() async {
    final origLines = _extractedText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final transLines = _translatedText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final count = origLines.length < transLines.length
        ? origLines.length
        : transLines.length;
    for (int i = 0; i < count; i++) {
      await DictionaryService.saveWord(
        original: origLines[i].trim(),
        translated: transLines[i].trim(),
        srcLang: _srcLang,
        tgtLang: _tgtLang,
        category: 'Foto',
      );
    }
    _showSnack(
      '$count frases guardadas en el diccionario ✓',
      AppColors.success,
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
              _buildLanguageBar(),
              Expanded(child: _buildContent()),
              if (!_hasResult && _selectedImage == null) _buildPickerButtons(),
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
              'Traductor de Fotos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_selectedImage != null)
            GestureDetector(
              onTap: () => setState(() {
                _selectedImage = null;
                _extractedText = '';
                _translatedText = '';
                _hasResult = false;
              }),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            )
          else
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
              (v) => setState(() {
                _srcLang = v;
              }),
              AppColors.moduleDocument,
            ),
          ),
          GestureDetector(
            onTap: _swapLangs,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.moduleDocument.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.moduleDocument,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: _langDropdown(
              _tgtLang,
              (v) => setState(() {
                _tgtLang = v;
              }),
              Colors.orangeAccent,
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

  Widget _buildContent() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.moduleDocument),
            SizedBox(height: 16),
            Text(
              'Extrayendo texto de la imagen...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_selectedImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_rounded,
              size: 72,
              color: AppColors.moduleDocument.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecciona una foto para traducir',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'El texto se extraerá y traducirá automáticamente',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),

          // Original text
          _textCard(
            title: 'Texto Original',
            text: _extractedText,
            color: AppColors.moduleDocument,
            icon: Icons.text_fields_rounded,
          ),
          const SizedBox(height: 12),

          // Translation
          if (_isTranslating)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Traduciendo...',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 14),
                  ),
                ],
              ),
            ),

          if (_hasResult) ...[
            _textCard(
              title: 'Traducción',
              text: _translatedText,
              color: Colors.orangeAccent,
              icon: Icons.translate_rounded,
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    Icons.copy_rounded,
                    'Copiar',
                    AppColors.primaryCyan,
                    () {
                      Clipboard.setData(ClipboardData(text: _translatedText));
                      _showSnack('Traducción copiada ✓', AppColors.primaryCyan);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    Icons.share_rounded,
                    'Compartir',
                    AppColors.moduleDocument,
                    () async {
                      await Share.share(_translatedText);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    Icons.bookmark_add_rounded,
                    'Guardar',
                    AppColors.success,
                    _saveAllToDict,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _textCard({
    required String title,
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: _bigPickerButton(
              Icons.photo_library_rounded,
              'Galería',
              AppColors.moduleDocument,
              () => _pickImage(ImageSource.gallery),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _bigPickerButton(
              Icons.camera_alt_rounded,
              'Cámara',
              AppColors.primaryCyan,
              () => _pickImage(ImageSource.camera),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigPickerButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
