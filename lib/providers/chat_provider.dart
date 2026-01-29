import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../models/group.dart';
import '../services/p2p_service.dart';
import '../services/storage_service.dart';
import '../services/crypto_service.dart';
import '../services/group_service.dart';
import '../services/image_service.dart';
import '../services/notification_service.dart';

class ChatProvider with ChangeNotifier {
  final P2PService _p2pService = P2PService();
  final StorageService _storageService = StorageService();
  final CryptoService _cryptoService = CryptoService();
  final GroupService _groupService = GroupService();
  final ImageService _imageService = ImageService();
  final Uuid _uuid = const Uuid();

  final Map<String, List<Message>> _messagesByPeer = {};
  final List<Peer> _peers = [];
  String? _currentUserId;
  String? _currentUserName;
  String? _statusMessage;
  bool _isInitialized = false;
  bool _meshEnabled = false; // Mesh multi-hop habilitado

  // Getters
  List<Peer> get peers => List.from(_peers);
  List<Peer> get connectedPeers =>
      _peers.where((p) => p.isConnected).toList();
  String? get statusMessage => _statusMessage;
  bool get isInitialized => _isInitialized;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  bool get isMeshEnabled => _meshEnabled;

  List<Group> get groups => _groupService.groups;
  List<GroupMessage> getGroupMessages(String groupId) =>
      _groupService.getMessages(groupId);

  // Criar grupo
  Group createGroup({
    required String name,
    required List<String> memberIds,
  }) {
    final group = _groupService.createGroup(
      id: _uuid.v4(),
      name: name,
      creatorId: _currentUserId!,
      memberIds: memberIds,
    );

    _setStatus('Grupo "$name" criado');
    return group;
  }

  // Enviar mensagem em grupo
  Future<bool> sendGroupMessage(String groupId, String content) async {
    if (_currentUserId == null) return false;

    final message = GroupMessage(
      id: _uuid.v4(),
      groupId: groupId,
      senderId: _currentUserId!,
      content: content,
      timestamp: DateTime.now(),
    );

    _groupService.addMessage(message);

    // Enviar para todos os membros do grupo
    final group = _groupService.getGroup(groupId);
    if (group != null) {
      for (final memberId in group.memberIds) {
        if (memberId != _currentUserId) {
          await sendMessage(memberId, content);
        }
      }
    }

    notifyListeners();
    return true;
  }

  // Enviar imagem
  Future<bool> sendImageMessage(String peerId, String imagePath) async {
    // TODO: Implementar envio de imagem via P2P
    // Por enquanto, apenas salva localmente
    final message = Message(
      id: _uuid.v4(),
      senderId: _currentUserId ?? 'me',
      receiverId: peerId,
      content: '[Imagem]',
      timestamp: DateTime.now(),
      isSent: false,
    );

    await _storageService.saveMessage(message);
    notifyListeners();
    return true;
  }

  List<Message> getMessagesForPeer(String peerId) {
    return _messagesByPeer[peerId] ?? [];
  }

  // Inicializar
  Future<void> initialize(String userName, {bool enableMesh = false}) async {
    try {
      _currentUserId = _uuid.v4();
      _currentUserName = userName;
      _meshEnabled = enableMesh;

      // Carregar peers e mensagens do banco
      await _loadDataFromStorage();

      // Iniciar P2P
      await _p2pService.startAdvertising(userName);
      await _p2pService.startDiscovery(userName);

      // Inicializar mesh se habilitado
      if (_meshEnabled) {
        _p2pService.initializeMesh(_currentUserId!);
        _setStatus('Mesh multi-hop ativado');
      }

      // Escutar eventos P2P
      _listenToP2PEvents();

      _isInitialized = true;
      _setStatus('Iniciado como: $userName${_meshEnabled ? ' (Mesh ativo)' : ''}');
      notifyListeners();
    } catch (e) {
      _setStatus('Erro ao inicializar: $e');
      rethrow;
    }
  }

  // Alternar mesh routing
  Future<void> toggleMesh(bool enable) async {
    if (!_isInitialized || _currentUserId == null) return;
    
    _meshEnabled = enable;
    
    if (enable) {
      _p2pService.initializeMesh(_currentUserId!);
      _setStatus('Mesh multi-hop ativado');
    } else {
      _setStatus('Mesh multi-hop desativado');
    }
    
    notifyListeners();
  }

