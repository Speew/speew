import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:typed_data';

// ----------------------------------------------------------------------------
// [SERVICE LAYER: GESTÃO DE HARDWARE COM FAIL-SAFE]
// ----------------------------------------------------------------------------
class MedicalMeshEngine extends ChangeNotifier {
  List<String> activeNodes = [];
  bool isHardwareInitialized = false;
  String? lastErrorMessage;
  
  final _storage = const FlutterSecureStorage();
  final _algo = AesGcm.with256bits();
  
  String? _nodeId;

  // Método de inicialização defensiva (Fail-Safe)
  Future<void> initializeSystem() async {
    if (isHardwareInitialized) return;
    
    try {
      // 1. Obter ID do nó (persistente)
      _nodeId = await _getPersistentNodeId();
      
      // 2. Validação de Pré-requisitos (Permissões de Grau Médico)
      bool permissionsGranted = await _requestStrictPermissions();
      if (!permissionsGranted) {
        _handleSystemFailure("Permissões de hardware negadas pelo S.O.");
        return;
      }

      // 3. Inicialização do Rádio com ID de Serviço Único
      const String protocolId = "com.speew.medical.v1";

      await Nearby().startAdvertising(
        _nodeId!, Strategy.P2P_CLUSTER,
        onConnectionInitiated: (id, info) => Nearby().acceptConnection(id, onPayLoadRecieved: (i, p) {}),
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            activeNodes.add(id);
            notifyListeners();
          }
        },
        onDisconnected: (id) {
          activeNodes.remove(id);
          notifyListeners();
        },
        serviceId: protocolId,
      );

      await Nearby().startDiscovery(
        _nodeId!, Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, sid) => Nearby().requestConnection(name, id, onConnectionInitiated: (i, n) {}),
        onEndpointLost: (id) {},
        serviceId: protocolId,
      );

      isHardwareInitialized = true;
      lastErrorMessage = null;
      notifyListeners();
      print("Protocolo MESH inicializado com sucesso. Node ID: $_nodeId");
    } catch (criticalError) {
      _handleSystemFailure("Falha crítica de barramento: $criticalError");
    }
  }
  
  Future<String> _getPersistentNodeId() async {
    String? id = await _storage.read(key: 'node_id');
    if (id == null) {
      id = "MD-Node-${DateTime.now().millisecondsSinceEpoch}";
      await _storage.write(key: 'node_id', value: id);
    }
    return id;
  }

  Future<bool> _requestStrictPermissions() async {
    // Permissões necessárias para Nearby Connections e Background
    Map<Permission, PermissionStatus> results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
    
    // Retorna true se TODAS as permissões críticas foram concedidas
    return results.values.every((status) => status.isGranted);
  }
  
  Future<void> shutdownSystem() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      activeNodes.clear();
      isHardwareInitialized = false;
      lastErrorMessage = null;
      notifyListeners();
      print("Protocolo MESH desativado.");
    } catch (e) {
      print("Erro ao desativar: $e");
    }
  }

  void _handleSystemFailure(String message) {
    isHardwareInitialized = false;
    lastErrorMessage = message;
    notifyListeners();
    print("ALERTA DE SISTEMA: $message");
    // TODO: Logar em arquivo local para auditoria posterior
  }
}

// ----------------------------------------------------------------------------
// [UI LAYER: DASHBOARD DE MONITORAMENTO]
// ----------------------------------------------------------------------------
class SpeewMonitor extends StatelessWidget {
  const SpeewMonitor({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MedicalMeshEngine>();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("SPEEW MEDICAL ALPHA", style: TextStyle(fontFamily: 'Monospace', color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          Icon(Icons.circle, color: engine.isHardwareInitialized ? Colors.greenAccent : Colors.redAccent),
          const SizedBox(width: 20),
        ],
      ),
      body: Column(
        children: [
          if (engine.lastErrorMessage != null)
            Container(
              color: Colors.red[900],
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              child: Text("ALERTA DE SISTEMA: ${engine.lastErrorMessage}", style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          Expanded(
            child: engine.activeNodes.isEmpty && engine.isHardwareInitialized
                ? _emptyState()
                : ListView.builder(
                    itemCount: engine.activeNodes.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.monitor_heart, color: Colors.blueAccent),
                      title: Text("NÓ ATIVO: ${engine.activeNodes[i]}", style: const TextStyle(color: Colors.white)),
                      trailing: const Text("LINK ESTÁVEL", style: TextStyle(color: Colors.green, fontSize: 10)),
                    ),
                  ),
          ),
          _buildControlPanel(engine),
        ],
      ),
    );
  }
  
  Widget _emptyState() => const Center(
    child: Text(
      "Aguardando nós ativos...",
      style: TextStyle(color: Colors.white54, fontSize: 16),
    ),
  );

  Widget _buildControlPanel(MedicalMeshEngine engine) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: engine.isHardwareInitialized ? Colors.redAccent : Colors.blueAccent,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: engine.isHardwareInitialized ? engine.shutdownSystem : engine.initializeSystem,
        child: Text(
          engine.isHardwareInitialized ? "DESATIVAR PROTOCOLO MESH" : "INICIALIZAR PROTOCOLO MESH",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

void main() => runApp(ChangeNotifierProvider(create: (_) => MedicalMeshEngine(), child: const MaterialApp(debugShowCheckedModeBanner: false, home: SpeewMonitor())));
