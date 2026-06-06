import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import '../services/dictionary_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSaveAR = SettingsService.autoSaveAR;
  bool _haptic = SettingsService.hapticFeedback;
  String _quality = SettingsService.cameraQuality;
  String _lang = SettingsService.appLanguage;

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

  Future<void> _confirmAction(
    String title,
    String msg,
    VoidCallback onConfirm,
  ) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
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
              'Confirmar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (res == true) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Ajustes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSectionHeader('Traducción y IA'),
              _buildSettingItem(
                icon: Icons.auto_awesome_rounded,
                title: 'Auto-guardar en AR',
                subtitle: 'Guardar frases automáticamente al escanear',
                trailing: Switch(
                  value: _autoSaveAR,
                  onChanged: (v) async {
                    await SettingsService.setAutoSaveAR(v);
                    setState(() => _autoSaveAR = v);
                  },
                  activeColor: AppColors.primaryCyan,
                ),
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.vibration_rounded,
                title: 'Feedback háptico',
                subtitle: 'Vibrar al detectar texto u objetos',
                trailing: Switch(
                  value: _haptic,
                  onChanged: (v) async {
                    await SettingsService.setHapticFeedback(v);
                    setState(() => _haptic = v);
                  },
                  activeColor: AppColors.primaryCyan,
                ),
                onTap: () {},
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Interfaz y Sistema'),
              _buildSettingItem(
                icon: Icons.translate_rounded,
                title: 'Idioma de la App',
                subtitle: _lang,
                onTap: () async {
                  // Simple toggle for demo
                  final newLang = _lang == 'Español' ? 'English' : 'Español';
                  await SettingsService.setAppLanguage(newLang);
                  setState(() => _lang = newLang);
                },
              ),
              _buildSettingItem(
                icon: Icons.high_quality_rounded,
                title: 'Calidad de Cámara',
                subtitle: _quality,
                onTap: () async {
                  final newQ = _quality == 'High' ? 'Medium' : 'High';
                  await SettingsService.setCameraQuality(newQ);
                  setState(() => _quality = newQ);
                },
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Datos y Almacenamiento'),
              _buildSettingItem(
                icon: Icons.delete_sweep_rounded,
                title: 'Limpiar Historial',
                subtitle: 'Borra todas tus traducciones pasadas',
                color: AppColors.error,
                onTap: () => _confirmAction(
                  '¿Limpiar Historial?',
                  'Esta acción no se puede deshacer.',
                  () async {
                    await HistoryService.clearAll();
                    _showSnack('Historial limpiado ✓', AppColors.error);
                  },
                ),
              ),
              _buildSettingItem(
                icon: Icons.folder_delete_rounded,
                title: 'Vaciar Diccionario',
                subtitle: 'Borra todas tus palabras guardadas',
                color: AppColors.error,
                onTap: () => _confirmAction(
                  '¿Vaciar Diccionario?',
                  'Perderás todas tus frases guardadas.',
                  () async {
                    await DictionaryService.clearAll();
                    _showSnack('Diccionario vaciado ✓', AppColors.error);
                  },
                ),
              ),

              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient.createShader(bounds),
                      child: const Text(
                        'NexaLens',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Versión 1.2.0 • Premium Edition',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? color,
    required VoidCallback onTap,
  }) {
    final iconColor = color ?? AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color ?? AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary.withOpacity(0.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
