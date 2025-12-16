import '../../core/errors/exceptions.dart';
import '../../core/utils/logger_service.dart';
import '../config/app_config.dart';
import '../errors/exceptions.dart';
import '../utils/logger_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Serviço de rede P2P para descoberta e conexão de dispositivos
/// Implementa Wi-Fi Direct e Bluetooth Mesh para comunicação offline
class P2PService extends ChangeNotifier {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  /// Lista de peers conectados
  final List<Peer> _connectedPeers = [];
  List<Peer> get connectedPeers => List.unmodifiable(_connectedPeers);

  /// Lista de peers descobertos mas não conectados
  final List<Peer> _discoveredPeers = [];
  List<Peer> get discoveredPeers => List.unmodifiable(_discoveredPeers);

  /// Status do servidor P2P
  bool _isServerRunning = false;
  bool get isServerRunning => _isServerRunning;

  /// Status da descoberta de peers
  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  /// Stream de mensagens recebidas
  final StreamController<P2PMessage> _messageStreamController = StreamController<P2PMessage>.broadcast();
  Stream<P2PMessage> get messageStream => _messageStreamController.stream;

  // ==================== INICIALIZAÇÃO ====================

  /// Inicializa o serviço P2P
  Future<void> initialize() async {
    try {
      // Em produção, inicializar plugins de Wi-Fi Direct e Bluetooth
      // nearby_connections para Wi-Fi Direct
      // flutter_blue_plus para Bluetooth Mesh
      
      logger.info('Serviço inicializado', tag: 'P2P');
    } catch (e) {
      logger.error('Erro ao inicializar', tag: 'P2P', error: e);
      throw P2PException.connectionFailed('Inicialização falhou', error: e);
    }
  }

  // ==================== SERVIDOR P2P ====================

  /// Inicia o servidor P2P (torna o dispositivo visível)
  Future<void> startServer(String userId, String displayName) async {
    if (_isServerRunning) {
      logger.warn('Servidor já está rodando', tag: 'P2P');
      return;
    }

    try {
      // Em produção:
      // 1. Iniciar Wi-Fi Direct como Group Owner
      // 2. Iniciar Bluetooth advertising
      // 3. Configurar listeners para conexões entrantes
      
      _isServerRunning = true;
      notifyListeners();
      
      logger.info('Servidor iniciado: $displayName ($userId)', tag: 'P2P');
    } catch (e) {
      logger.error('Erro ao iniciar servidor', tag: 'P2P', error: e);
      throw P2PException.connectionFailed('Falha ao iniciar servidor', error: e);
    }
  }

  /// Para o servidor P2P
  Future<void> stopServer() async {
    if (!_isServerRunning) return;

    try {
      // Em produção:
      // 1. Parar Wi-Fi Direct
      // 2. Parar Bluetooth advertising
      // 3. Desconectar todos os peers
      
      _isServerRunning = false;
      _connectedPeers.clear();
      notifyListeners();
      
      logger.info('Servidor parado', tag: 'P2P');
    } catch (e) {
      logger.error('Erro ao parar servidor', tag: 'P2P', error: e);
    }
  }

  // ==================== DESCOBERTA DE PEERS ====================

