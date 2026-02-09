import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  
  String _userName = '';
  String _userStatus = '';
  String _userAvatar = '';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _stealthMode = false;
  bool _autoDownloadMedia = true;
  int _messageDeleteTimer = 0; // 0 = disabled
  
  SettingsProvider({required SharedPreferences sharedPreferences})
      : _prefs = sharedPreferences {
    _loadSettings();
  }
  
  // Getters
  String get userName => _userName;
  String get userStatus => _userStatus;
  String get userAvatar => _userAvatar;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get stealthMode => _stealthMode;
  bool get autoDownloadMedia => _autoDownloadMedia;
  int get messageDeleteTimer => _messageDeleteTimer;
  
  void _loadSettings() {
    _userName = _prefs.getString('user_name') ?? '';
    _userStatus = _prefs.getString('user_status') ?? '';
    _userAvatar = _prefs.getString('user_avatar') ?? '';
    _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    _soundEnabled = _prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = _prefs.getBool('vibration_enabled') ?? true;
    _stealthMode = _prefs.getBool('stealth_mode') ?? false;
    _autoDownloadMedia = _prefs.getBool('auto_download_media') ?? true;
    _messageDeleteTimer = _prefs.getInt('message_delete_timer') ?? 0;
    
    notifyListeners();
  }
  
  Future<void> setUserName(String name) async {
    _userName = name;
    await _prefs.setString('user_name', name);
    notifyListeners();
  }
  
  Future<void> setUserStatus(String status) async {
    _userStatus = status;
    await _prefs.setString('user_status', status);
    notifyListeners();
  }
  
  Future<void> setUserAvatar(String avatar) async {
    _userAvatar = avatar;
    await _prefs.setString('user_avatar', avatar);
    notifyListeners();
  }
  
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _prefs.setBool('notifications_enabled', value);
    notifyListeners();
  }
  
  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _prefs.setBool('sound_enabled', value);
    notifyListeners();
  }
  
  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs.setBool('vibration_enabled', value);
    notifyListeners();
  }
  
  Future<void> setStealthMode(bool value) async {
    _stealthMode = value;
    await _prefs.setBool('stealth_mode', value);
    notifyListeners();
  }
  
  Future<void> setAutoDownloadMedia(bool value) async {
    _autoDownloadMedia = value;
    await _prefs.setBool('auto_download_media', value);
    notifyListeners();
  }
  
  Future<void> setMessageDeleteTimer(int seconds) async {
    _messageDeleteTimer = seconds;
    await _prefs.setInt('message_delete_timer', seconds);
    notifyListeners();
  }
  
  Future<void> clearAllSettings() async {
    await _prefs.clear();
    _loadSettings();
  }
}