  // Carregar dados do storage
  Future<void> _loadDataFromStorage() async {
    try {
      // Carregar peers
      final storedPeers = await _storageService.getAllPeers();
      _peers.addAll(storedPeers);

      // Carregar mensagens para cada peer
      for (final peer in storedPeers) {
        final messages = await _storageService.getMessages(peer.id);
        _messagesByPeer[peer.id] = messages;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    }
  }

  // Escutar eventos P2P
  void _listenToP2PEvents() {
    // Peers descobertos
    _p2pService.discoveredPeersStream.listen((peer) {
      _addOrUpdatePeer(peer);
    });

    // Mensagens recebidas
    _p2pService.messagesStream.listen((data) {
      _handleIncomingMessage(data);
    });

    // Status de conexão
    _p2pService.connectionStatusStream.listen((status) {
      _setStatus(status);
    });
  }

  // Adicionar ou atualizar peer
  void _addOrUpdatePeer(Peer peer) {
    final index = _peers.indexWhere((p) => p.id == peer.id);
    
    if (index >= 0) {
      _peers[index] = peer;
    } else {
      _peers.add(peer);
      _messagesByPeer[peer.id] = [];
    }

    // Salvar no storage
    _storageService.savePeer(peer);
    
    notifyListeners();
  }

  // Conectar a um peer
  Future<void> connectToPeer(Peer peer) async {
    try {
      await _p2pService.connectToPeer(peer.id, _currentUserName ?? 'User');
      _setStatus('Conectando a ${peer.name}...');
    } catch (e) {
      _setStatus('Erro ao conectar: $e');
    }
  }

  // Desconectar de um peer
  Future<void> disconnectFromPeer(Peer peer) async {
    try {
      await _p2pService.disconnectFromPeer(peer.id);
      _addOrUpdatePeer(peer.copyWith(isConnected: false));
      _setStatus('Desconectado de ${peer.name}');
    } catch (e) {
      _setStatus('Erro ao desconectar: $e');
    }
  }

  // Enviar mensagem
  Future<bool> sendMessage(String peerId, String content) async {
    try {
      final message = Message(
        id: _uuid.v4(),
        senderId: _currentUserId ?? 'me',
        receiverId: peerId,
        content: content,
        timestamp: DateTime.now(),
        isSent: false,
      );

      // Salvar localmente primeiro
      await _storageService.saveMessage(message);
      
      // Adicionar à lista local
      if (!_messagesByPeer.containsKey(peerId)) {
        _messagesByPeer[peerId] = [];
      }
      _messagesByPeer[peerId]!.add(message);
      notifyListeners();

      // Enviar via P2P (mesh ou direto)
      bool sent;
      if (_meshEnabled) {
        sent = await _p2pService.sendMeshMessage(peerId, content);
      } else {
        sent = await _p2pService.sendMessage(peerId, content);
      }

      // Atualizar status de envio
      if (sent) {
        await _storageService.updateMessageStatus(message.id, true);
        final index = _messagesByPeer[peerId]!
            .indexWhere((m) => m.id == message.id);
        if (index >= 0) {
          _messagesByPeer[peerId]![index] = 
              message.copyWith(isSent: true);
        }
        notifyListeners();
      }

      return sent;
    } catch (e) {
      _setStatus('Erro ao enviar mensagem: $e');
      return false;
    }
  }

  // Receber mensagem
  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final viaMesh = data['via_mesh'] as bool? ?? false;
      final hopCount = data['hop_count'] as int? ?? 0;
      
      final message = Message(
        id: _uuid.v4(),
        senderId: data['sender_id'] as String,
        receiverId: _currentUserId ?? 'me',
        content: data['content'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          data['timestamp'] as int,
        ),
        isSent: true,
      );

      // Salvar no storage
      _storageService.saveMessage(message);

      // Adicionar à lista
      final senderId = message.senderId;
      if (!_messagesByPeer.containsKey(senderId)) {
        _messagesByPeer[senderId] = [];
      }
      _messagesByPeer[senderId]!.add(message);

      // Mostrar notificação
      final peer = _peers.firstWhere(
        (p) => p.id == senderId,
        orElse: () => Peer(
          id: senderId,
          name: 'Desconhecido',
          lastSeen: DateTime.now(),
        ),
      );
      
      NotificationService.showMessageNotification(
        id: NotificationService.generateNotificationId(senderId),
        title: peer.name,
        body: message.content,
      );

      // Atualizar status com info de mesh
      if (viaMesh) {
        _setStatus('Mensagem recebida via mesh ($hopCount hops)');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao processar mensagem recebida: $e');
    }
  }

  // Obter estatísticas mesh
  Map<String, dynamic> getMeshStatistics() {
    return _p2pService.getMeshStatistics();
  }

  // Atualizar status
  void _setStatus(String status) {
    _statusMessage = status;
    debugPrint('Status: $status');
    notifyListeners();
  }

  // Limpar histórico de um peer
  Future<void> clearChatHistory(String peerId) async {
    try {
      final messages = _messagesByPeer[peerId] ?? [];
      for (final message in messages) {
        await _storageService.deleteMessage(message.id);
      }
      _messagesByPeer[peerId] = [];
      notifyListeners();
    } catch (e) {
      _setStatus('Erro ao limpar histórico: $e');
    }
  }

  // Remover peer
  Future<void> removePeer(String peerId) async {
    try {
      await _storageService.deletePeer(peerId);
      await clearChatHistory(peerId);
      _peers.removeWhere((p) => p.id == peerId);
      _messagesByPeer.remove(peerId);
      notifyListeners();
    } catch (e) {
      _setStatus('Erro ao remover peer: $e');
    }
  }

  @override
  void dispose() {
    _p2pService.dispose();
    _groupService.dispose();
    super.dispose();
  }
}
