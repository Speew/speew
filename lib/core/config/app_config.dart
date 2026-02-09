import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // App Information
  static const String appName = 'Speew';
  static const String appVersion = '2.0.0';
  static const int appBuildNumber = 200;
  
  // Network Configuration
  static const String p2pServiceId = 'com.speew.p2p';
  static const String p2pStrategy = 'P2P_CLUSTER';
  static const int maxPeers = 8;
  static const int connectionTimeout = 30000; // 30 seconds
  static const int messageTimeout = 10000; // 10 seconds
  
  // Mesh Network
  static const int meshMaxHops = 5;
  static const int meshRouteTimeout = 60000; // 60 seconds
  static const int meshDiscoveryInterval = 5000; // 5 seconds
  
  // Storage
  static const String databaseName = 'speew.db';
  static const int databaseVersion = 2;
  static const String hiveChatBox = 'chats';
  static const String hiveMessagesBox = 'messages';
  static const String hiveContactsBox = 'contacts';
  static const String hiveGroupsBox = 'groups';
  static const String hiveSettingsBox = 'settings';
  
  // Media
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int imageQuality = 85;
  static const int thumbnailSize = 200;
  
  // Voice & Video
  static const int voiceMessageMaxDuration = 300; // 5 minutes
  static const int voiceCallTimeout = 45000; // 45 seconds
  static const int voiceBitrate = 64000; // 64kbps
  static const int videoBitrate = 500000; // 500kbps
  
  // Security
  static const int encryptionKeySize = 256;
  static const int hashIterations = 10000;
  static const int saltLength = 32;
  static const String encryptionAlgorithm = 'AES-256-GCM';
  
  // Auto-destruct
  static const List<int> destructTimers = [
    30,      // 30 seconds
    60,      // 1 minute
    300,     // 5 minutes
    3600,    // 1 hour
    86400,   // 24 hours
  ];
  
  // Performance
  static const int messageLoadBatchSize = 50;
  static const int messageCacheSize = 200;
  static const int imageCacheSize = 100;
  static const bool enablePerformanceMonitoring = !kReleaseMode;
  
  // UI
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration splashDuration = Duration(seconds: 2);
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  
  // Notifications
  static const String notificationChannelId = 'speew_messages';
  static const String notificationChannelName = 'Messages';
  static const String notificationChannelDescription = 'New message notifications';
  
  // User Preferences (loaded dynamically)
  static bool _darkMode = false;
  static bool _notificationsEnabled = true;
  static bool _soundEnabled = true;
  static bool _vibrationEnabled = true;
  static bool _stealthMode = false;
  static String _userName = '';
  static String _userStatus = '';
  
  static bool get darkMode => _darkMode;
  static bool get notificationsEnabled => _notificationsEnabled;
  static bool get soundEnabled => _soundEnabled;
  static bool get vibrationEnabled => _vibrationEnabled;
  static bool get stealthMode => _stealthMode;
  static String get userName => _userName;
  static String get userStatus => _userStatus;
  
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    _darkMode = prefs.getBool('dark_mode') ?? false;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    _stealthMode = prefs.getBool('stealth_mode') ?? false;
    _userName = prefs.getString('user_name') ?? '';
    _userStatus = prefs.getString('user_status') ?? '';
  }
  
  static Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }
  
  static Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }
  
  static Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
  }
  
  static Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', value);
  }
  
  static Future<void> setStealthMode(bool value) async {
    _stealthMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stealth_mode', value);
  }
  
  static Future<void> setUserName(String value) async {
    _userName = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', value);
  }
  
  static Future<void> setUserStatus(String value) async {
    _userStatus = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_status', value);
  }
}
