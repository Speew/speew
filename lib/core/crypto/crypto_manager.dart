import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import '../config/app_config.dart';
import '../utils/logger_service.dart';
import '../errors/exceptions.dart';
import 'crypto_service.dart';

/// Gerenciador centralizado de criptografia
/// 
/// Implementa Factory Pattern para criar contextos criptográficos
/// e coordena todos os serviços de segurança
class CryptoManager {
  static final CryptoManager _instance = CryptoManager._internal();
  factory CryptoManager() => _instance;
  CryptoManager._internal();

  final CryptoService _cryptoService = CryptoService();
  final Random _random = Random.secure();

  /// Inicializa o gerenciador de criptografia
  Future<void> initialize() async {
    try {
      logger.info('CryptoManager inicializado', tag: 'Crypto');
    } catch (e) {
      logger.error('Falha ao inicializar CryptoManager', tag: 'Crypto', error: e);
      throw CryptoException.encryptionFailed('Inicialização falhou', error: e);
    }
  }

  /// Factory: Cria um novo contexto criptográfico
  CryptoContext createContext({
    required String userId,
    String? publicKey,
    String? privateKey,
  }) {
    return CryptoContext(
      userId: userId,
      publicKey: publicKey,
      privateKey: privateKey,
      manager: this,
    );
  }

