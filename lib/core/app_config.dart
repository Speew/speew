import 'package:flutter/foundation.dart';

class AppConfig {
  // App Info
  static const String appName = 'Speew';
  static const String appVersion = '2.0.0';
  static const String appTagline = 'Mensagens P2P Offline';
  
  // Initialization
  static Future<void> load() async {
    // Future: Load user preferences, check for updates, etc.
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  // P2P Configuration
  static const String serviceId = 'com.speew.p2p';
  static const String strategy = 'P2P_CLUSTER';
  static const int maxPeers = 8;
  static const int connectionTimeout = 30; // seconds
  static const int discoveryDuration = 300; // seconds (5 min)
  
  // Crypto Configuration
  static const int keySize = 256; // bits
  static const int pbkdf2Iterations = 10000;
  static const String saltPrefix = 'speew-salt-v1-';
  
  // Storage Configuration
  static const String dbName = 'speew_mvp.db';
  static const int dbVersion = 1;
  static const int maxMessagesPerPeer = 1000;
  static const int messageCleanupDays = 30;
  
  // UI Configuration
  static const int maxMessageLength = 5000;
  static const int typingIndicatorTimeout = 3; // seconds
  static const bool enableAnimations = true;
  static const bool enableHapticFeedback = true;
  static const Duration splashDuration = Duration(seconds: 2);
  
  // Network Configuration
  static const int maxRetries = 3;
  static const int retryDelay = 2; // seconds
  static const int pingInterval = 30; // seconds
  static const int messageTimeout = 10; // seconds
  
  // Notification Configuration
  static const bool enableNotifications = true;
  static const bool enableSound = true;
  static const bool enableVibration = true;
  
  // Debug
  static bool get enableDebugLogs => kDebugMode;
  static const bool enablePerformanceMonitoring = false;
  
  // Feature Flags
  static const bool enableEncryption = true;
  static const bool enableMessageReceipts = true;
  static const bool enableTypingIndicator = false;
  static const bool enableFileSharing = false; // Future feature
}

class AppStrings {
  // Errors
  static const String errorGeneric = 'Ocorreu um erro. Tente novamente.';
  static const String errorConnection = 'Erro ao conectar. Verifique se Wi-Fi e Localização estão ativos.';
  static const String errorPermissions = 'Permissões necessárias não foram concedidas.';
  static const String errorSending = 'Erro ao enviar mensagem.';
  static const String errorStorage = 'Erro ao salvar dados.';
  static const String errorCrypto = 'Erro na criptografia.';
  
  // Success Messages
  static const String successConnected = 'Conectado com sucesso!';
  static const String successDisconnected = 'Desconectado.';
  static const String successMessageSent = 'Mensagem enviada.';
  static const String successChatCleared = 'Histórico limpo.';
  static const String successPeerRemoved = 'Peer removido.';
  
  // Info Messages
  static const String infoDiscovering = 'Procurando dispositivos próximos...';
  static const String infoConnecting = 'Conectando...';
  static const String infoNoMessages = 'Nenhuma mensagem ainda';
  static const String infoNoPeers = 'Nenhum dispositivo encontrado';
  static const String infoOffline = 'Offline';
  static const String infoOnline = 'Online';
  
  // Actions
  static const String actionConnect = 'Conectar';
  static const String actionDisconnect = 'Desconectar';
  static const String actionSend = 'Enviar';
  static const String actionCancel = 'Cancelar';
  static const String actionDelete = 'Deletar';
  static const String actionClear = 'Limpar';
  static const String actionRetry = 'Tentar Novamente';
  static const String actionSettings = 'Configurações';
  
  // Labels
  static const String labelYourName = 'Seu nome';
  static const String labelMessage = 'Mensagem';
  static const String labelTyping = 'digitando...';
  static const String labelLastSeen = 'Último contato';
  static const String labelConnected = 'Conectado';
  static const String labelDisconnected = 'Desconectado';
}

class AppTheme {
  // Colors
  static const primaryColor = 0xFF2196F3; // Blue
  static const primaryDarkColor = 0xFF1976D2;
  static const accentColor = 0xFF00BCD4;
  static const backgroundColor = 0xFFF5F5F5;
  static const surfaceColor = 0xFFFFFFFF;
  static const errorColor = 0xFFF44336;
  static const successColor = 0xFF4CAF50;
  static const warningColor = 0xFFFFC107;
  
  // Message Bubble Colors
  static const myMessageColor = 0xFF2196F3;
  static const peerMessageColor = 0xFFE0E0E0;
  static const myMessageTextColor = 0xFFFFFFFF;
  static const peerMessageTextColor = 0xFF000000;
  
  // Status Colors
  static const onlineColor = 0xFF4CAF50;
  static const offlineColor = 0xFF9E9E9E;
  static const connectingColor = 0xFFFFC107;
  
  // Sizes
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // Typography
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeXXLarge = 24.0;
}

class AppConstants {
  // Date Formats
  static const String dateFormatShort = 'HH:mm';
  static const String dateFormatMedium = 'dd/MM HH:mm';
  static const String dateFormatLong = 'dd/MM/yyyy HH:mm';
  
  // Message Types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeFile = 'file';
  static const String messageTypeSystem = 'system';
  
  // Connection Status
  static const String statusConnected = 'connected';
  static const String statusDisconnected = 'disconnected';
  static const String statusConnecting = 'connecting';
  
  // Message Status
  static const String statusPending = 'pending';
  static const String statusSent = 'sent';
  static const String statusDelivered = 'delivered';
  static const String statusRead = 'read';
  static const String statusFailed = 'failed';
}
