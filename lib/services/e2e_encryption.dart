import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../core/utils.dart';

class E2EEncryption {
  // Algoritmos
  static final _x25519 = X25519();
  static final _chacha20 = Chacha20.poly1305Aead();
  static final _sha256 = Sha256();
  
  // Chaves locais
  SimpleKeyPair? _localKeyPair;
  SimplePublicKey? _remotePublicKey;
  SecretKey? _sharedSecret;
  
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get hasSharedSecret => _sharedSecret != null;

  /// Inicializar - Gerar par de chaves local
  Future<void> initialize() async {
    _localKeyPair = await _x25519.newKeyPair();
    _isInitialized = true;
    DebugUtils.log('E2E Encryption initialized', tag: 'E2E');
  }

  /// Obter chave pública local para enviar ao peer
  Future<Uint8List> getPublicKey() async {
    if (_localKeyPair == null) {
      throw Exception('Not initialized');
    }

    final publicKey = await _localKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Receber chave pública do peer e calcular shared secret
  Future<void> computeSharedSecret(Uint8List remotePublicKeyBytes) async {
    if (_localKeyPair == null) {
      throw Exception('Not initialized');
    }

    // Criar SimplePublicKey do peer
    _remotePublicKey = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );

    // Calcular shared secret usando ECDH
    final sharedSecretBytes = await _x25519.sharedSecretKey(
      keyPair: _localKeyPair!,
      remotePublicKey: _remotePublicKey!,
    );

    // Derivar chave final usando HKDF
    final hkdf = Hkdf(
      hmac: Hmac(_sha256),
      outputLength: 32,
    );

    _sharedSecret = await hkdf.deriveKey(
      secretKey: sharedSecretBytes,
      nonce: utf8.encode('speew-e2e-v1'),
    );

    DebugUtils.log('Shared secret computed', tag: 'E2E');
  }

  /// Encriptar mensagem
  Future<Map<String, dynamic>> encrypt(String plaintext) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    final secretBox = await _chacha20.encrypt(
      utf8.encode(plaintext),
      secretKey: _sharedSecret!,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Decriptar mensagem
  Future<String> decrypt(Map<String, dynamic> encrypted) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

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
  }

  /// Encriptar bytes (para arquivos)
  Future<Map<String, dynamic>> encryptBytes(Uint8List data) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

    final secretBox = await _chacha20.encrypt(
      data,
      secretKey: _sharedSecret!,
    );

    return {
      'ciphertext': secretBox.cipherText,
      'nonce': secretBox.nonce,
      'mac': secretBox.mac.bytes,
    };
  }

  /// Decriptar bytes
  Future<Uint8List> decryptBytes(Map<String, dynamic> encrypted) async {
    if (_sharedSecret == null) {
      throw Exception('Shared secret not established');
    }

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

  /// Reset (para novo peer)
  void reset() {
    _remotePublicKey = null;
    _sharedSecret = null;
    DebugUtils.log('E2E session reset', tag: 'E2E');
  }

  /// Fingerprint da chave pública (para verificação)
  Future<String> getPublicKeyFingerprint() async {
    final publicKeyBytes = await getPublicKey();
    final hash = await _sha256.hash(publicKeyBytes);
    
    // Retornar primeiros 16 bytes em hex
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
}

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
    Uint8List remotePublicKey,
  ) async {
    final session = getSession(peerId);
    await session.computeSharedSecret(remotePublicKey);
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
}
