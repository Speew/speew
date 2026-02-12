import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// Network Helper
/// Simple utilities for checking network connectivity
class NetworkHelper {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has any network connection
  static Future<bool> hasConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return !_isDisconnected(result);
    } catch (e) {
      return false;
    }
  }

  /// Check if device has WiFi connection
  static Future<bool> hasWifi() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.wifi);
    } catch (e) {
      return false;
    }
  }

  /// Check if device has mobile data connection
  static Future<bool> hasMobileData() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.mobile);
    } catch (e) {
      return false;
    }
  }

  /// Listen to connectivity changes
  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Get connection type as string
  static Future<String> getConnectionType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (_isDisconnected(results)) return 'No Connection';
      if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
      if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
      if (results.contains(ConnectivityResult.mobile)) return 'Mobile Data';
      if (results.contains(ConnectivityResult.bluetooth)) return 'Bluetooth';
      return 'Unknown';
    } catch (e) {
      return 'Error';
    }
  }

  static bool _isDisconnected(List<ConnectivityResult> results) {
    return results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
  }
}
