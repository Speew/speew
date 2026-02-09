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
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Check if device has WiFi connection
  static Future<bool> hasWifi() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.wifi;
    } catch (e) {
      return false;
    }
  }

  /// Check if device has mobile data connection
  static Future<bool> hasMobileData() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.mobile;
    } catch (e) {
      return false;
    }
  }

  /// Listen to connectivity changes
  static Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Get connection type as string
  static Future<String> getConnectionType() async {
    try {
      final result = await _connectivity.checkConnectivity();
      switch (result) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'Mobile Data';
        case ConnectivityResult.ethernet:
          return 'Ethernet';
        case ConnectivityResult.bluetooth:
          return 'Bluetooth';
        case ConnectivityResult.none:
          return 'No Connection';
        default:
          return 'Unknown';
      }
    } catch (e) {
      return 'Error';
    }
  }
}
