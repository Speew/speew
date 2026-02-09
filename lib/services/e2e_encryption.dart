import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import '../core/utils.dart';

class E2EEncryption {
  
  static final _x25519 = X25519();
  static final _chacha20 = Chacha20.poly1305Aead();
  static final _sha256 = Sha256();

  Box? _keyStore;

  SimpleKeyPair? _localKeyPair;
  SimplePublicKey? _remotePublicKey;
  SecretKey? _sharedSecret;

  String? _sessionId;
  DateTime? _sessionCreated;
  int _messagesEncrypted = 0;

  static const int maxMessagesBeforeRotation = 1000;
  static const Duration maxSessionDuration = Duration(days: 7);
  
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get hasSharedSecret => _sharedSecret != null;
  bool get needsKeyRotation => 
      _messagesEncrypted >= maxMessagesBeforeRotation ||
      (_sessionCreated != null && 
       DateTime.now().difference(_sessionCreated!) > maxSessionDuration);

  Future<void> initialize() async {
    try {
      
      _keyStore = await Hive.openBox('e2e_keys');

      final savedKeyPair = _keyStore?.get('local_keypair');
      
      if (savedKeyPair != null) {
        
        _localKeyPair = await _deserializeKeyPair(savedKeyPair);
        DebugUtils.log('Restored existing keypair', tag: 'E2E');
      } else {
        
        _localKeyPair = await _x25519.newKeyPair();

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

  Future<Uint8List> getPublicKey() async {
    if (_localKeyPair == null) {
      throw Exception('Not initialized');
    }

    final publicKey = await _localKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  Future<void> computeSharedSecret(
    Uint8List remotePublicKeyBytes, {
    String? sessionId,
  }) async {
    if (_localKeyPair == null) {
      throw Exception('Not initialized');
    }

    try {
      
      _remotePublicKey = SimplePublicKey(
        remotePublicKeyBytes,
        type: KeyPairType.x25519,
      );

      final sharedSecretKey = await _x25519.sharedSecretKey(
        keyPair: _localKeyPair!,
        remotePublicKey: _remotePublicKey!,
      );

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

      await _saveSessionInfo();

      DebugUtils.log('Shared secret computed for session: $_sessionId', tag: 'E2E');
    } catch (e) {
      DebugUtils.logError('Failed to compute shared secret', error: e);
      rethrow;
    }
  }

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

  Future<Map<String, dynamic>> encryptBytes(
    Uint8List data, {
    Function(double)? onProgress,
  }) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    try {
      
      const chunkSize = 256 * 1024; 
      
      if (data.length <= chunkSize) {
        
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

  Future<Uint8List> decryptBytes(
    Map<String, dynamic> encrypted, {
    Function(double)? onProgress,
  }) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    try {
      
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

  Future<void> rotateKeys() async {
    if (_remotePublicKey == null) {
      throw Exception('No remote key to rotate with');
    }

    DebugUtils.log('Rotating keys...', tag: 'E2E');

    final newLocalKeyPair = await _x25519.newKeyPair();

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

    _localKeyPair = newLocalKeyPair;
    _sessionCreated = DateTime.now();
    _messagesEncrypted = 0;

    DebugUtils.log('Keys rotated successfully', tag: 'E2E');
  }

  Future<String> getPublicKeyFingerprint() async {
    final publicKeyBytes = await getPublicKey();
    final hash = await _sha256.hash(publicKeyBytes);
    
    return hash.bytes
        .take(16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

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

  Future<void> _saveSessionInfo() async {
    await _keyStore?.put('session_info', {
      'session_id': _sessionId,
      'created': _sessionCreated?.millisecondsSinceEpoch,
      'messages_encrypted': _messagesEncrypted,
    });
  }

  Future<Map<String, dynamic>> _serializeKeyPair(SimpleKeyPair keyPair) async {
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    
    return {
      'private': base64Encode(privateBytes),
      'public': base64Encode(publicKey.bytes),
    };
  }

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

  void reset() {
    _remotePublicKey = null;
    _sharedSecret = null;
    _sessionId = null;
    _sessionCreated = null;
    _messagesEncrypted = 0;
    
    DebugUtils.log('E2E session reset', tag: 'E2E');
  }

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

class E2EManager {
  final Map<String, E2EEncryption> _sessions = {};

  E2EEncryption getSession(String peerId) {
    if (!_sessions.containsKey(peerId)) {
      _sessions[peerId] = E2EEncryption();
    }
    return _sessions[peerId]!;
  }

  Future<void> initializeSession(String peerId) async {
    final session = getSession(peerId);
    if (!session.isInitialized) {
      await session.initialize();
    }
  }

  Future<void> exchangeKeys(
    String peerId,
    Uint8List remotePublicKey, {
    String? sessionId,
  }) async {
    final session = getSession(peerId);
    await session.computeSharedSecret(remotePublicKey, sessionId: sessionId);
  }

  bool isSessionReady(String peerId) {
    final session = _sessions[peerId];
    return session?.hasSharedSecret ?? false;
  }

  void clearSession(String peerId) {
    _sessions[peerId]?.reset();
    _sessions.remove(peerId);
    DebugUtils.log('E2E session cleared for $peerId', tag: 'E2E');
  }

  void clearAllSessions() {
    _sessions.clear();
    DebugUtils.log('All E2E sessions cleared', tag: 'E2E');
  }

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