import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/chat_provider.dart';
import 'services/theme_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar notificações
  await NotificationService.initialize();
  
  runApp(const SpeewApp());
}

class SpeewApp extends StatelessWidget {
  const SpeewApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadThemePreference()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Speew MVP',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SetupScreen(),
          );
        },
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _enableMesh = false; // Toggle para mesh multi-hop
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();

    // Verificar se todas foram concedidas
    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    if (!allGranted) {
      setState(() {
        _errorMessage = 'Algumas permissões foram negadas.\n'
            'O app pode não funcionar corretamente.';
      });
      
      // Mostrar diálogo explicando
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissões Necessárias'),
        content: const Text(
          'O Speew precisa das seguintes permissões:\n\n'
          '• Bluetooth: Para conectar com outros dispositivos\n'
          '• Localização: Requerido pelo Android para Wi-Fi Direct\n'
          '• Wi-Fi: Para comunicação P2P\n\n'
          'Sem essas permissões, o app não funcionará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }

  Future<void> _initialize() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira seu nome';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Solicitar permissões
      await _requestPermissions();

      // Inicializar ChatProvider
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.initialize(name, enableMesh: _enableMesh);

      // Navegar para Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao inicializar: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              const Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),

              // Título
              const Text(
                'Speew MVP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Subtítulo
              const Text(
                'Mensagens P2P Offline',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              // Input de nome
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Seu nome',
                  hintText: 'Como você quer ser chamado?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _initialize(),
              ),
              const SizedBox(height: 24),

              // Toggle Mesh Multi-hop
              Card(
                child: SwitchListTile(
                  title: const Text('Mesh Multi-hop'),
                  subtitle: const Text(
                    'Permite mensagens através de múltiplos dispositivos intermediários',
                  ),
                  value: _enableMesh,
                  onChanged: (value) {
                    setState(() {
                      _enableMesh = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Botão iniciar
              ElevatedButton(
                onPressed: _isLoading ? null : _initialize,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Iniciar',
                        style: TextStyle(fontSize: 18),
                      ),
              ),

              // Mensagem de erro
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Info
              const Text(
                'Certifique-se de que:\n'
                '• Wi-Fi está ativo\n'
                '• Localização está ativa\n'
                '• Bluetooth está ativo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
