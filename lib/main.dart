import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/di/injection_container.dart';
import 'core/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/error/error_handler.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure system UI
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize error handling
  ErrorHandler.initialize();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Setup dependency injection
  await InjectionContainer.init();
  
  // Load app configuration
  await AppConfig.load();
  
  runApp(const SpeewApp());
}

class SpeewApp extends StatelessWidget {
  const SpeewApp({super.key});
  
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => getIt<ThemeProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<ChatProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<ConnectionProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<SettingsProvider>(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          ErrorHandler.setNavigatorKey(_navigatorKey);
          
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Speew',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            onGenerateRoute: AppRouter.generateRoute,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
