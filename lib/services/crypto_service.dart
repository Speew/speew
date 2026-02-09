import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;
import '../core/error/error_handler.dart';

class CryptoService {
  static final _algorithm = Chacha20.poly1305Aead();
  static final _x25519 = X25519();
  static final _ed25519 = Ed25519();
  
  SimpleKeyPair? _keyPair;
  final Map<String, SecretKey> _sessionKeys = {};

  Future<void> initialize() async {
    _keyPair = await _x25519.newKeyPair();
  }

  Future<SimpleKeyPair> getKeyPair() async {
    _keyPair ??= await _x25519.newKeyPair();
    return _keyPair!;
  }

  Future<SimplePublicKey> getPublicKey() async {
    final keyPair = await getKeyPair();
    return await keyPair.extractPublicKey();
  }

  Future<SecretKey> deriveSharedSecret(SimplePublicKey peerPublicKey) async {
    final keyPair = await getKeyPair();
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: peerPublicKey,
    );
    return sharedSecret;
  }

  Future<void> setSessionKey(String peerId, SecretKey key) async {
    _sessionKeys[peerId] = key;
  }

  SecretKey? getSessionKey(String peerId) {
    return _sessionKeys[peerId];
  }

  Future<SecretKey> generateKey() async {
    return await _algorithm.newSecretKey();
  }

  Future<SecretKey> deriveKeyFromPassword(String password, [String? salt]) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    
    final actualSalt = salt ?? 'speew-salt-v2-${DateTime.now().millisecondsSinceEpoch}';
    
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode(actualSalt),
    );
    
    return secretKey;
  }

  Future<String> encryptMessage(String plaintext, String peerId) async {
    final key = _sessionKeys[peerId];
    if (key == null) {
      throw EncryptionException('No session key for peer: $peerId');
    }
    return await encrypt(plaintext, key);
  }

  Future<String> decryptMessage(String encrypted, String peerId) async {
    final key = _sessionKeys[peerId];
    if (key == null) {
      throw EncryptionException('No session key for peer: $peerId');
    }
    return await decrypt(encrypted, key);
  }

  Future<String> encrypt(String plaintext, SecretKey key) async {
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );

    final data = {
      'c': base64Encode(secretBox.cipherText),
      'n': base64Encode(secretBox.nonce),
      'm': base64Encode(secretBox.mac.bytes),
    };

    return jsonEncode(data);
  }

  Future<String> decrypt(String encryptedJson, SecretKey key) async {
    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;

    final secretBox = SecretBox(
      base64Decode(data['c'] as String),
      nonce: base64Decode(data['n'] as String),
      mac: Mac(base64Decode(data['m'] as String)),
    );

    final decrypted = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(decrypted);
  }

  Future<Map<String, dynamic>> encryptBytes(Uint8List data, SecretKey key) async {
    final secretBox = await _algorithm.encrypt(data, secretKey: key);

    return {
      'ciphertext': secretBox.cipherText,
      'nonce': secretBox.nonce,
      'mac': secretBox.mac.bytes,
    };
  }

  Future<Uint8List> decryptBytes(Map<String, dynamic> encryptedData, SecretKey key) async {
    final secretBox = SecretBox(
      encryptedData['ciphertext'] as Uint8List,
      nonce: encryptedData['nonce'] as List<int>,
      mac: Mac(encryptedData['mac'] as List<int>),
    );

    final decrypted = await _algorithm.decrypt(secretBox, secretKey: key);
    return Uint8List.fromList(decrypted);
  }

  String hashString(String data) {
    final bytes = utf8.encode(data);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  String hashBytes(Uint8List data) {
    final digest = crypto.sha256.convert(data);
    return digest.toString();
  }

  Future<Signature> sign(String message) async {
    final keyPair = await _ed25519.newKeyPair();
    final signature = await _ed25519.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );
    return signature;
  }

  Future<bool> verify(String message, Signature signature, SimplePublicKey publicKey) async {
    return await _ed25519.verify(
      utf8.encode(message),
      signature: signature,
    );
  }

  void clearSessionKeys() {
    _sessionKeys.clear();
  }

  void clearSessionKey(String peerId) {
    _sessionKeys.remove(peerId);
  }
}