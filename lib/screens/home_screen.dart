import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/module_card.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _staggerController;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pages.addAll([
      _HomeContent(staggerController: _staggerController),
      const HistoryScreen(),
      const SettingsScreen(),
    ]);
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
              ),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 1
                    ? Icons.history_rounded
                    : Icons.history_outlined,
              ),
              label: 'Historial',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 2
                    ? Icons.settings_rounded
                    : Icons.settings_outlined,
              ),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final AnimationController staggerController;

  const _HomeContent({required this.staggerController});

  @override
  Widget build(BuildContext context) {
    final modules = _getModules(context);
    final quickActions = _getQuickActions(context);

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.primaryGradient.createShader(bounds),
                          child: const Text(
                            'NexaLens',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Acciones Rápidas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quickActions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final qa = quickActions[index];
                        return _QuickActionChip(
                          icon: qa['icon'] as IconData,
                          label: qa['label'] as String,
                          color: qa['color'] as Color,
                          onTap: qa['onTap'] as VoidCallback,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Modules header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Text(
                'Módulos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // Modules grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final m = modules[index];
                final delay = index * 0.08;
                return _StaggeredItem(
                  controller: staggerController,
                  delay: delay,
                  child: ModuleCard(
                    icon: m['icon'] as IconData,
                    title: m['title'] as String,
                    subtitle: m['subtitle'] as String,
                    color: m['color'] as Color,
                    onTap: m['onTap'] as VoidCallback,
                    index: index,
                  ),
                );
              }, childCount: modules.length),
            ),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getQuickActions(BuildContext context) {
    return [
      {
        'icon': Icons.translate_rounded,
        'label': 'AR Trad',
        'color': AppColors.moduleTranslate,
        'onTap': () => Navigator.pushNamed(context, '/translator'),
      },
      {
        'icon': Icons.article_rounded,
        'label': 'Texto',
        'color': AppColors.accentPurple,
        'onTap': () => Navigator.pushNamed(context, '/text_translator'),
      },
      {
        'icon': Icons.forum_rounded,
        'label': 'Hablar',
        'color': AppColors.moduleOCR,
        'onTap': () => Navigator.pushNamed(context, '/conversation'),
      },
      {
        'icon': Icons.image_search_rounded,
        'label': 'Fotos',
        'color': AppColors.moduleDocument,
        'onTap': () => Navigator.pushNamed(context, '/document'),
      },
      {
        'icon': Icons.menu_book_rounded,
        'label': 'Glosario',
        'color': AppColors.moduleAcademic,
        'onTap': () => Navigator.pushNamed(context, '/dictionary'),
      },
    ];
  }

  List<Map<String, dynamic>> _getModules(BuildContext context) {
    return [
      {
        'icon': Icons.translate_rounded,
        'title': 'Traductor AR',
        'subtitle': 'Traducción visual en tiempo real',
        'color': AppColors.moduleTranslate,
        'onTap': () => Navigator.pushNamed(context, '/translator'),
      },
      {
        'icon': Icons.article_rounded,
        'title': 'Traductor de Texto',
        'subtitle': 'Traducción manual rápida',
        'color': AppColors.accentPurple,
        'onTap': () => Navigator.pushNamed(context, '/text_translator'),
      },
      {
        'icon': Icons.forum_rounded,
        'title': 'Conversación',
        'subtitle': 'Habla y traduce al instante',
        'color': AppColors.moduleOCR,
        'onTap': () => Navigator.pushNamed(context, '/conversation'),
      },
      {
        'icon': Icons.photo_library_rounded,
        'title': 'Traductor de Fotos',
        'subtitle': 'Extrae texto de tu galería',
        'color': AppColors.moduleDocument,
        'onTap': () => Navigator.pushNamed(context, '/document'),
      },
      {
        'icon': Icons.menu_book_rounded,
        'title': 'Diccionario Inteligente',
        'subtitle': 'Tu glosario personal guardado',
        'color': AppColors.moduleAcademic,
        'onTap': () => Navigator.pushNamed(context, '/dictionary'),
      },
    ];
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredItem extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;

  const _StaggeredItem({
    required this.controller,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final begin = delay.clamp(0.0, 0.8);
    final end = (delay + 0.2).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
