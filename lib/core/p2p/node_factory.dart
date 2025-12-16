import '../config/app_config.dart';
import '../utils/logger_service.dart';
import '../errors/exceptions.dart';
import '../crypto/crypto_manager.dart';

/// Factory para criação de nodes P2P
/// 
/// Implementa Factory Pattern para criar diferentes tipos de nodes
class NodeFactory {
  static final NodeFactory _instance = NodeFactory._internal();
  factory NodeFactory() => _instance;
  NodeFactory._internal();

  final CryptoManager _cryptoManager = CryptoManager();

  /// Cria um novo node P2P
  Future<P2PNode> createNode({
    required String userId,
    required String displayName,
    NodeType type = NodeType.standard,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Gerar par de chaves se necessário
      final keyPair = await _cryptoManager.generateKeyPair();
      
      final node = P2PNode(
        nodeId: _cryptoManager.generateUniqueId(),
        userId: userId,
        displayName: displayName,
        publicKey: keyPair['publicKey']!,
        type: type,
        createdAt: DateTime.now(),
        metadata: metadata ?? {},
      );

      logger.info('Node criado: ${node.displayName} (${node.nodeId})', tag: 'NodeFactory');
      return node;
    } catch (e) {
      logger.error('Falha ao criar node', tag: 'NodeFactory', error: e);
      throw P2PException.connectionFailed('Criação de node falhou', error: e);
    }
  }

