class AppConstants {
  // App
  static const String appName = 'Speew';
  static const String appTagline = 'Secure P2P Messaging';
  
  // Storage Keys
  static const String keyFirstLaunch = 'first_launch';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserAvatar = 'user_avatar';
  static const String keyUserStatus = 'user_status';
  static const String keyDarkMode = 'dark_mode';
  static const String keyNotifications = 'notifications';
  static const String keySound = 'sound';
  static const String keyVibration = 'vibration';
  static const String keyStealthMode = 'stealth_mode';
  
  // Message Types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeVideo = 'video';
  static const String messageTypeAudio = 'audio';
  static const String messageTypeFile = 'file';
  static const String messageTypeLocation = 'location';
  static const String messageTypeContact = 'contact';
  
  // Connection Status
  static const String statusOnline = 'online';
  static const String statusOffline = 'offline';
  static const String statusConnecting = 'connecting';
  static const String statusAway = 'away';
  
  // Message Status
  static const String statusSent = 'sent';
  static const String statusDelivered = 'delivered';
  static const String statusRead = 'read';
  static const String statusFailed = 'failed';
  static const String statusPending = 'pending';
  
  // Animations
  static const int animationDuration = 300;
  static const int shortAnimationDuration = 150;
  static const int longAnimationDuration = 500;
  
  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  
  // Limits
  static const int maxMessageLength = 5000;
  static const int maxUsernameLength = 50;
  static const int maxStatusLength = 150;
  static const int maxGroupNameLength = 50;
  static const int maxGroupMembers = 50;
  
  // Time
  static const int messageRefreshInterval = 1000; // 1 second
  static const int typingIndicatorTimeout = 5000; // 5 seconds
  static const int onlineStatusTimeout = 30000; // 30 seconds
  
  // Assets
  static const String assetLogoPath = 'assets/icons/app_icon.png';
  static const String assetEmptyStatePath = 'assets/images/empty_state.png';
  static const String assetNoConnectionPath = 'assets/images/no_connection.png';
  
  // Permissions
  static const String permissionCamera = 'camera';
  static const String permissionStorage = 'storage';
  static const String permissionLocation = 'location';
  static const String permissionMicrophone = 'microphone';
  static const String permissionNotifications = 'notifications';
  static const String permissionBluetooth = 'bluetooth';
  static const String permissionNearbyDevices = 'nearby_devices';
  
  // Error Messages
  static const String errorGeneric = 'An error occurred. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorPermission = 'Permission denied. Please enable required permissions.';
  static const String errorStorage = 'Storage error. Please check available space.';
  static const String errorEncryption = 'Encryption error. Message could not be secured.';
  static const String errorFileSize = 'File too large. Maximum size is ';
  static const String errorFileType = 'File type not supported.';
  static const String errorNoConnection = 'No active connections. Please wait for peers.';
  
  // Success Messages
  static const String successMessageSent = 'Message sent successfully';
  static const String successFileSent = 'File sent successfully';
  static const String successGroupCreated = 'Group created successfully';
  static const String successSettingsSaved = 'Settings saved successfully';
  
  // Info Messages
  static const String infoConnecting = 'Connecting to network...';
  static const String infoSearchingPeers = 'Searching for nearby devices...';
  static const String infoSendingFile = 'Sending file...';
  static const String infoReceivingFile = 'Receiving file...';
  static const String infoEncryptingMessage = 'Encrypting message...';
}
