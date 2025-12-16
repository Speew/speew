import 'core/config/app_config.dart';
import 'core/power/energy_manager.dart';
import 'core/background/background_service.dart';
import 'core/storage/mesh/mesh_state_storage.dart';
import 'core/mesh/deep_background_relay_service.dart';
import 'core/power/low_battery_emergency_engine.dart';
import 'core/crypto/crypto_service.dart';
import 'core/models/user.dart';
import 'core/p2p/p2p_service.dart';
import 'core/reputation/reputation_service.dart';
import 'core/storage/database_service.dart';
import 'core/utils/logger_service.dart';
import 'core/wallet/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/energy_settings_screen.dart'; // Importação da nova tela

/// Ponto de entrada do aplicativo
/// Inicializa todos os serviços e configura o tema
late final AppServices _appServices;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar serviços
  _appServices = await _initializeServices();
  
  runApp(RedeP2PApp(services: _appServices));
}

/// Classe para agrupar todos os serviços inicializados
class AppServices {
  final P2PService p2pService;
  final WalletService walletService;
  final ReputationService reputationService;
  final EnergyManager energyManager;
  final BackgroundService backgroundService;
  final MeshStateStorage meshStateStorage;
  final DeepBackgroundRelayService deepBackgroundRelayService;
  final LowBatteryEmergencyEngine lowBatteryEmergencyEngine;

  AppServices({
    required this.p2pService,
    required this.walletService,
    required this.reputationService,
    required this.energyManager,
    required this.backgroundService,
    required this.meshStateStorage,
    required this.deepBackgroundRelayService,
    required this.lowBatteryEmergencyEngine,
  });
}

/// Inicializa todos os serviços necessários
Future<AppServices> _initializeServices() async {
  try {
    // Inicializar banco de dados
    final db = DatabaseService();
    await db.database;
    
    // Inicializar serviços de Core
    final energyManager = EnergyManager();
    final backgroundService = BackgroundService(energyManager);
    final meshStateStorage = MeshStateStorage();
    final deepBackgroundRelayService = DeepBackgroundRelayService(energyManager);
    final lowBatteryEmergencyEngine = LowBatteryEmergencyEngine(energyManager);

    // Inicializar serviços de Feature
    final p2pService = P2PService();
    await p2pService.initialize();
    final walletService = WalletService();
    final reputationService = ReputationService();
    
    // Carregar estado da mesh (Persistência do Estado da Mesh)
    final meshState = await meshStateStorage.loadState();
    // p2pService.restoreState(meshState); // Simulação de restauração

    // Observar mudanças de perfil de energia para aplicar otimizações
    energyManager.currentProfile.listen((profile) {
      deepBackgroundRelayService.handleEnergyProfileChange(profile);
      lowBatteryEmergencyEngine.handleEnergyProfileChange(profile);
    });

    logger.info('Serviços inicializados com sucesso', tag: 'App');

    return AppServices(
      p2pService: p2pService,
      walletService: walletService,
      reputationService: reputationService,
      energyManager: energyManager,
      backgroundService: backgroundService,
      meshStateStorage: meshStateStorage,
      deepBackgroundRelayService: deepBackgroundRelayService,
      lowBatteryEmergencyEngine: lowBatteryEmergencyEngine,
    );
  } catch (e) {
    logger.error('Erro ao inicializar serviços', tag: 'App', error: e);
    rethrow;
  }
}

/// Widget principal do aplicativo
class RedeP2PApp extends StatefulWidget {
  final AppServices services;
  const RedeP2PApp({Key? key, required this.services}) : super(key: key);

  @override
  State<RedeP2PApp> createState() => _RedeP2PAppState();
}

class _RedeP2PAppState extends State<RedeP2PApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Gerenciamento do ciclo de vida do app (Background Mode)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final backgroundService = widget.services.backgroundService;

    if (state == AppLifecycleState.paused) {
      // App indo para o background
      backgroundService.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      // App voltando para o foreground
      backgroundService.onAppForegrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.services.p2pService),
        ChangeNotifierProvider.value(value: widget.services.walletService),
        ChangeNotifierProvider.value(value: widget.services.reputationService),
        // Novos serviços
        Provider.value(value: widget.services.energyManager),
        Provider.value(value: widget.services.backgroundService),
        Provider.value(value: widget.services.meshStateStorage),
        Provider.value(value: widget.services.deepBackgroundRelayService),
        Provider.value(value: widget.services.lowBatteryEmergencyEngine),
      ],
      child: MaterialApp(
        title: 'Speew',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: const InitializationScreen(),
      ),
    );
  }
}

/// Tela de inicialização
/// Cria ou carrega o usuário e navega para a tela principal
// A tela de inicialização não precisa mais inicializar os serviços, apenas o usuário.
// O restante do código da InitializationScreen pode permanecer o mesmo, mas a lógica de inicialização de serviços foi movida.
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({Key? key}) : super(key: key);

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  /// Inicializa ou cria o usuário
  Future<void> _initializeUser() async {
    try {
      // Verificar se já existe um usuário
      final users = await _db.getAllUsers();
      
      User currentUser;
      
      if (users.isEmpty) {
        // Criar novo usuário
        currentUser = await _createNewUser();
      } else {
        // Usar o primeiro usuário encontrado
        currentUser = users.first;
      }
      
      // Navegar para a tela principal
      if (mounted) {
        // Salvar o estado inicial da mesh ao criar o usuário
        final meshStateStorage = _appServices.meshStateStorage;
        await meshStateStorage.saveState(MeshState.empty()); // Salva um estado inicial

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userId: currentUser.userId,
              displayName: currentUser.displayName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao inicializar: $e';
        _isLoading = false;
      });
    }
  }

  /// Cria um novo usuário
  Future<User> _createNewUser() async {
    // Gerar par de chaves
    final keyPair = await _crypto.generateKeyPair();
    
    // Criar usuário
    final user = User(
      userId: _crypto.generateUniqueId(),
      publicKey: keyPair['publicKey']!,
      displayName: 'Usuário ${DateTime.now().millisecondsSinceEpoch % 10000}',
      reputationScore: 0.5, // Reputação neutra inicial
      lastSeen: DateTime.now(),
    );
    
    // Salvar no banco de dados
    await _db.insertUser(user);
    
    logger.info('Novo usuário criado: ${user.displayName}', tag: 'App');
    return user;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'Inicializando Rede P2P...',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configurando criptografia e banco de dados',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Erro na Inicialização',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error ?? 'Erro desconhecido',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _initializeUser();
                    },
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
      ),
    );
  }
}