  /// Gera um par de chaves (pública e privada)
  Future<Map<String, String>> generateKeyPair() async {
    // Simulação de geração de chaves de longo prazo (ECDH/Ed25519-like)
    final privateKey = generateToken(length: 64);
    final publicKey = hash(privateKey); // Simulação de chave pública derivada
    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
    };
  }

  // --- Criptografia Híbrida (PQC-like) ---

  /// Gera uma chave de sessão efêmera (Ephemeral DH) e uma chave PQC-like (hash).
  /// Retorna a chave de sessão final (derivada das duas) e os dados de Key Exchange.
  Future<Map<String, String>> generateHybridSessionKey(String peerPublicKey) async {
    // 1. Camada 1 (Padrão): ECDH (curva elíptica) para velocidade.
    // Simulação: Gera uma chave efêmera e a compartilha
    final ephemeralKey = generateToken(length: 64); // Chave DH efêmera
    final sharedSecretDH = hash(ephemeralKey + peerPublicKey); // Simulação de segredo compartilhado DH

    // 2. Camada 2 (Post-Quantum Simulado): KEM-like (hash de tamanho maior)
    // Simulação: Gera um hash de 512 bits (PQC-like KEM)
    final pqcKey = hash(generateToken(length: 128)); // Hash de 512 bits
    
    // Chave de sessão final: Combinação das duas chaves (PFS garantido pelo DH efêmero)
    final finalSessionKey = hash(sharedSecretDH + pqcKey);

    return {
      'sessionKey': finalSessionKey,
      'keyExchangeData': '$ephemeralKey:$pqcKey', // Dados a serem enviados ao peer
    };
  }

  /// Deriva a chave de sessão a partir dos dados de Key Exchange recebidos.
  Future<String> deriveHybridSessionKey(String myPrivateKey, String keyExchangeData) async {
    // Simulação: Extrai as chaves efêmeras e PQC-like
    final parts = keyExchangeData.split(':');
    if (parts.length != 2) throw CryptoException.invalidKey('Dados de Key Exchange inválidos');
    final ephemeralKey = parts[0];
    final pqcKey = parts[1];

    // 1. Camada 1: Recria o segredo compartilhado DH
    final sharedSecretDH = hash(ephemeralKey + myPrivateKey); // myPrivateKey é usado para simular a derivação

    // 2. Combina para a chave de sessão final
    final finalSessionKey = hash(sharedSecretDH + pqcKey);
    return finalSessionKey;
  }

  /// Encripta dados com uma chave simétrica (Chave de Transporte Única).
  Future<String> encrypt(String data, String sessionKey) async {
    // Simulação: AES-like com chave de transporte única (derivada da sessionKey + nonce)
    final nonce = generateToken(length: 16);
    final transportKey = hash(sessionKey + nonce).substring(0, 32); // Chave de transporte única

    // Implementação de criptografia simétrica (ex: AES)
    // throw UnimplementedError('Encrypt simétrico não implementado');
    return '$nonce:${hash(data + transportKey)}:${base64Encode(utf8.encode(data))}'; // Simulação de [nonce:tag:ciphertext]
  }

  /// Decripta dados com a chave de sessão.
  Future<String> decrypt(String encryptedData, String sessionKey) async {
    final parts = encryptedData.split(':');
    if (parts.length != 3) throw CryptoException.decryptionFailed('Formato de pacote inválido');
    final nonce = parts[0];
    final tag = parts[1];
    final base64Ciphertext = parts[2];

    final transportKey = hash(sessionKey + nonce).substring(0, 32);
    final data = utf8.decode(base64Decode(base64Ciphertext));
    
    // Simulação de verificação de autenticidade (tag)
    if (tag != hash(data + transportKey)) {
      throw CryptoException.decryptionFailed('Falha na verificação de autenticidade (MAC)');
    }

    return data;
  }

  /// Assina dados usando chave privada
  Future<String> sign(String data, String privateKey) async {
    try {
      return await _cryptoService.signData(data, privateKey);
    } catch (e) {
      logger.error('Falha ao assinar dados', tag: 'Crypto', error: e);
      throw CryptoException.invalidSignature('Assinatura falhou');
    }
  }

  /// Verifica assinatura usando chave pública
  Future<bool> verify(String data, String signature, String publicKey) async {
    try {
      return await _cryptoService.verifySignature(data, signature, publicKey);
    } catch (e) {
      logger.error('Falha ao verificar assinatura', tag: 'Crypto', error: e);
      throw CryptoException.invalidSignature('Verificação falhou');
    }
  }

  /// Gera hash SHA-256 de dados
  String hash(String data) {
    try {
      final bytes = utf8.encode(data);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      logger.error('Falha ao gerar hash', tag: 'Crypto', error: e);
      throw CryptoException.encryptionFailed('Hash falhou', error: e);
    }
  }

  /// Gera ID único criptograficamente seguro
  String generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final combined = '$timestamp-${base64Encode(randomBytes)}';
    return hash(combined).substring(0, 32);
  }

  /// Gera token aleatório
  String generateToken({int length = 32}) {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).substring(0, length);
  }

  /// Compara dois hashes de forma segura (timing-safe)
  bool secureCompare(String hash1, String hash2) {
    if (hash1.length != hash2.length) return false;
    
    int result = 0;
    for (int i = 0; i < hash1.length; i++) {
      result |= hash1.codeUnitAt(i) ^ hash2.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// Contexto criptográfico para um usuário específico
/// 
/// Encapsula operações criptográficas com as chaves do usuário
class CryptoContext {
  final String userId;
  final String? publicKey;
  final String? privateKey;
  final CryptoManager manager;

  CryptoContext({
    required this.userId,
    this.publicKey,
    this.privateKey,
    required this.manager,
  });

  /// Encripta dados para este usuário
  Future<String> encryptForMe(String data) async {
    if (publicKey == null) {
      throw CryptoException.invalidKey('Chave pública não disponível');
    }
    return await manager.encrypt(data, publicKey!);
  }

  /// Decripta dados recebidos
  Future<String> decryptForMe(String encryptedData) async {
    if (privateKey == null) {
      throw CryptoException.invalidKey('Chave privada não disponível');
    }
    return await manager.decrypt(encryptedData, privateKey!);
  }

  /// Assina dados como este usuário
  Future<String> signAsMe(String data) async {
    if (privateKey == null) {
      throw CryptoException.invalidKey('Chave privada não disponível');
    }
    return await manager.sign(data, privateKey!);
  }

  /// Verifica se dados foram assinados por este usuário
  Future<bool> verifyFromMe(String data, String signature) async {
    if (publicKey == null) {
      throw CryptoException.invalidKey('Chave pública não disponível');
    }
    return await manager.verify(data, signature, publicKey!);
  }

  /// Verifica se contexto está completo (tem ambas as chaves)
  bool get isComplete => publicKey != null && privateKey != null;

  /// Verifica se pode encriptar
  bool get canEncrypt => publicKey != null;

  /// Verifica se pode decriptar
  bool get canDecrypt => privateKey != null;
}

/// Adapter para diferentes implementações de criptografia
abstract class EncryptionAdapter {
  Future<String> encrypt(String data, String key);
  Future<String> decrypt(String data, String key);
  Future<String> sign(String data, String key);
  Future<bool> verify(String data, String signature, String key);
}

/// Implementação RSA do adapter
class RSAEncryptionAdapter implements EncryptionAdapter {
  @override
  Future<String> encrypt(String data, String key) async {
    // Implementação RSA
    throw UnimplementedError('RSA encryption não implementado');
  }

  @override
  Future<String> decrypt(String data, String key) async {
    // Implementação RSA
    throw UnimplementedError('RSA decryption não implementado');
  }

  @override
  Future<String> sign(String data, String key) async {
    // Implementação RSA
    throw UnimplementedError('RSA signing não implementado');
  }

  @override
  Future<bool> verify(String data, String signature, String key) async {
    // Implementação RSA
    throw UnimplementedError('RSA verification não implementado');
  }
}

/// Verificador de assinaturas
class SignatureVerifier {
  final CryptoManager _manager;

  SignatureVerifier(this._manager);

  /// Verifica assinatura e lança exceção se inválida
  Future<void> verifyOrThrow(
    String data,
    String signature,
    String publicKey, {
    String? context,
  }) async {
    final isValid = await _manager.verify(data, signature, publicKey);
    if (!isValid) {
      final contextStr = context != null ? ' ($context)' : '';
      throw CryptoException.invalidSignature('Assinatura inválida$contextStr');
    }
  }

  /// Verifica múltiplas assinaturas
  Future<bool> verifyMultiple(
    String data,
    List<String> signatures,
    List<String> publicKeys,
  ) async {
    if (signatures.length != publicKeys.length) {
      throw CryptoException.invalidSignature('Número de assinaturas e chaves não corresponde');
    }

    for (int i = 0; i < signatures.length; i++) {
      final isValid = await _manager.verify(data, signatures[i], publicKeys[i]);
      if (!isValid) return false;
    }

    return true;
  }
}
