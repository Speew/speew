import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  Function(String)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings, onDidReceiveNotificationResponse: _onNotificationTapped);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    final result = await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return result ?? true;
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showGroupNotification({
    required String groupName,
    required String senderName,
    required String message,
    String? payload,
  }) async {
    await showMessageNotification(
      title: groupName,
      body: '$senderName: $message',
      payload: payload,
    );
  }

  Future<void> showConnectionNotification({
    required String peerName,
    String? payload,
  }) async {
    await showMessageNotification(
      title: 'New Connection',
      body: '$peerName connected',
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      onNotificationTap?.call(response.payload!);
    }
  }
}