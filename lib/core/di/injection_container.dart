import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/p2p_service.dart';
import '../../services/crypto_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/voice_call_service.dart';
import '../../services/file_transfer_service.dart';
import '../../services/mesh_routing_service.dart';
import '../../services/group_service.dart';

final getIt = GetIt.instance;

class InjectionContainer {
  static Future<void> init() async {
    // External dependencies
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(sharedPreferences);
    
    // Core Services
    getIt.registerLazySingleton<StorageService>(
      () => StorageService(),
    );
    
    getIt.registerLazySingleton<CryptoService>(
      () => CryptoService(),
    );
    
    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );
    
    // Network Services
    getIt.registerLazySingleton<P2PService>(
      () => P2PService(
        cryptoService: getIt(),
        storageService: getIt(),
      ),
    );
    
    getIt.registerLazySingleton<MeshRoutingService>(
      () => MeshRoutingService(
        p2pService: getIt(),
      ),
    );
    
    getIt.registerLazySingleton<FileTransferService>(
      () => FileTransferService(
        p2pService: getIt(),
        cryptoService: getIt(),
      ),
    );
    
    getIt.registerLazySingleton<VoiceCallService>(
      () => VoiceCallService(
        p2pService: getIt(),
      ),
    );
    
    getIt.registerLazySingleton<GroupService>(
      () => GroupService(
        p2pService: getIt(),
        cryptoService: getIt(),
        storageService: getIt(),
      ),
    );
    
    // Providers
    getIt.registerFactory<ThemeProvider>(
      () => ThemeProvider(
        sharedPreferences: getIt(),
      ),
    );
    
    getIt.registerFactory<ConnectionProvider>(
      () => ConnectionProvider(
        p2pService: getIt(),
        meshService: getIt(),
      ),
    );
    
    getIt.registerFactory<SettingsProvider>(
      () => SettingsProvider(
        sharedPreferences: getIt(),
      ),
    );
    
    getIt.registerFactory<ChatProvider>(
      () => ChatProvider(
        p2pService: getIt(),
        cryptoService: getIt(),
        storageService: getIt(),
        notificationService: getIt(),
        fileTransferService: getIt(),
      ),
    );
    
    await getIt.allReady();
  }

  static void reset() {
    getIt.reset();
  }
}
