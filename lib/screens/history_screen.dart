import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../services/history_service.dart';
import '../services/dictionary_service.dart';
import '../models/history_entry.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'Todos';
  final List<String> _filters = [
    'Todos',
    'AR',
    'Conversación',
    'Foto',
    'Texto',
  ];
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;

  static const _typeColors = {
    'AR': AppColors.moduleTranslate,
    'Conversación': AppColors.moduleOCR,
    'Foto': AppColors.moduleDocument,
    'Texto': AppColors.accentPurple,
  };

  static const _typeIcons = {
    'AR': Icons.translate_rounded,
    'Conversación': Icons.forum_rounded,
    'Foto': Icons.photo_library_rounded,
    'Texto': Icons.article_rounded,
  };

  Future<void> _showDetailModal(HistoryEntry entry) async {
    final typeColor = _typeColors[entry.type] ?? AppColors.primaryCyan;
    final typeIcon = _typeIcons[entry.type] ?? Icons.translate_rounded;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.type,
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMMM yyyy, HH:mm').format(entry.createdAt),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _detailSection(
              'Original (${entry.srcLang})',
              entry.originalText,
              Colors.white70,
            ),
            const SizedBox(height: 20),
            _detailSection(
              'Traducción (${entry.tgtLang})',
              entry.translatedText,
              typeColor,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _modalAction(
                    icon: Icons.copy_rounded,
                    label: 'Copiar',
                    color: AppColors.primaryCyan,
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: entry.translatedText),
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copiado ✓'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modalAction(
                    icon: Icons.bookmark_add_rounded,
                    label: 'Guardar',
                    color: AppColors.success,
                    onTap: () async {
                      await DictionaryService.saveWord(
                        original: entry.originalText,
                        translated: entry.translatedText,
                        srcLang: entry.srcLang,
                        tgtLang: entry.tgtLang,
                        category: entry.type,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Guardado en diccionario ✓'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _modalAction(
              icon: Icons.delete_outline_rounded,
              label: 'Eliminar del historial',
              color: AppColors.error,
              onTap: () {
                _deleteEntry(entry.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, String text, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: SelectableText(
            text,
            style: TextStyle(color: color, fontSize: 16, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _modalAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await HistoryService.getEntries(filter: _selectedFilter);
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEntry(String id) async {
    await HistoryService.deleteEntry(id);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text(
          '¿Borrar todo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Esta acción eliminará todo el historial de traducciones permanentemente.',
          style: TextStyle(color: Colors.white70),
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
              'Borrar todo',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HistoryService.clearAll();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_entries.isNotEmpty)
                  GestureDetector(
                    onTap: _clearAll,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(10),
                      borderRadius: 14,
                      child: const Icon(
                        Icons.delete_sweep_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                      _isLoading = true;
                    });
                    _loadHistory();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryCyan.withOpacity(0.2)
                          : AppColors.glassWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryCyan.withOpacity(0.5)
                            : AppColors.glassBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primaryCyan
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryCyan,
                  ),
                )
              : _entries.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return _HistoryCard(
                      entry: entry,
                      onDelete: () => _deleteEntry(entry.id),
                      onTap: () => _showDetailModal(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppColors.textTertiary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin resultados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay registros en esta categoría',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.entry,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor =
        _HistoryScreenState._typeColors[entry.type] ?? AppColors.primaryCyan;
    final typeIcon =
        _HistoryScreenState._typeIcons[entry.type] ?? Icons.translate_rounded;
    final dateStr = DateFormat('dd MMM, HH:mm').format(entry.createdAt);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 18,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(typeIcon, color: typeColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.originalText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${entry.srcLang} → ${entry.tgtLang}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: typeColor.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.translatedText,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
