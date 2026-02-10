import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../core/utils.dart';
import '../core/error/error_handler.dart';

class E2EEncryptionService {
  
  static final _x25519 = X25519();
  static final _chacha20 = Chacha20.poly1305Aead();
  static final _sha256 = Sha256();

  SimpleKeyPair? _identityKeyPair;

  final Map<String, _SessionKeys> _sessions = {};

  Future<void> initialize() async {
    _identityKeyPair = await _x25519.newKeyPair();
    DebugUtils.log('E2E Encryption initialized', tag: 'E2E');
  }

  Future<String> getPublicIdentityKey() async {
    if (_identityKeyPair == null) await initialize();
    
    final publicKey = await _identityKeyPair!.extractPublicKey();
    final bytes = await publicKey.extract();
    return base64Encode(bytes.bytes);
  }

  Future<Map<String, String>> initiateHandshake(String peerId) async {
    if (_identityKeyPair == null) await initialize();

    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    final ephemeralPublicBytes = await ephemeralPublicKey.extract();

    final identityPublicKey = await _identityKeyPair!.extractPublicKey();
    final identityPublicBytes = await identityPublicKey.extract();

    _sessions[peerId] = _SessionKeys(
      ephemeralKeyPair: ephemeralKeyPair,
      myIdentityKeyPair: _identityKeyPair!,
    );

    DebugUtils.log('Handshake initiated with $peerId', tag: 'E2E');

    return {
      'identity_key': base64Encode(identityPublicBytes.bytes),
      'ephemeral_key': base64Encode(ephemeralPublicBytes.bytes),
      'protocol_version': '1.0',
    };
  }

  Future<Map<String, String>> processHandshake(
    String peerId,
    Map<String, String> handshakeData,
  ) async {
    if (_identityKeyPair == null) await initialize();

    final peerIdentityKeyBytes = base64Decode(handshakeData['identity_key']!);
    final peerEphemeralKeyBytes = base64Decode(handshakeData['ephemeral_key']!);

    final peerIdentityKey = SimplePublicKey(
      peerIdentityKeyBytes,
      type: KeyPairType.x25519,
    );
    final peerEphemeralKey = SimplePublicKey(
      peerEphemeralKeyBytes,
      type: KeyPairType.x25519,
    );

    final myEphemeralKeyPair = await _x25519.newKeyPair();
    final myEphemeralPublicKey = await myEphemeralKeyPair.extractPublicKey();
    final myEphemeralPublicBytes = await myEphemeralPublicKey.extract();

    final dh1 = await _x25519.sharedSecretKey(
      keyPair: _identityKeyPair!,
      remotePublicKey: peerEphemeralKey,
    );

    final dh2 = await _x25519.sharedSecretKey(
      keyPair: myEphemeralKeyPair,
      remotePublicKey: peerIdentityKey,
    );

    final dh3 = await _x25519.sharedSecretKey(
      keyPair: myEphemeralKeyPair,
      remotePublicKey: peerEphemeralKey,
    );

    final masterSecret = await _deriveMasterSecret([dh1, dh2, dh3]);

    final sendKey = await _deriveKey(masterSecret, 'send');
    final receiveKey = await _deriveKey(masterSecret, 'receive');

    _sessions[peerId] = _SessionKeys(
      ephemeralKeyPair: myEphemeralKeyPair,
      myIdentityKeyPair: _identityKeyPair!,
      peerIdentityKey: peerIdentityKey,
      peerEphemeralKey: peerEphemeralKey,
      sendKey: sendKey,
      receiveKey: receiveKey,
      masterSecret: masterSecret,
    );

    DebugUtils.log('Handshake completed with $peerId', tag: 'E2E');

    final myIdentityPublicKey = await _identityKeyPair!.extractPublicKey();
    final myIdentityPublicBytes = await myIdentityPublicKey.extract();

    return {
      'identity_key': base64Encode(myIdentityPublicBytes.bytes),
      'ephemeral_key': base64Encode(myEphemeralPublicBytes.bytes),
      'protocol_version': '1.0',
    };
  }

  Future<void> completeHandshake(
    String peerId,
    Map<String, String> responseData,
  ) async {
    final session = _sessions[peerId];
    if (session == null) {
      throw EncryptionException('No pending handshake for $peerId');
    }

    final peerIdentityKeyBytes = base64Decode(responseData['identity_key']!);
    final peerEphemeralKeyBytes = base64Decode(responseData['ephemeral_key']!);

    final peerIdentityKey = SimplePublicKey(
      peerIdentityKeyBytes,
      type: KeyPairType.x25519,
    );
    final peerEphemeralKey = SimplePublicKey(
      peerEphemeralKeyBytes,
      type: KeyPairType.x25519,
    );

    final dh1 = await _x25519.sharedSecretKey(
      keyPair: session.myIdentityKeyPair,
      remotePublicKey: peerEphemeralKey,
    );

    final dh2 = await _x25519.sharedSecretKey(
      keyPair: session.ephemeralKeyPair,
      remotePublicKey: peerIdentityKey,
    );

    final dh3 = await _x25519.sharedSecretKey(
      keyPair: session.ephemeralKeyPair,
      remotePublicKey: peerEphemeralKey,
    );

    final masterSecret = await _deriveMasterSecret([dh1, dh2, dh3]);

    final sendKey = await _deriveKey(masterSecret, 'receive');
    final receiveKey = await _deriveKey(masterSecret, 'send');

    _sessions[peerId] = session.copyWith(
      peerIdentityKey: peerIdentityKey,
      peerEphemeralKey: peerEphemeralKey,
      sendKey: sendKey,
      receiveKey: receiveKey,
      masterSecret: masterSecret,
    );

    DebugUtils.log('Handshake fully established with $peerId', tag: 'E2E');
  }

