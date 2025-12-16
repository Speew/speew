import '../../core/utils/logger_service.dart';
import '../../models/private_network.dart';
import '../../models/user.dart';
import '../crypto/crypto_service.dart';
import '../storage/database_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// ==================== NOVO MÓDULO: REDES PRIVADAS ====================
/// Serviço de gerenciamento de redes privadas com chave de acesso
/// 
/// Funcionalidades:
/// - Criar "salas privadas"
/// - Autenticação por senha, QR Code ou NFC
/// - Controle de acesso baseado em chave
/// - Gerenciamento de participantes
///
/// ADICIONADO: Fase 7 - Redes Privadas
class PrivateNetworkService extends ChangeNotifier {
  static final PrivateNetworkService _instance = PrivateNetworkService._internal();
  factory PrivateNetworkService() => _instance;
  PrivateNetworkService._internal();

  final CryptoService _crypto = CryptoService();
  final DatabaseService _db = DatabaseService();

  /// Redes privadas ativas
  final Map<String, PrivateNetwork> _activeNetworks = {};

  /// Participantes por rede
  final Map<String, List<NetworkParticipant>> _networkParticipants = {};

  /// Rede atual do usuário
  String? _currentNetworkId;
  String? get currentNetworkId => _currentNetworkId;

  // ==================== CRIAÇÃO DE REDES ====================

  /// Cria uma nova rede privada
  Future<PrivateNetwork> createPrivateNetwork({
    required String name,
    required String description,
    required String creatorId,
    required String accessKey,
    int maxParticipants = 0,
    String authType = 'password',
  }) async {
    try {
      // Gera ID da rede
      final networkId = _crypto.generateUniqueId();

      // Hash da chave de acesso
      final accessKeyHash = _crypto.sha256Hash(accessKey);

      // Gera QR Code data se necessário
      String? qrCodeData;
      if (authType == 'qr_code') {
        qrCodeData = _generateQRCodeData(networkId, accessKey);
      }

      // Cria rede
      final network = PrivateNetwork(
        networkId: networkId,
        name: name,
        description: description,
        creatorId: creatorId,
        accessKeyHash: accessKeyHash,
        createdAt: DateTime.now(),
        maxParticipants: maxParticipants,
        authType: authType,
        qrCodeData: qrCodeData,
      );

      // Salva no banco
      await _db.insertPrivateNetwork(network);

      // Adiciona criador como admin
      final creator = NetworkParticipant(
        userId: creatorId,
        networkId: networkId,
        joinedAt: DateTime.now(),
        role: 'admin',
      );
      await _db.insertNetworkParticipant(creator);

      // Atualiza cache
      _activeNetworks[networkId] = network;
      _networkParticipants[networkId] = [creator];

      logger.info('Rede criada: $name ($networkId)', tag: 'PrivateNetwork');
      notifyListeners();

      return network;
    } catch (e) {
      logger.info('Erro ao criar rede: $e', tag: 'PrivateNetwork');
      rethrow;
    }
  }

