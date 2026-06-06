import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../services/translation_service.dart';
import '../services/history_service.dart';
import '../services/dictionary_service.dart';
import '../services/settings_service.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});
  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen>
    with WidgetsBindingObserver {
  // ─── Camera ───
  CameraController? _cameraCtrl;
  bool _isCameraReady = false;
  bool _isFrontCamera = false;
  final FlutterTts _tts = FlutterTts();

  // ─── OCR ───
  final _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  String _detectedText = '';
  Timer? _ocrDebounce;

  // ─── Translation ───
  String _srcLang = 'ES';
  String _tgtLang = 'EN';
  String _translatedText = '';
  bool _isTranslating = false;
  bool _hasResult = false;
  bool _overlayMode = true;
  bool _liveMode = false; // Start off by default
  Timer? _translateDebounce;
  String _errorMsg = '';

  // ─── AR Overlay ───
  RecognizedText? _lastRecognizedText;
  Size? _imageSize;
  final Map<String, String> _translationCache = {};

  // ─── Interactive ROI ───
  Rect _roiRect = const Rect.fromLTWH(40, 200, 280, 200);

  // ─── Languages ───
  final _langs = {
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
    'AR': 'العربية',
    'HI': 'हिन्दी',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ocrDebounce?.cancel();
    _translateDebounce?.cancel();
    _stopLiveOCR();
    _textRecognizer.close();
    _tts.stop();
    TranslationService.dispose(); // Cleanup on-device models
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraCtrl?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ────────────────────── Camera Setup ──────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMsg = 'No cameras available');
        return;
      }

      final cam = cameras.firstWhere(
        (c) =>
            c.lensDirection ==
            (_isFrontCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => cameras.first,
      );

      _cameraCtrl = CameraController(
        cam,
        ResolutionPreset.veryHigh, // even better quality
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraCtrl!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _errorMsg = '';
      });

      // Start streaming frames for live OCR when in live mode
      if (_liveMode) _startLiveOCR();
    } catch (e) {
      setState(() => _errorMsg = 'Error de cámara: $e');
    }
  }

  // ────────────────────── Live OCR ──────────────────────

  void _startLiveOCR() {
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;
    _cameraCtrl!.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;

      _ocrDebounce?.cancel();
      _ocrDebounce = Timer(const Duration(milliseconds: 500), () {
        _processFrame(image);
      });
    });
  }

  void _stopLiveOCR() {
    try {
      _cameraCtrl?.stopImageStream();
    } catch (_) {}
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final recognized = await _textRecognizer.processImage(inputImage);

      final screen = MediaQuery.of(context).size;
      final double srcW = image.height
          .toDouble(); // Upright width (after 90/270 rot)
      final double srcH = image.width.toDouble(); // Upright height

      final double scaleX = screen.width / srcW;
      final double scaleY = screen.height / srcH;
      final double scale = scaleX > scaleY ? scaleX : scaleY;
      final double offsetX = (screen.width - srcW * scale) / 2;
      final double offsetY = (screen.height - srcH * scale) / 2;

      final filteredBlocks = recognized.blocks.where((b) {
        final rect = b.boundingBox;
        final mapped = Rect.fromLTWH(
          rect.left * scale + offsetX,
          rect.top * scale + offsetY,
          rect.width * scale,
          rect.height * scale,
        );
        // Stricter check: Center must be inside the focus area
        return _roiRect.contains(mapped.center);
      }).toList();

      // Sort blocks by reading order (Top-to-Bottom, then Left-to-Right)
      filteredBlocks.sort((a, b) {
        final rA = a.boundingBox;
        final rB = b.boundingBox;
        final Ay = rA.top;
        final By = rB.top;

        // Dynamic line tolerance: half of the average block height
        final double tolerance = (rA.height + rB.height) / 4;

        if ((Ay - By).abs() < tolerance) {
          return rA.left.compareTo(rB.left);
        }
        return Ay.compareTo(By);
      });

      final String currentText = filteredBlocks
          .map((b) => b.text.trim())
          .join('\n\n')
          .trim();

      if (mounted) {
        setState(() {
          // ALWAYS update these for smooth AR tracking
          _lastRecognizedText = recognized;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());

          // ANTI-FLICKER: Only update text if significantly different
          if (!_isTextSimilar(currentText, _detectedText)) {
            _detectedText = currentText;
          }
        });

        if (filteredBlocks.isNotEmpty && _liveMode) {
          _autoTranslateBlocks(filteredBlocks);
        }
      }

      // Throttle OCR to ~10 FPS to reduce jitter
      await Future.delayed(const Duration(milliseconds: 100));
      _isProcessing = false;
    } catch (e) {
      _isProcessing = false;
    }
  }

  bool _isTextSimilar(String a, String b) {
    if (a == b) return true;
    final setA = a
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((s) => s.length > 2)
        .toSet();
    final setB = b
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((s) => s.length > 2)
        .toSet();
    if (setA.isEmpty || setB.isEmpty) return false;

    final intersection = setA.intersection(setB).length;
    final maxLen = setA.length > setB.length ? setA.length : setB.length;
    return (intersection / maxLen) > 0.8; // 80% word match
  }

  InputImage? _convertToInputImage(CameraImage image) {
    try {
      final camera = _cameraCtrl!.description;
      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation? rotation = InputImageRotationValue.fromRawValue(
        sensorOrientation,
      );
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // ────────────────────── Capture & Recognize ──────────────────────

  Future<void> _captureAndRecognize() async {
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;

    if (_liveMode) {
      // STOP/FREEZE
      _stopLiveOCR();
      if (SettingsService.hapticFeedback) {
        HapticFeedback.mediumImpact();
      }

      // Force one last translation pass on the currently visible blocks to ensure no 'pending' text
      if (_lastRecognizedText != null) {
        final screen = MediaQuery.of(context).size;
        final previewSize = _cameraCtrl!.value.previewSize!;
        final double scaleX = screen.width / previewSize.height;
        final double scaleY = screen.height / previewSize.width;
        final scale = scaleX > scaleY ? scaleX : scaleY;
        final offsetX = (screen.width - previewSize.height * scale) / 2;
        final offsetY = (screen.height - previewSize.width * scale) / 2;

        final finalBlocks = _lastRecognizedText!.blocks.where((b) {
          final rect = b.boundingBox;
          final mapped = Rect.fromLTWH(
            rect.left * scale + offsetX,
            rect.top * scale + offsetY,
            rect.width * scale,
            rect.height * scale,
          );
          return _roiRect.contains(mapped.center);
        }).toList();

        if (finalBlocks.isNotEmpty) {
          _autoTranslateBlocks(finalBlocks);
        }
      }

      setState(() {
        _liveMode = false;
        _hasResult = true;
      });
      return;
    } else {
      // START/RESUME
      setState(() {
        _liveMode = true;
        _hasResult = false;
        _errorMsg = '';
      });
      _startLiveOCR();
    }
  }

  // ────────────────────── Auto Translate (Live Blocks) ──────────────────────

  bool _isAutoBusy = false;
  DateTime _lastTranslateTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _autoTranslateBlocks(List<TextBlock> blocks) async {
    if (blocks.isEmpty || _isAutoBusy) return;

    final now = DateTime.now();
    if (now.difference(_lastTranslateTime) <
        const Duration(milliseconds: 600)) {
      _updateTranslatedState(blocks);
      return;
    }
    _lastTranslateTime = now;

    final toTranslate = <String>[];
    for (final b in blocks) {
      final text = b.text.trim();
      final key = text.toLowerCase();
      if (text.isNotEmpty && !_translationCache.containsKey(key)) {
        toTranslate.add(text);
      }
    }

    if (toTranslate.isEmpty) {
      _updateTranslatedState(blocks);
      return;
    }

    try {
      _isAutoBusy = true;
      final results = await Future.wait(
        toTranslate.map(
          (text) => TranslationService.translate(
            text: text,
            srcLang: _srcLang,
            tgtLang: _tgtLang,
          ).timeout(const Duration(seconds: 4), onTimeout: () => text),
        ),
      );

      for (int i = 0; i < toTranslate.length; i++) {
        final original = toTranslate[i];
        final translated = results[i];
        _translationCache[original.trim().toLowerCase()] = translated;

        // Log to history
        HistoryService.addEntry(
          type: 'AR',
          originalText: original,
          translatedText: translated,
          srcLang: _srcLang,
          tgtLang: _tgtLang,
        );

        // Selective auto-save to dictionary
        if (SettingsService.autoSaveAR && original.split(' ').length >= 3) {
          DictionaryService.saveWord(
            original: original,
            translated: translated,
            srcLang: _srcLang,
            tgtLang: _tgtLang,
            category: 'AR',
          );
        }

        // Haptic feedback if enabled
        if (SettingsService.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
      }

      if (mounted) _updateTranslatedState(blocks);
    } catch (e) {
      for (final text in toTranslate) {
        _translationCache[text] = text;
      }
      if (mounted) _updateTranslatedState(blocks);
    } finally {
      _isAutoBusy = false;
    }
  }

  void _updateTranslatedState(List<TextBlock> blocks) {
    if (!mounted) return;
    setState(() {
      _translatedText = blocks
          .map((b) => _translationCache[b.text.trim().toLowerCase()] ?? b.text)
          .join(' ');
      _hasResult = true;
    });
  }

  // ────────────────────── UI Helpers ──────────────────────

  void _toggleLiveMode() {
    setState(() => _liveMode = !_liveMode);
    if (_liveMode) {
      _startLiveOCR();
    } else {
      _stopLiveOCR();
    }
  }

  void _swapLangs() => setState(() {
    final t = _srcLang;
    _srcLang = _tgtLang;
    _tgtLang = t;
    _hasResult = false;
    _translatedText = '';
    _detectedText = '';
    _translationCache.clear();
  });

  void _reset() {
    _stopLiveOCR();
    _translationCache.clear();
    setState(() {
      _hasResult = false;
      _translatedText = '';
      _detectedText = '';
      _errorMsg = '';
      _liveMode = true;
    });
    _startLiveOCR();
  }

  // ────────────────────── BUILD ──────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview (Fixed Stretching)
          if (_isCameraReady && _cameraCtrl != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraCtrl!.value.previewSize!.height,
                  height: _cameraCtrl!.value.previewSize!.width,
                  child: CameraPreview(_cameraCtrl!),
                ),
              ),
            )
          else
            Container(
              color: Colors.grey[900],
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: _errorMsg.isNotEmpty
                    ? _buildErrorState()
                    : const CircularProgressIndicator(
                        color: AppColors.moduleTranslate,
                      ),
              ),
            ),

          // AR Overlay (Google Lens Style)
          if (_hasResult && _overlayMode && _lastRecognizedText != null)
            _buildAROverlay(),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _circleBtn(
                    Icons.arrow_back_rounded,
                    () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Traductor Visual',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                  const Spacer(),
                  _circleBtn(
                    _overlayMode ? Icons.layers_rounded : Icons.layers_outlined,
                    () => setState(() => _overlayMode = !_overlayMode),
                  ),
                ],
              ),
            ),
          ),

          // Language selector bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _langChip(
                      _srcLang,
                      _langs[_srcLang] ?? _srcLang,
                      AppColors.moduleTranslate,
                      () => _pickLang(true),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: GestureDetector(
                      onTap: _swapLangs,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.moduleTranslate.withOpacity(0.2),
                          border: Border.all(
                            color: AppColors.moduleTranslate.withOpacity(0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.moduleTranslate.withOpacity(
                                0.15,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.moduleTranslate,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _langChip(
                      _tgtLang,
                      _langs[_tgtLang] ?? _tgtLang,
                      AppColors.primaryCyan,
                      () => _pickLang(false),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Interactive Scanning Area ROI
          _buildDraggableROI(),

          // Translating indicator
          if (_isTranslating && !_hasResult)
            Center(
              child: GlassContainer(
                padding: const EdgeInsets.all(28),
                borderRadius: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.moduleTranslate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Traduciendo...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_detectedText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          _detectedText.length > 60
                              ? '${_detectedText.substring(0, 60)}...'
                              : _detectedText,
                          style: TextStyle(
                            color: AppColors.textTertiary.withOpacity(0.7),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Error message
          if (_errorMsg.isNotEmpty && !_isTranslating)
            Positioned(
              bottom: 160,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMsg,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _errorMsg = ''),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Result card (non-overlay/panel mode)
          if (_hasResult && !_overlayMode)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                borderColor: AppColors.moduleTranslate.withOpacity(0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Original text
                    _langLabel(_srcLang, 'Original', AppColors.moduleTranslate),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 80),
                      child: SingleChildScrollView(
                        child: Text(
                          _detectedText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppColors.glassBorder),
                    ),
                    // Translated text
                    _langLabel(_tgtLang, 'Traducción', AppColors.primaryCyan),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: SingleChildScrollView(
                        child: Text(
                          _translatedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _actionBtn(
                            Icons.copy_rounded,
                            'Copiar',
                            AppColors.primaryCyan,
                            () {
                              Clipboard.setData(
                                ClipboardData(text: _translatedText),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copiado al portapapeles'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        _actionBtn(
                          Icons.volume_up_rounded,
                          'Escuchar',
                          AppColors.moduleTranslate,
                          () async {
                            await _tts.setLanguage(_tgtLang.toLowerCase());
                            await _tts.speak(_translatedText);
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionBtn(
                            Icons.bookmark_add_rounded,
                            'Guardar',
                            AppColors.success,
                            () async {
                              await DictionaryService.saveWord(
                                original: _detectedText,
                                translated: _translatedText,
                                srcLang: _srcLang,
                                tgtLang: _tgtLang,
                                category: 'AR',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Guardado en el diccionario ✓'),
                                  backgroundColor: AppColors.success,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Live mode toggle
                  _circleBtn(
                    _liveMode
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    _toggleLiveMode,
                    highlight: _liveMode,
                  ),
                  // Main capture/translate button
                  GestureDetector(
                    onTap: _isTranslating ? null : _captureAndRecognize,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isTranslating
                              ? AppColors.textTertiary
                              : AppColors.moduleTranslate,
                          width: 3,
                        ),
                        boxShadow: _isTranslating
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.moduleTranslate.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                      child: Center(
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isTranslating
                                ? AppColors.textTertiary.withOpacity(0.2)
                                : AppColors.moduleTranslate.withOpacity(0.2),
                          ),
                          child: Icon(
                            _isTranslating
                                ? Icons.hourglass_top_rounded
                                : (_liveMode
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded),
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Reset
                  _circleBtn(
                    _hasResult
                        ? Icons.refresh_rounded
                        : Icons.flash_off_rounded,
                    _hasResult ? _reset : () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────── Widgets ──────────────────────

  Widget _circleBtn(IconData i, VoidCallback f, {bool highlight = false}) =>
      GestureDetector(
        onTap: f,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlight
                ? AppColors.success.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: highlight
                  ? AppColors.success.withOpacity(0.5)
                  : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Icon(
            i,
            color: highlight ? AppColors.success : Colors.white,
            size: 22,
          ),
        ),
      );

  Widget _langChip(String code, String name, Color c, VoidCallback f) =>
      GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, color: c, size: 16),
            ],
          ),
        ),
      );

  Widget _langLabel(String code, String label, Color c) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          code,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
    ],
  );

  Widget _actionBtn(IconData i, String l, Color c, VoidCallback f) =>
      GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, color: c, size: 16),
              const SizedBox(width: 6),
              Text(
                l,
                style: TextStyle(
                  color: c,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildErrorState() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.camera_alt_outlined,
        color: AppColors.textTertiary.withOpacity(0.3),
        size: 56,
      ),
      const SizedBox(height: 16),
      Text(
        _errorMsg,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _initCamera,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.moduleTranslate.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.moduleTranslate.withOpacity(0.4),
            ),
          ),
          child: const Text(
            'Reintentar',
            style: TextStyle(
              color: AppColors.moduleTranslate,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );

  // ────────────────────── Language Picker ──────────────────────

  void _pickLang(bool src) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              src ? 'Idioma Origen' : 'Idioma Destino',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _langs.entries.map((e) {
                final sel = src ? e.key == _srcLang : e.key == _tgtLang;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (src) {
                        _srcLang = e.key;
                      } else {
                        _tgtLang = e.key;
                      }
                      _hasResult = false;
                      _translatedText = '';
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.moduleTranslate.withOpacity(0.2)
                          : AppColors.glassWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel
                            ? AppColors.moduleTranslate
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      '${e.key}  ${e.value}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel
                            ? AppColors.moduleTranslate
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ────────────────────── AR & ROI ──────────────────────

  Widget _buildAROverlay() {
    if (_lastRecognizedText == null || _imageSize == null)
      return const SizedBox();

    return Positioned.fill(
      child: CustomPaint(
        painter: AROverlayPainter(
          recognizedText: _lastRecognizedText!,
          imageSize: _imageSize!,
          translationCache: _translationCache,
          tgtLang: _tgtLang,
          roiRect: _roiRect,
        ),
      ),
    );
  }

  Widget _buildDraggableROI() {
    return Positioned.fromRect(
      rect: _roiRect,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Body (Draggable)
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _roiRect = _roiRect.shift(details.delta);
                final screen = MediaQuery.of(context).size;
                _roiRect = Rect.fromLTWH(
                  _roiRect.left.clamp(0, screen.width - _roiRect.width),
                  _roiRect.top.clamp(0, screen.height - _roiRect.height),
                  _roiRect.width,
                  _roiRect.height,
                );
              });
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.moduleTranslate.withOpacity(0.5),
                  width: 2,
                ),
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Resize handle (bottom-right)
          Positioned(
            right: -12,
            bottom: -12,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _roiRect = Rect.fromLTRB(
                    _roiRect.left,
                    _roiRect.top,
                    (_roiRect.right + details.delta.dx).clamp(
                      _roiRect.left + 120,
                      MediaQuery.of(context).size.width,
                    ),
                    (_roiRect.bottom + details.delta.dy).clamp(
                      _roiRect.top + 80,
                      MediaQuery.of(context).size.height,
                    ),
                  );
                });
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.moduleTranslate,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6)],
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),

          // Label
          Positioned(
            top: -28,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.moduleTranslate,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ENFOQUE DE TRADUCCIÓN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AROverlayPainter ───

class AROverlayPainter extends CustomPainter {
  final RecognizedText recognizedText;
  final Size imageSize;
  final Map<String, String> translationCache;
  final String tgtLang;
  final Rect roiRect;

  AROverlayPainter({
    required this.recognizedText,
    required this.imageSize,
    required this.translationCache,
    required this.tgtLang,
    required this.roiRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    // UPWARD coordinate mapping (ML Kit already handled rotation)
    final double srcW = imageSize.height;
    final double srcH = imageSize.width;

    final double scaleX = size.width / srcW;
    final double scaleY = size.height / srcH;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    final double offsetX = (size.width - srcW * scale) / 2;
    final double offsetY = (size.height - srcH * scale) / 2;

    final paintBg = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = AppColors.primaryCyan.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final TextBlock block in recognizedText.blocks) {
      final rect = block.boundingBox;

      // Direct mapping
      final mappedRect = Rect.fromLTWH(
        rect.left * scale + offsetX,
        rect.top * scale + offsetY,
        rect.width * scale,
        rect.height * scale,
      );

      // Stricter check: Center must be inside the focus area
      if (!roiRect.contains(mappedRect.center)) continue;

      // Draw background
      canvas.drawRRect(
        RRect.fromRectAndRadius(mappedRect, const Radius.circular(4)),
        paintBg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(mappedRect, const Radius.circular(4)),
        paintBorder,
      );

      final cacheResult = translationCache[block.text.trim().toLowerCase()];
      final translatedText = cacheResult ?? block.text;
      final bool isPending = cacheResult == null;

      // ─── Hyper-Adaptive Font Size Logic ───
      final int charCount = translatedText.length;
      final bool isParagraph = charCount > 50;

      // Start with a more conservative size for long paragraphs
      double fontSize = isParagraph
          ? (mappedRect.height * 0.55).clamp(6, 24)
          : (mappedRect.height * 0.75).clamp(6, 32);

      TextPainter tp;
      int attempts = 0;
      do {
        tp = TextPainter(
          text: TextSpan(
            text: translatedText,
            style: TextStyle(
              color: isPending
                  ? AppColors.primaryCyan.withOpacity(0.3)
                  : AppColors.primaryCyan,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              height: 1.0, // Tighter height for paragraphs
              backgroundColor: Colors.black54,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: isParagraph ? 10 : 4,
          ellipsis: '...',
          textAlign: TextAlign.start,
        )..layout(maxWidth: mappedRect.width);

        // If it fits and doesn't exceed height, we are done
        if ((tp.height <= mappedRect.height) || fontSize <= 4) break;

        fontSize -= isParagraph ? 1.0 : 2.0;
        attempts++;
      } while (attempts < 15);

      // Center vertically within the box
      final textOffset = Offset(
        mappedRect.left,
        mappedRect.top + (mappedRect.height - tp.height) / 2,
      );

      tp.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant AROverlayPainter oldDelegate) => true;
}
