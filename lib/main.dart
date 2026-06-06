import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/translator_screen.dart';
import 'screens/document_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/history_screen.dart';
import 'screens/text_translator_screen.dart';
import 'screens/login_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.darkSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NexaLensApp());
}

class NexaLensApp extends StatelessWidget {
  const NexaLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexaLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: AppColors.darkSurface,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/translator': (context) => const TranslatorScreen(),
        '/conversation': (context) => const ConversationScreen(),
        '/document': (context) => const PhotoTranslatorScreen(),
        '/dictionary': (context) => const DictionaryScreen(),
        '/history': (context) => const HistoryScreen(),
        '/text_translator': (context) => const TextTranslatorScreen(),
      },
    );
  }
}
