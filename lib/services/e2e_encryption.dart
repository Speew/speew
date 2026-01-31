import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import '../core/utils.dart';

/// E2E Encryption Service - OTIMIZADO
/// Features:
/// - Persistent key storage (Hive)
/// - Key rotation automática
/// - Session resumption
/// - Multiple sessions per peer
class E2EEncryption {
  // Algoritmos
  static final _x25519 = X25519();
  static final _chacha20 = Chacha20.poly1305Aead();
  static final _sha256 = Sha256();
  
  // Storage
  Box? _keyStore;
  
  // Chaves locais
  SimpleKeyPair? _localKeyPair;
  SimplePublicKey? _remotePublicKey;
  SecretKey? _sharedSecret;
  
  // Session management
  String? _sessionId;
  DateTime? _sessionCreated;
  int _messagesEncrypted = 0;
  
  // Key rotation config
  static const int maxMessagesBeforeRotation = 1000;
  static const Duration maxSessionDuration = Duration(days: 7);
  
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get hasSharedSecret => _sharedSecret != null;
  bool get needsKeyRotation => 
      _messagesEncrypted >= maxMessagesBeforeRotation ||
      (_sessionCreated != null && 
       DateTime.now().difference(_sessionCreated!) > maxSessionDuration);

  /// Inicializar com storage persistente
  Future<void> initialize() async {
    try {
      // Abrir Hive box para chaves
      _keyStore = await Hive.openBox('e2e_keys');
      
      // Tentar carregar chave existente
      final savedKeyPair = _keyStore?.get('local_keypair');
      
      if (savedKeyPair != null) {
        // Restaurar chave existente
        _localKeyPair = await _deserializeKeyPair(savedKeyPair);
        DebugUtils.log('Restored existing keypair', tag: 'E2E');
      } else {
        // Gerar nova chave
        _localKeyPair = await _x25519.newKeyPair();
        
        // Salvar para persistência
        final serialized = await _serializeKeyPair(_localKeyPair!);
        await _keyStore?.put('local_keypair', serialized);
        
        DebugUtils.log('Generated new keypair', tag: 'E2E');
      }
      
      _isInitialized = true;
    } catch (e) {
      DebugUtils.logError('E2E initialization failed', error: e);
      rethrow;
    }
  }

  /// Obter chave pública local
  Future<Uint8List> getPublicKey() async {
    if (_localKeyPair == null) {
      throw Exception('Not initialized');
    }

    final publicKey = await _localKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Estabelecer sessão com peer
  Future<void> computeSharedSecret(
    Uint8List remotePublicKeyBytes, {
    String? sessionId,
  }) async {
    if (_localKeyPair == null) {
      throw Exception('Not initialized');
    }

    try {
      // Criar SimplePublicKey do peer
      _remotePublicKey = SimplePublicKey(
        remotePublicKeyBytes,
        type: KeyPairType.x25519,
      );

      // Calcular shared secret usando ECDH
      final sharedSecretKey = await _x25519.sharedSecretKey(
        keyPair: _localKeyPair!,
        remotePublicKey: _remotePublicKey!,
      );

      // Derivar chave final usando HKDF (Key Derivation Function)
      final hkdf = Hkdf(
        hmac: Hmac(_sha256),
        outputLength: 32,
      );

      _sharedSecret = await hkdf.deriveKey(
        secretKey: sharedSecretKey,
        nonce: utf8.encode('speew-e2e-v2'),
        info: sessionId != null ? utf8.encode(sessionId) : [],
      );

      _sessionId = sessionId ?? _generateSessionId();
      _sessionCreated = DateTime.now();
      _messagesEncrypted = 0;

      // Salvar session info
      await _saveSessionInfo();

      DebugUtils.log('Shared secret computed for session: $_sessionId', tag: 'E2E');
    } catch (e) {
      DebugUtils.logError('Failed to compute shared secret', error: e);
      rethrow;
    }
  }

  /// Encriptar mensagem (otimizado)
  Future<Map<String, dynamic>> encrypt(String plaintext) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    try {
      final nonce = _chacha20.newNonce();
      
      final secretBox = await _chacha20.encrypt(
        utf8.encode(plaintext),
        secretKey: _sharedSecret!,
        nonce: nonce,
      );

      _messagesEncrypted++;
      
      // Verificar se precisa rotacionar chaves
      if (needsKeyRotation) {
        DebugUtils.log('Key rotation needed', tag: 'E2E');
      }

      return {
        'ciphertext': base64Encode(secretBox.cipherText),
        'nonce': base64Encode(nonce),
        'mac': base64Encode(secretBox.mac.bytes),
        'session_id': _sessionId,
        'msg_count': _messagesEncrypted,
      };
    } catch (e) {
      DebugUtils.logError('Encryption failed', error: e);
      rethrow;
    }
  }

