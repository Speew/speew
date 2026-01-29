import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/utils.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Inicializar serviço de notificações
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    DebugUtils.log('Notification service initialized', tag: 'NOTIF');
  }

  // Solicitar permissões (iOS)
  static Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return result ?? true;
  }

  // Mostrar notificação de mensagem
  static Future<void> showMessageNotification({
    required int id,
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Mensagens',
      channelDescription: 'Notificações de novas mensagens',
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

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
    );

    DebugUtils.log('Notification shown: $title', tag: 'NOTIF');
  }

  // Mostrar notificação de grupo
  static Future<void> showGroupNotification({
    required int id,
    required String groupName,
    required String senderName,
    required String message,
  }) async {
    await showMessageNotification(
      id: id,
      title: '$groupName',
      body: '$senderName: $message',
    );
  }

  // Mostrar notificação de nova conexão
  static Future<void> showConnectionNotification({
    required int id,
    required String peerName,
  }) async {
    await showMessageNotification(
      id: id,
      title: 'Nova Conexão',
      body: '$peerName conectou-se',
    );
  }

  // Cancelar notificação específica
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancelar todas as notificações
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Callback quando notificação é tocada
  static void _onNotificationTapped(NotificationResponse response) {
    DebugUtils.log('Notification tapped: ${response.payload}', tag: 'NOTIF');
    // TODO: Navegar para tela apropriada
  }

  // Gerar ID único para notificação
  static int generateNotificationId(String senderId) {
    return senderId.hashCode.abs() % 100000;
  }
}
