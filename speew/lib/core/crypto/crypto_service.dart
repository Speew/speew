import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart';

/// Serviço de criptografia para a rede P2P
/// Implementa XChaCha20-Poly1305 para mensagens/arquivos e Ed25519 para assinaturas
class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  /// Algoritmo de criptografia simétrica XChaCha20-Poly1305
  final _xchacha20 = Xchacha20.poly1305Aead();
  
  /// Algoritmo de assinatura digital Ed25519
  final _ed25519 = Ed25519();

  // ==================== GERAÇÃO DE CHAVES ====================

  /// Gera um par de chaves Ed25519 (pública e privada)
  /// Retorna um Map com 'publicKey' e 'privateKey' em base64
  Future<Map<String, String>> generateKeyPair() async {
    final keyPair = await _ed25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    
    return {
      'publicKey': base64Encode(publicKey.bytes),
      'privateKey': base64Encode(privateKeyBytes),
    };
  }

  /// Gera uma chave simétrica aleatória para XChaCha20
  Future<String> generateSymmetricKey() async {
    final secretKey = await _xchacha20.newSecretKey();
    final bytes = await secretKey.extractBytes();
    return base64Encode(bytes);
  }

  /// Gera um nonce aleatório de 24 bytes para XChaCha20
  List<int> generateNonce() {
    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256))));
    return List.generate(24, (_) => secureRandom.nextUint8());
  }

  // ==================== CRIPTOGRAFIA SIMÉTRICA ====================

  /// Criptografa dados usando XChaCha20-Poly1305
  /// Retorna um Map com 'ciphertext', 'nonce' e 'mac' em base64
  Future<Map<String, String>> encryptData(String plaintext, String symmetricKeyBase64) async {
    try {
      final keyBytes = base64Decode(symmetricKeyBase64);
      final secretKey = SecretKey(keyBytes);
      final nonce = generateNonce();
      
      final secretBox = await _xchacha20.encrypt(
        utf8.encode(plaintext),
        secretKey: secretKey,
        nonce: nonce,
      );
      
      return {
        'ciphertext': base64Encode(secretBox.cipherText),
        'nonce': base64Encode(secretBox.nonce),
        'mac': base64Encode(secretBox.mac.bytes),
      };
    } catch (e) {
      throw Exception('Erro ao criptografar dados: $e');
    }
  }

  /// Descriptografa dados usando XChaCha20-Poly1305
  Future<String> decryptData(
    String ciphertextBase64,
    String nonceBase64,
    String macBase64,
    String symmetricKeyBase64,
  ) async {
    try {
      final keyBytes = base64Decode(symmetricKeyBase64);
      final secretKey = SecretKey(keyBytes);
      final ciphertext = base64Decode(ciphertextBase64);
      final nonce = base64Decode(nonceBase64);
      final mac = Mac(base64Decode(macBase64));
      
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);
      final plaintext = await _xchacha20.decrypt(secretBox, secretKey: secretKey);
      
      return utf8.decode(plaintext);
    } catch (e) {
      throw Exception('Erro ao descriptografar dados: $e');
    }
  }

  /// Criptografa bytes (para arquivos) usando XChaCha20-Poly1305
  Future<Map<String, dynamic>> encryptBytes(List<int> data, String symmetricKeyBase64) async {
    try {
      final keyBytes = base64Decode(symmetricKeyBase64);
      final secretKey = SecretKey(keyBytes);
      final nonce = generateNonce();
      
      final secretBox = await _xchacha20.encrypt(
        data,
        secretKey: secretKey,
        nonce: nonce,
      );
      
      return {
        'ciphertext': secretBox.cipherText,
        'nonce': secretBox.nonce,
        'mac': secretBox.mac.bytes,
      };
    } catch (e) {
      throw Exception('Erro ao criptografar bytes: $e');
    }
  }

  /// Descriptografa bytes (para arquivos)
  Future<List<int>> decryptBytes(
    List<int> ciphertext,
    List<int> nonce,
    List<int> mac,
    String symmetricKeyBase64,
  ) async {
    try {
      final keyBytes = base64Decode(symmetricKeyBase64);
      final secretKey = SecretKey(keyBytes);
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
      
      return await _xchacha20.decrypt(secretBox, secretKey: secretKey);
    } catch (e) {
      throw Exception('Erro ao descriptografar bytes: $e');
    }
  }

  // ==================== ASSINATURAS DIGITAIS ====================

  /// Assina dados usando Ed25519
  Future<String> signData(String data, String privateKeyBase64) async {
    try {
      final privateKeyBytes = base64Decode(privateKeyBase64);
      final keyPair = await _ed25519.newKeyPairFromSeed(privateKeyBytes);
      
      final signature = await _ed25519.sign(
        utf8.encode(data),
        keyPair: keyPair,
      );
      
      return base64Encode(signature.bytes);
    } catch (e) {
      throw Exception('Erro ao assinar dados: $e');
    }
  }

  /// Verifica uma assinatura Ed25519
  Future<bool> verifySignature(
    String data,
    String signatureBase64,
    String publicKeyBase64,
  ) async {
    try {
      final signatureBytes = base64Decode(signatureBase64);
      final publicKeyBytes = base64Decode(publicKeyBase64);
      final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      
      final signature = Signature(signatureBytes, publicKey: publicKey);
      
      final isValid = await _ed25519.verify(
        utf8.encode(data),
        signature: signature,
      );
      
      return isValid;
    } catch (e) {
      return false;
    }
  }

  // ==================== HASHING ====================

  /// Calcula o hash SHA-256 de dados
  String sha256Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Calcula o hash SHA-256 de bytes (para checksums de blocos)
  String sha256HashBytes(List<int> data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  // ==================== NOISE PROTOCOL (simplificado) ====================

  /// Implementação simplificada do Noise Protocol para troca de chaves
  /// Em produção, usar uma biblioteca completa do Noise Protocol
  Future<Map<String, String>> performNoiseHandshake(String peerPublicKeyBase64) async {
    // Gera chave efêmera para a sessão
    final ephemeralKey = await generateSymmetricKey();
    
    // Em uma implementação real do Noise Protocol:
    // 1. Troca de chaves públicas efêmeras
    // 2. Derivação de chaves de sessão usando ECDH
    // 3. Autenticação mútua
    
    // Esta é uma versão simplificada para MVP
    return {
      'sessionKey': ephemeralKey,
      'peerPublicKey': peerPublicKeyBase64,
    };
  }

  // ==================== UTILITÁRIOS ====================

  /// Gera um ID único usando timestamp e random
  String generateUniqueId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = List.generate(8, (_) => DateTime.now().microsecondsSinceEpoch % 256);
    final combined = '$timestamp${base64Encode(random)}';
    return sha256Hash(combined).substring(0, 32);
  }
}