  Future<String> encryptMessage(String peerId, String plaintext) async {
    final session = _sessions[peerId];
    if (session == null || session.sendKey == null) {
      throw EncryptionException('No E2E session with $peerId');
    }

    final nonce = _chacha20.newNonce();
    final secretBox = await _chacha20.encrypt(
      utf8.encode(plaintext),
      secretKey: session.sendKey!,
      nonce: nonce,
    );

    final encrypted = {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'version': '1.0',
    };

    return jsonEncode(encrypted);
  }

  Future<String> decryptMessage(String peerId, String encryptedJson) async {
    final session = _sessions[peerId];
    if (session == null || session.receiveKey == null) {
      throw EncryptionException('No E2E session with $peerId');
    }

    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;

    final secretBox = SecretBox(
      base64Decode(data['ciphertext'] as String),
      nonce: base64Decode(data['nonce'] as String),
      mac: Mac(base64Decode(data['mac'] as String)),
    );

    final decrypted = await _chacha20.decrypt(
      secretBox,
      secretKey: session.receiveKey!,
    );

    return utf8.decode(decrypted);
  }

  Future<SecretKey> _deriveMasterSecret(List<SecretKey> dhSecrets) async {
    final combined = <int>[];
    
    for (final secret in dhSecrets) {
      final bytes = await secret.extractBytes();
      combined.addAll(bytes);
    }

    final hash = await _sha256.hash(combined);
    return SecretKey(hash.bytes);
  }

  Future<SecretKey> _deriveKey(SecretKey masterSecret, String purpose) async {
    final masterBytes = await masterSecret.extractBytes();
    final purposeBytes = utf8.encode(purpose);
    
    final hash = await _sha256.hash([...masterBytes, ...purposeBytes]);
    return SecretKey(hash.bytes);
  }

  Future<void> ratchetKeys(String peerId) async {
    final session = _sessions[peerId];
    if (session == null) return;

    final newEphemeralKeyPair = await _x25519.newKeyPair();

    if (session.peerEphemeralKey != null) {
      final newDh = await _x25519.sharedSecretKey(
        keyPair: newEphemeralKeyPair,
        remotePublicKey: session.peerEphemeralKey!,
      );

      final newSendKey = await _deriveKey(newDh, 'send_ratchet');
      final newReceiveKey = await _deriveKey(newDh, 'receive_ratchet');

      _sessions[peerId] = session.copyWith(
        ephemeralKeyPair: newEphemeralKeyPair,
        sendKey: newSendKey,
        receiveKey: newReceiveKey,
      );

      DebugUtils.log('Keys ratcheted for $peerId', tag: 'E2E');
    }
  }

  Future<String> getFingerdebugPrint(String peerId) async {
    final session = _sessions[peerId];
    if (session?.peerIdentityKey == null) {
      return 'No session';
    }

    final peerKeyBytes = await session.peerIdentityKey!.extract();
    final hash = await _sha256.hash(peerKeyBytes.bytes);

    final bytes = hash.bytes.take(16).toList();
    final parts = <String>[];
    
    for (int i = 0; i < bytes.length; i += 2) {
      parts.add(bytes.sublist(i, i + 2).map((b) => b.toRadixString(16).padLeft(2, '0')).join());
    }
    
    return parts.join(':').toUpperCase();
  }

  void clearSession(String peerId) {
    _sessions.remove(peerId);
    DebugUtils.log('Session cleared for $peerId', tag: 'E2E');
  }

  bool hasSession(String peerId) {
    final session = _sessions[peerId];
    return session?.sendKey != null && session?.receiveKey != null;
  }

  void dispose() {
    _sessions.clear();
  }
}

class _SessionKeys {
  final SimpleKeyPair ephemeralKeyPair;
  final SimpleKeyPair myIdentityKeyPair;
  final SimplePublicKey? peerIdentityKey;
  final SimplePublicKey? peerEphemeralKey;
  final SecretKey? sendKey;
  final SecretKey? receiveKey;
  final SecretKey? masterSecret;

  _SessionKeys({
    required this.ephemeralKeyPair,
    required this.myIdentityKeyPair,
    this.peerIdentityKey,
    this.peerEphemeralKey,
    this.sendKey,
    this.receiveKey,
    this.masterSecret,
  });

  _SessionKeys copyWith({
    SimpleKeyPair? ephemeralKeyPair,
    SimpleKeyPair? myIdentityKeyPair,
    SimplePublicKey? peerIdentityKey,
    SimplePublicKey? peerEphemeralKey,
    SecretKey? sendKey,
    SecretKey? receiveKey,
    SecretKey? masterSecret,
  }) {
    return _SessionKeys(
      ephemeralKeyPair: ephemeralKeyPair ?? this.ephemeralKeyPair,
      myIdentityKeyPair: myIdentityKeyPair ?? this.myIdentityKeyPair,
      peerIdentityKey: peerIdentityKey ?? this.peerIdentityKey,
      peerEphemeralKey: peerEphemeralKey ?? this.peerEphemeralKey,
      sendKey: sendKey ?? this.sendKey,
      receiveKey: receiveKey ?? this.receiveKey,
      masterSecret: masterSecret ?? this.masterSecret,
    );
  }
}