  /// Gera dados para QR Code
  String _generateQRCodeData(String networkId, String accessKey) {
    final data = {
      'type': 'private_network',
      'network_id': networkId,
      'access_key': accessKey,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return base64Encode(utf8.encode(jsonEncode(data)));
  }

  /// Parseia dados de QR Code
  Map<String, dynamic>? parseQRCodeData(String qrCodeData) {
    try {
      final decoded = utf8.decode(base64Decode(qrCodeData));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      logger.info('Erro ao parsear QR Code: $e', tag: 'PrivateNetwork');
      return null;
    }
  }

  // ==================== AUTENTICAÇÃO E ENTRADA ====================

  /// Tenta entrar em uma rede privada
  Future<bool> joinPrivateNetwork({
    required String networkId,
    required String userId,
    required String accessKey,
  }) async {
    try {
      // Obtém a rede
      final network = await _db.getPrivateNetwork(networkId);
      if (network == null) {
        logger.info('Rede não encontrada: $networkId', tag: 'PrivateNetwork');
        return false;
      }

      // Verifica se a rede está ativa
      if (!network.isActive) {
        logger.info('Rede não está ativa', tag: 'PrivateNetwork');
        return false;
      }

      // Valida chave de acesso
      final accessKeyHash = _crypto.sha256Hash(accessKey);
      if (accessKeyHash != network.accessKeyHash) {
        logger.info('Chave de acesso inválida', tag: 'PrivateNetwork');
        return false;
      }

      // Verifica limite de participantes
      if (network.hasParticipantLimit) {
        final participants = await _db.getNetworkParticipants(networkId);
        if (participants.length >= network.maxParticipants) {
          logger.info('Rede está cheia', tag: 'PrivateNetwork');
          return false;
        }
      }

      // Verifica se já é participante
      final existingParticipant = await _db.getNetworkParticipant(networkId, userId);
      if (existingParticipant != null) {
        if (existingParticipant.status == 'banned') {
          logger.info('Usuário banido desta rede', tag: 'PrivateNetwork');
          return false;
        }
        if (existingParticipant.isActive) {
          logger.info('Usuário já é participante', tag: 'PrivateNetwork');
          _currentNetworkId = networkId;
          return true;
        }
      }

      // Adiciona como participante
      final participant = NetworkParticipant(
        userId: userId,
        networkId: networkId,
        joinedAt: DateTime.now(),
      );
      await _db.insertNetworkParticipant(participant);

      // Atualiza cache
      _activeNetworks[networkId] = network;
      if (!_networkParticipants.containsKey(networkId)) {
        _networkParticipants[networkId] = [];
      }
      _networkParticipants[networkId]!.add(participant);

      _currentNetworkId = networkId;

      logger.info('Usuário $userId entrou na rede $networkId', tag: 'PrivateNetwork');
      notifyListeners();

      return true;
    } catch (e) {
      logger.info('Erro ao entrar na rede: $e', tag: 'PrivateNetwork');
      return false;
    }
  }

  /// Entra em rede via QR Code
  Future<bool> joinViaQRCode({
    required String userId,
    required String qrCodeData,
  }) async {
    try {
      final data = parseQRCodeData(qrCodeData);
      if (data == null) return false;

      final networkId = data['network_id'] as String;
      final accessKey = data['access_key'] as String;

      return await joinPrivateNetwork(
        networkId: networkId,
        userId: userId,
        accessKey: accessKey,
      );
    } catch (e) {
      logger.info('Erro ao entrar via QR Code: $e', tag: 'PrivateNetwork');
      return false;
    }
  }

  /// Sai de uma rede privada
  Future<void> leavePrivateNetwork(String networkId, String userId) async {
    try {
      await _db.updateNetworkParticipantStatus(networkId, userId, 'left');

      // Atualiza cache
      _networkParticipants[networkId]?.removeWhere((p) => p.userId == userId);

      if (_currentNetworkId == networkId) {
        _currentNetworkId = null;
      }

      logger.info('Usuário $userId saiu da rede $networkId', tag: 'PrivateNetwork');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao sair da rede: $e', tag: 'PrivateNetwork');
    }
  }

  // ==================== GERENCIAMENTO DE PARTICIPANTES ====================

  /// Obtém participantes de uma rede
  Future<List<NetworkParticipant>> getNetworkParticipants(String networkId) async {
    try {
      // Verifica cache
      if (_networkParticipants.containsKey(networkId)) {
        return _networkParticipants[networkId]!;
      }

      // Busca do banco
      final participants = await _db.getNetworkParticipants(networkId);
      _networkParticipants[networkId] = participants;

      return participants;
    } catch (e) {
      logger.info('Erro ao obter participantes: $e', tag: 'PrivateNetwork');
      return [];
    }
  }

  /// Promove um participante a admin
  Future<void> promoteToAdmin(String networkId, String userId, String requesterId) async {
    try {
      // Verifica se o requisitante é admin
      final requester = await _db.getNetworkParticipant(networkId, requesterId);
      if (requester == null || !requester.isAdmin) {
        throw Exception('Apenas admins podem promover participantes');
      }

      await _db.updateNetworkParticipantRole(networkId, userId, 'admin');

      // Atualiza cache
      final participant = _networkParticipants[networkId]?.firstWhere(
        (p) => p.userId == userId,
        orElse: () => throw Exception('Participante não encontrado'),
      );
      if (participant != null) {
        final index = _networkParticipants[networkId]!.indexOf(participant);
        _networkParticipants[networkId]![index] = participant.copyWith(role: 'admin');
      }

      logger.info('Usuário $userId promovido a admin', tag: 'PrivateNetwork');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao promover participante: $e', tag: 'PrivateNetwork');
      rethrow;
    }
  }

  /// Bane um participante da rede
  Future<void> banParticipant(String networkId, String userId, String requesterId) async {
    try {
      // Verifica se o requisitante é admin
      final requester = await _db.getNetworkParticipant(networkId, requesterId);
      if (requester == null || !requester.isAdmin) {
        throw Exception('Apenas admins podem banir participantes');
      }

      // Não pode banir o criador
      final network = await _db.getPrivateNetwork(networkId);
      if (network?.creatorId == userId) {
        throw Exception('Não é possível banir o criador da rede');
      }

      await _db.updateNetworkParticipantStatus(networkId, userId, 'banned');

      // Atualiza cache
      _networkParticipants[networkId]?.removeWhere((p) => p.userId == userId);

      logger.info('Usuário $userId banido da rede $networkId', tag: 'PrivateNetwork');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao banir participante: $e', tag: 'PrivateNetwork');
      rethrow;
    }
  }

  // ==================== CONSULTAS ====================

  /// Obtém uma rede privada
  Future<PrivateNetwork?> getPrivateNetwork(String networkId) async {
    try {
      // Verifica cache
      if (_activeNetworks.containsKey(networkId)) {
        return _activeNetworks[networkId];
      }

      // Busca do banco
      final network = await _db.getPrivateNetwork(networkId);
      if (network != null) {
        _activeNetworks[networkId] = network;
      }

      return network;
    } catch (e) {
      logger.info('Erro ao obter rede: $e', tag: 'PrivateNetwork');
      return null;
    }
  }

  /// Obtém todas as redes do usuário
  Future<List<PrivateNetwork>> getUserNetworks(String userId) async {
    try {
      return await _db.getUserPrivateNetworks(userId);
    } catch (e) {
      logger.info('Erro ao obter redes do usuário: $e', tag: 'PrivateNetwork');
      return [];
    }
  }

  /// Verifica se usuário está em uma rede
  Future<bool> isUserInNetwork(String networkId, String userId) async {
    try {
      final participant = await _db.getNetworkParticipant(networkId, userId);
      return participant != null && participant.isActive;
    } catch (e) {
      logger.info('Erro ao verificar participação: $e', tag: 'PrivateNetwork');
      return false;
    }
  }

  /// Verifica se usuário é admin de uma rede
  Future<bool> isUserAdmin(String networkId, String userId) async {
    try {
      final participant = await _db.getNetworkParticipant(networkId, userId);
      return participant != null && participant.isAdmin;
    } catch (e) {
      logger.info('Erro ao verificar admin: $e', tag: 'PrivateNetwork');
      return false;
    }
  }

  // ==================== ESTATÍSTICAS ====================

  /// Obtém estatísticas de uma rede
  Future<Map<String, dynamic>> getNetworkStats(String networkId) async {
    try {
      final network = await getPrivateNetwork(networkId);
      final participants = await getNetworkParticipants(networkId);

      final activeParticipants = participants.where((p) => p.isActive).length;
      final admins = participants.where((p) => p.isAdmin).length;

      return {
        'name': network?.name ?? 'Unknown',
        'totalParticipants': participants.length,
        'activeParticipants': activeParticipants,
        'admins': admins,
        'maxParticipants': network?.maxParticipants ?? 0,
        'hasLimit': network?.hasParticipantLimit ?? false,
        'isFull': network?.hasParticipantLimit == true && 
                  activeParticipants >= (network?.maxParticipants ?? 0),
        'createdAt': network?.createdAt,
        'authType': network?.authType,
      };
    } catch (e) {
      logger.info('Erro ao obter estatísticas: $e', tag: 'PrivateNetwork');
      return {};
    }
  }

  // ==================== LIMPEZA ====================

  /// Fecha uma rede privada
  Future<void> closeNetwork(String networkId, String requesterId) async {
    try {
      final network = await _db.getPrivateNetwork(networkId);
      if (network == null) return;

      // Apenas o criador pode fechar a rede
      if (network.creatorId != requesterId) {
        throw Exception('Apenas o criador pode fechar a rede');
      }

      await _db.updatePrivateNetworkStatus(networkId, 'closed');

      // Remove do cache
      _activeNetworks.remove(networkId);
      _networkParticipants.remove(networkId);

      if (_currentNetworkId == networkId) {
        _currentNetworkId = null;
      }

      logger.info('Rede $networkId fechada', tag: 'PrivateNetwork');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao fechar rede: $e', tag: 'PrivateNetwork');
      rethrow;
    }
  }

  /// Limpa cache
  void clearCache() {
    _activeNetworks.clear();
    _networkParticipants.clear();
    _currentNetworkId = null;
    notifyListeners();
  }
}