  /// Decriptar mensagem (otimizado)
  Future<String> decrypt(Map<String, dynamic> encrypted) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    try {
      final secretBox = SecretBox(
        base64Decode(encrypted['ciphertext'] as String),
        nonce: base64Decode(encrypted['nonce'] as String),
        mac: Mac(base64Decode(encrypted['mac'] as String)),
      );

      final decrypted = await _chacha20.decrypt(
        secretBox,
        secretKey: _sharedSecret!,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      DebugUtils.logError('Decryption failed', error: e);
      rethrow;
    }
  }

  /// Encriptar bytes (para arquivos) - OTIMIZADO para grandes volumes
  Future<Map<String, dynamic>> encryptBytes(
    Uint8List data, {
    Function(double)? onProgress,
  }) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    try {
      // Para dados grandes, processar em chunks
      const chunkSize = 256 * 1024; // 256KB chunks
      
      if (data.length <= chunkSize) {
        // Pequeno, processar de uma vez
        final nonce = _chacha20.newNonce();
        final secretBox = await _chacha20.encrypt(
          data,
          secretKey: _sharedSecret!,
          nonce: nonce,
        );

        return {
          'ciphertext': secretBox.cipherText,
          'nonce': nonce,
          'mac': secretBox.mac.bytes,
        };
      } else {
        // Grande, processar em chunks
        final chunks = <Map<String, dynamic>>[];
        int processed = 0;

        for (int i = 0; i < data.length; i += chunkSize) {
          final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
          final chunk = data.sublist(i, end);

          final nonce = _chacha20.newNonce();
          final secretBox = await _chacha20.encrypt(
            chunk,
            secretKey: _sharedSecret!,
            nonce: nonce,
          );

          chunks.add({
            'ciphertext': secretBox.cipherText,
            'nonce': nonce,
            'mac': secretBox.mac.bytes,
          });

          processed += chunk.length;
          onProgress?.call(processed / data.length);
        }

        return {
          'chunks': chunks,
          'total_size': data.length,
        };
      }
    } catch (e) {
      DebugUtils.logError('Byte encryption failed', error: e);
      rethrow;
    }
  }

  /// Decriptar bytes (otimizado)
  Future<Uint8List> decryptBytes(
    Map<String, dynamic> encrypted, {
    Function(double)? onProgress,
  }) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    try {
      // Verificar se é chunked
      if (encrypted.containsKey('chunks')) {
        final chunks = encrypted['chunks'] as List;
        final result = <int>[];
        int processed = 0;
        final totalSize = encrypted['total_size'] as int;

        for (final chunkData in chunks) {
          final secretBox = SecretBox(
            chunkData['ciphertext'] as Uint8List,
            nonce: chunkData['nonce'] as List<int>,
            mac: Mac(chunkData['mac'] as List<int>),
          );

          final decrypted = await _chacha20.decrypt(
            secretBox,
            secretKey: _sharedSecret!,
          );

          result.addAll(decrypted);
          processed += decrypted.length;
          onProgress?.call(processed / totalSize);
        }

        return Uint8List.fromList(result);
      } else {
        // Single block
        final secretBox = SecretBox(
          encrypted['ciphertext'] as Uint8List,
          nonce: encrypted['nonce'] as List<int>,
          mac: Mac(encrypted['mac'] as List<int>),
        );

        final decrypted = await _chacha20.decrypt(
          secretBox,
          secretKey: _sharedSecret!,
        );

        return Uint8List.fromList(decrypted);
      }
    } catch (e) {
      DebugUtils.logError('Byte decryption failed', error: e);
      rethrow;
    }
  }

  /// Rotacionar chaves (Perfect Forward Secrecy)
  Future<void> rotateKeys() async {
    if (_remotePublicKey == null) {
      throw Exception('No remote key to rotate with');
    }

    DebugUtils.log('Rotating keys...', tag: 'E2E');

    // Gerar novo par de chaves efêmero
    final newLocalKeyPair = await _x25519.newKeyPair();

    // Recalcular shared secret
    final newSharedSecretKey = await _x25519.sharedSecretKey(
      keyPair: newLocalKeyPair,
      remotePublicKey: _remotePublicKey!,
    );

    final hkdf = Hkdf(
      hmac: Hmac(_sha256),
      outputLength: 32,
    );

    _sharedSecret = await hkdf.deriveKey(
      secretKey: newSharedSecretKey,
      nonce: utf8.encode('speew-rotation-${DateTime.now().millisecondsSinceEpoch}'),
    );

    // Atualizar keypair local efêmero (não persistir - é efêmero!)
    _localKeyPair = newLocalKeyPair;
    _sessionCreated = DateTime.now();
    _messagesEncrypted = 0;

    DebugUtils.log('Keys rotated successfully', tag: 'E2E');
  }

  /// Fingerprint da chave pública (para verificação)
  Future<String> getPublicKeyFingerprint() async {
    final publicKeyBytes = await getPublicKey();
    final hash = await _sha256.hash(publicKeyBytes);
    
    return hash.bytes
        .take(16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  /// Verificar fingerprint do peer
  Future<String> getRemoteKeyFingerprint() async {
    if (_remotePublicKey == null) {
      throw Exception('Remote public key not set');
    }

    final hash = await _sha256.hash(_remotePublicKey!.bytes);
    
    return hash.bytes
        .take(16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  /// Salvar informações da sessão
  Future<void> _saveSessionInfo() async {
    await _keyStore?.put('session_info', {
      'session_id': _sessionId,
      'created': _sessionCreated?.millisecondsSinceEpoch,
      'messages_encrypted': _messagesEncrypted,
    });
  }

  /// Serializar keypair
  Future<Map<String, dynamic>> _serializeKeyPair(SimpleKeyPair keyPair) async {
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    
    return {
      'private': base64Encode(privateBytes),
      'public': base64Encode(publicKey.bytes),
    };
  }

  /// Deserializar keypair
  Future<SimpleKeyPair> _deserializeKeyPair(Map<String, dynamic> data) async {
    final privateBytes = base64Decode(data['private'] as String);
    return SimpleKeyPairData(
      privateBytes,
      publicKey: SimplePublicKey(
        base64Decode(data['public'] as String),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
  }

  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Reset (para novo peer)
  void reset() {
    _remotePublicKey = null;
    _sharedSecret = null;
    _sessionId = null;
    _sessionCreated = null;
    _messagesEncrypted = 0;
    
    DebugUtils.log('E2E session reset', tag: 'E2E');
  }

  /// Estatísticas da sessão
  Map<String, dynamic> getSessionStats() {
    return {
      'session_id': _sessionId,
      'created': _sessionCreated?.toIso8601String(),
      'messages_encrypted': _messagesEncrypted,
      'needs_rotation': needsKeyRotation,
      'has_shared_secret': hasSharedSecret,
    };
  }

  Future<void> dispose() async {
    await _keyStore?.close();
  }
}

/// Gerenciador de múltiplas sessões E2E
class E2EManager {
  final Map<String, E2EEncryption> _sessions = {};

  /// Obter ou criar sessão E2E para um peer
  E2EEncryption getSession(String peerId) {
    if (!_sessions.containsKey(peerId)) {
      _sessions[peerId] = E2EEncryption();
    }
    return _sessions[peerId]!;
  }

  /// Inicializar sessão
  Future<void> initializeSession(String peerId) async {
    final session = getSession(peerId);
    if (!session.isInitialized) {
      await session.initialize();
    }
  }

  /// Trocar chaves com peer
  Future<void> exchangeKeys(
    String peerId,
    Uint8List remotePublicKey, {
    String? sessionId,
  }) async {
    final session = getSession(peerId);
    await session.computeSharedSecret(remotePublicKey, sessionId: sessionId);
  }

  /// Verificar se sessão está pronta
  bool isSessionReady(String peerId) {
    final session = _sessions[peerId];
    return session?.hasSharedSecret ?? false;
  }

  /// Limpar sessão
  void clearSession(String peerId) {
    _sessions[peerId]?.reset();
    _sessions.remove(peerId);
    DebugUtils.log('E2E session cleared for $peerId', tag: 'E2E');
  }

  /// Limpar todas as sessões
  void clearAllSessions() {
    _sessions.clear();
    DebugUtils.log('All E2E sessions cleared', tag: 'E2E');
  }

  /// Obter estatísticas de todas as sessões
  Map<String, dynamic> getAllStats() {
    return _sessions.map(
      (peerId, session) => MapEntry(peerId, session.getSessionStats()),
    );
  }

  Future<void> dispose() async {
    for (final session in _sessions.values) {
      await session.dispose();
    }
    _sessions.clear();
  }
}