  /// Inicia a descoberta de dispositivos próximos
  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      logger.warn('Descoberta já está ativa', tag: 'P2P');
      return;
    }

    try {
      // Em produção:
      // 1. Iniciar Wi-Fi Direct discovery
      // 2. Iniciar Bluetooth scanning
      // 3. Processar peers descobertos
      
      _isDiscovering = true;
      _discoveredPeers.clear();
      notifyListeners();
      
      // Simulação de descoberta (remover em produção)
      _simulateDiscovery();
      
      logger.info('Descoberta iniciada', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao iniciar descoberta: $e', tag: 'P2P');
      throw Exception('Falha ao iniciar descoberta: $e');
    }
  }

  /// Para a descoberta de dispositivos
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;

    try {
      // Em produção:
      // 1. Parar Wi-Fi Direct discovery
      // 2. Parar Bluetooth scanning
      
      _isDiscovering = false;
      notifyListeners();
      
      logger.info('Descoberta parada', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao parar descoberta: $e', tag: 'P2P');
    }
  }

  /// Simulação de descoberta de peers (apenas para desenvolvimento)
  void _simulateDiscovery() {
    // Esta função será removida na versão de produção
    // Aqui apenas para demonstrar a estrutura
    Future.delayed(const Duration(seconds: 2), () {
      if (_isDiscovering) {
        final mockPeer = Peer(
          peerId: 'mock-peer-${DateTime.now().millisecondsSinceEpoch}',
          displayName: 'Dispositivo Simulado',
          publicKey: 'mock-public-key',
          connectionType: 'wifi-direct',
          signalStrength: -60,
        );
        _discoveredPeers.add(mockPeer);
        notifyListeners();
      }
    });
  }

  // ==================== CONEXÃO COM PEERS ====================

  /// Conecta a um peer descoberto
  Future<bool> connectToPeer(Peer peer) async {
    try {
      // Em produção:
      // 1. Estabelecer conexão Wi-Fi Direct ou Bluetooth
      // 2. Realizar handshake Noise Protocol
      // 3. Trocar chaves de sessão
      // 4. Adicionar à lista de peers conectados
      
      if (!_connectedPeers.any((p) => p.peerId == peer.peerId)) {
        _connectedPeers.add(peer);
        _discoveredPeers.removeWhere((p) => p.peerId == peer.peerId);
        notifyListeners();
      }
      
      logger.info('Conectado ao peer: ${peer.displayName}', tag: 'P2P');
      return true;
    } catch (e) {
      logger.info('Erro ao conectar ao peer: $e', tag: 'P2P');
      return false;
    }
  }

  /// Desconecta de um peer
  Future<void> disconnectFromPeer(String peerId) async {
    try {
      // Em produção:
      // 1. Fechar conexão Wi-Fi Direct ou Bluetooth
      // 2. Limpar chaves de sessão
      
      _connectedPeers.removeWhere((p) => p.peerId == peerId);
      notifyListeners();
      
      logger.info('Desconectado do peer: $peerId', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao desconectar do peer: $e', tag: 'P2P');
    }
  }

  // ==================== ENVIO E RECEPÇÃO DE MENSAGENS ====================

  /// Envia uma mensagem para um peer específico
  Future<bool> sendMessage(String peerId, P2PMessage message) async {
    try {
      // Em produção:
      // 1. Serializar mensagem
      // 2. Criptografar com chave de sessão
      // 3. Enviar via Wi-Fi Direct ou Bluetooth
      // 4. Aguardar confirmação de recebimento
      
      final peer = _connectedPeers.firstWhere(
        (p) => p.peerId == peerId,
        orElse: () => throw Exception('Peer não conectado'),
      );
      
      logger.info('Mensagem enviada para ${peer.displayName}: ${message.type}', tag: 'P2P');
      return true;
    } catch (e) {
      logger.info('Erro ao enviar mensagem: $e', tag: 'P2P');
      return false;
    }
  }

  /// Envia uma mensagem broadcast para todos os peers conectados
  Future<void> broadcastMessage(P2PMessage message) async {
    for (final peer in _connectedPeers) {
      await sendMessage(peer.peerId, message);
    }
  }

  /// Processa mensagem recebida de um peer
  void _onMessageReceived(String peerId, Map<String, dynamic> data) {
    try {
      // Em produção:
      // 1. Descriptografar mensagem
      // 2. Validar assinatura
      // 3. Processar conteúdo
      
      final message = P2PMessage.fromMap(data);
      _messageStreamController.add(message);
      
      logger.info('Mensagem recebida de $peerId: ${message.type}', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao processar mensagem recebida: $e', tag: 'P2P');
    }
  }

  // ==================== MESH NETWORKING ====================

  /// Propaga uma mensagem através da rede mesh (store-and-forward)
  Future<void> propagateMessage(P2PMessage message, {String? excludePeerId}) async {
    try {
      // Em produção:
      // 1. Verificar se a mensagem já foi propagada (evitar loops)
      // 2. Incrementar hop count
      // 3. Enviar para todos os peers exceto o originador
      // 4. Armazenar para forward posterior se destinatário offline
      
      for (final peer in _connectedPeers) {
        if (peer.peerId != excludePeerId) {
          await sendMessage(peer.peerId, message);
        }
      }
      
      logger.info('Mensagem propagada na mesh: ${message.messageId}', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao propagar mensagem: $e', tag: 'P2P');
    }
  }

  // ==================== LIMPEZA ====================

  /// Libera recursos do serviço
  @override
  void dispose() {
    stopServer();
    stopDiscovery();
    _messageStreamController.close();
    super.dispose();
  }
}

// ==================== CLASSES AUXILIARES ====================

/// Representa um peer (dispositivo) na rede P2P
class Peer {
  final String peerId;
  final String displayName;
  final String publicKey;
  final String connectionType; // 'wifi-direct' ou 'bluetooth'
  final int signalStrength; // em dBm
  final DateTime discoveredAt;

  Peer({
    required this.peerId,
    required this.displayName,
    required this.publicKey,
    required this.connectionType,
    required this.signalStrength,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'peerId': peerId,
      'displayName': displayName,
      'publicKey': publicKey,
      'connectionType': connectionType,
      'signalStrength': signalStrength,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }

  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      peerId: map['peerId'] as String,
      displayName: map['displayName'] as String,
      publicKey: map['publicKey'] as String,
      connectionType: map['connectionType'] as String,
      signalStrength: map['signalStrength'] as int,
      discoveredAt: DateTime.parse(map['discoveredAt'] as String),
    );
  }
}

/// Representa uma mensagem P2P
class P2PMessage {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String type; // 'text', 'file', 'transaction', 'control'
  final Map<String, dynamic> payload;
  final int hopCount;
  final DateTime timestamp;

  P2PMessage({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.payload,
    this.hopCount = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'type': type,
      'payload': payload,
      'hopCount': hopCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory P2PMessage.fromMap(Map<String, dynamic> map) {
    return P2PMessage(
      messageId: map['messageId'] as String,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      type: map['type'] as String,
      payload: map['payload'] as Map<String, dynamic>,
      hopCount: map['hopCount'] as int? ?? 0,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  /// Cria uma cópia da mensagem com hop count incrementado
  P2PMessage incrementHop() {
    return P2PMessage(
      messageId: messageId,
      senderId: senderId,
      receiverId: receiverId,
      type: type,
      payload: payload,
      hopCount: hopCount + 1,
      timestamp: timestamp,
    );
  }
}
