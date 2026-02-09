import 'package:flutter/material.dart';

import '../../ui/screens/splash_screen.dart';
import '../../ui/screens/onboarding_screen.dart';
import '../../ui/screens/home_screen.dart';
import '../../ui/screens/chat_screen.dart';
import '../../ui/screens/settings_screen.dart';
import '../../ui/screens/profile_screen.dart';
import '../../ui/screens/create_group_screen.dart';
import '../../ui/screens/group_info_screen.dart';
import '../../ui/screens/mesh_stats_screen.dart';
import '../../ui/screens/security_screen.dart';
import '../../ui/screens/about_screen.dart';
import '../../models/peer.dart';
import '../../models/group.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String createGroup = '/create-group';
  static const String groupInfo = '/group-info';
  static const String meshStats = '/mesh-stats';
  static const String security = '/security';
  static const String about = '/about';
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
        
      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        );
        
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
        
      case chat:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) {
          return _errorRoute('Chat requires peer or group argument');
        }
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            peer: args['peer'] as Peer?,
            group: args['group'] as Group?,
          ),
        );
        
      case settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );
        
      case profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        );
        
      case createGroup:
        return MaterialPageRoute(
          builder: (_) => const CreateGroupScreen(),
        );
        
      case groupInfo:
        final group = settings.arguments as Group?;
        if (group == null) {
          return _errorRoute('Group info requires group argument');
        }
        return MaterialPageRoute(
          builder: (_) => GroupInfoScreen(group: group),
        );
        
      case meshStats:
        return MaterialPageRoute(
          builder: (_) => const MeshStatsScreen(),
        );
        
      case security:
        return MaterialPageRoute(
          builder: (_) => const SecurityScreen(),
        );
        
      case about:
        return MaterialPageRoute(
          builder: (_) => const AboutScreen(),
        );
        
      default:
        return _errorRoute('Route ${settings.name} not found');
    }
  }
  
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}