  /// Cria um node fantasma (stealth)
  Future<P2PNode> createStealthNode({
    required String userId,
    Duration? lifetime,
  }) async {
    final displayName = 'Stealth-${_cryptoManager.generateToken(length: 8)}';
    final node = await createNode(
      userId: userId,
      displayName: displayName,
      type: NodeType.stealth,
      metadata: {
        'stealth': true,
        'lifetime': lifetime?.inSeconds ?? AppConfig.stealthModeRotationInterval.inSeconds,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    logger.info('Node stealth criado: ${node.nodeId}', tag: 'NodeFactory');
    return node;
  }

  /// Cria um node relay (intermediário)
  Future<P2PNode> createRelayNode({
    required String userId,
    required String displayName,
    int maxConnections = 100,
  }) async {
    final node = await createNode(
      userId: userId,
      displayName: displayName,
      type: NodeType.relay,
      metadata: {
        'relay': true,
        'maxConnections': maxConnections,
        'priority': 'high',
      },
    );

    logger.info('Node relay criado: ${node.displayName}', tag: 'NodeFactory');
    return node;
  }

  /// Cria um node a partir de dados serializados
  P2PNode fromJson(Map<String, dynamic> json) {
    try {
      return P2PNode(
        nodeId: json['nodeId'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        publicKey: json['publicKey'] as String,
        type: NodeType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => NodeType.standard,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      );
    } catch (e) {
      logger.error('Falha ao deserializar node', tag: 'NodeFactory', error: e);
      throw P2PException('Dados de node inválidos', code: 'INVALID_NODE_DATA');
    }
  }
}

/// Tipos de nodes P2P
enum NodeType {
  /// Node padrão (usuário comum)
  standard,
  
  /// Node relay (intermediário de alta capacidade)
  relay,
  
  /// Node stealth (identidade temporária)
  stealth,
  
  /// Node bootstrap (ponto de entrada na rede)
  bootstrap,
}

/// Representação de um node P2P
class P2PNode {
  final String nodeId;
  final String userId;
  final String displayName;
  final String publicKey;
  final NodeType type;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  // Estado do node
  DateTime lastSeen;
  bool isOnline;
  int connectionCount;
  double reputation;

  P2PNode({
    required this.nodeId,
    required this.userId,
    required this.displayName,
    required this.publicKey,
    required this.type,
    required this.createdAt,
    required this.metadata,
  })  : lastSeen = DateTime.now(),
        isOnline = true,
        connectionCount = 0,
        reputation = AppConfig.initialReputation;

  /// Verifica se o node está ativo
  bool get isActive {
    final inactiveThreshold = DateTime.now().subtract(AppConfig.heartbeatInterval * 3);
    return lastSeen.isAfter(inactiveThreshold);
  }

  /// Verifica se é um node stealth
  bool get isStealth => type == NodeType.stealth;

  /// Verifica se é um node relay
  bool get isRelay => type == NodeType.relay;

  /// Atualiza timestamp de última atividade
  void updateLastSeen() {
    lastSeen = DateTime.now();
    isOnline = true;
  }

  /// Marca node como offline
  void markOffline() {
    isOnline = false;
  }

  /// Incrementa contador de conexões
  void incrementConnections() {
    connectionCount++;
  }

  /// Decrementa contador de conexões
  void decrementConnections() {
    if (connectionCount > 0) connectionCount--;
  }

  /// Atualiza reputação
  void updateReputation(double delta) {
    reputation = (reputation + delta).clamp(
      AppConfig.minReputation,
      AppConfig.maxReputation,
    );
  }

  /// Serializa para JSON
  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'userId': userId,
      'displayName': displayName,
      'publicKey': publicKey,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'isOnline': isOnline,
      'connectionCount': connectionCount,
      'reputation': reputation,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'P2PNode(id: $nodeId, name: $displayName, type: ${type.name}, online: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is P2PNode && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;
}

/// Factory para criação de conexões P2P
class ConnectionFactory {
  static final ConnectionFactory _instance = ConnectionFactory._internal();
  factory ConnectionFactory() => _instance;
  ConnectionFactory._internal();

  final CryptoManager _cryptoManager = CryptoManager();

  /// Cria uma nova conexão entre dois nodes
  P2PConnection createConnection({
    required P2PNode localNode,
    required P2PNode remoteNode,
    ConnectionType type = ConnectionType.direct,
  }) {
    try {
      final connection = P2PConnection(
        connectionId: _cryptoManager.generateUniqueId(),
        localNodeId: localNode.nodeId,
        remoteNodeId: remoteNode.nodeId,
        type: type,
        establishedAt: DateTime.now(),
      );

      logger.info(
        'Conexão criada: ${localNode.displayName} <-> ${remoteNode.displayName}',
        tag: 'ConnectionFactory',
      );

      return connection;
    } catch (e) {
      logger.error('Falha ao criar conexão', tag: 'ConnectionFactory', error: e);
      throw P2PException.connectionFailed('Criação de conexão falhou', error: e);
    }
  }

  /// Cria conexão a partir de JSON
  P2PConnection fromJson(Map<String, dynamic> json) {
    return P2PConnection(
      connectionId: json['connectionId'] as String,
      localNodeId: json['localNodeId'] as String,
      remoteNodeId: json['remoteNodeId'] as String,
      type: ConnectionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ConnectionType.direct,
      ),
      establishedAt: DateTime.parse(json['establishedAt'] as String),
    );
  }
}

/// Tipos de conexão P2P
enum ConnectionType {
  /// Conexão direta (Wi-Fi Direct, Bluetooth)
  direct,
  
  /// Conexão via relay
  relayed,
  
  /// Conexão mesh (multi-hop)
  mesh,
}

/// Representação de uma conexão P2P
class P2PConnection {
  final String connectionId;
  final String localNodeId;
  final String remoteNodeId;
  final ConnectionType type;
  final DateTime establishedAt;

  // Estado da conexão
  DateTime lastActivity;
  bool isActive;
  int bytesSent;
  int bytesReceived;
  int latencyMs;

  P2PConnection({
    required this.connectionId,
    required this.localNodeId,
    required this.remoteNodeId,
    required this.type,
    required this.establishedAt,
  })  : lastActivity = DateTime.now(),
        isActive = true,
        bytesSent = 0,
        bytesReceived = 0,
        latencyMs = 0;

  /// Atualiza atividade da conexão
  void updateActivity() {
    lastActivity = DateTime.now();
  }

  /// Registra dados enviados
  void recordSent(int bytes) {
    bytesSent += bytes;
    updateActivity();
  }

  /// Registra dados recebidos
  void recordReceived(int bytes) {
    bytesReceived += bytes;
    updateActivity();
  }

  /// Atualiza latência
  void updateLatency(int ms) {
    latencyMs = ms;
  }

  /// Marca conexão como inativa
  void markInactive() {
    isActive = false;
  }

  /// Verifica se conexão está saudável
  bool get isHealthy {
    final timeout = DateTime.now().subtract(AppConfig.connectionTimeout);
    return isActive && lastActivity.isAfter(timeout);
  }

  /// Serializa para JSON
  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'localNodeId': localNodeId,
      'remoteNodeId': remoteNodeId,
      'type': type.name,
      'establishedAt': establishedAt.toIso8601String(),
      'lastActivity': lastActivity.toIso8601String(),
      'isActive': isActive,
      'bytesSent': bytesSent,
      'bytesReceived': bytesReceived,
      'latencyMs': latencyMs,
    };
  }

  @override
  String toString() {
    return 'P2PConnection(id: $connectionId, type: ${type.name}, active: $isActive, latency: ${latencyMs}ms)';
  }
}
