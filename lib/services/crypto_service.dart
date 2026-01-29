import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static final _algorithm = Chacha20.poly1305Aead();
  
  // Gerar chave simétrica
  Future<SecretKey> generateKey() async {
    return await _algorithm.newSecretKey();
  }

  // Gerar chave a partir de senha
  Future<SecretKey> deriveKeyFromPassword(String password) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: 256,
    );
    
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode('speew-salt-12345678'), // Em produção, usar salt aleatório
    );
    
    return secretKey;
  }

  // Encriptar texto
  Future<String> encrypt(String plaintext, SecretKey key) async {
    try {
      final secretBox = await _algorithm.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
      );

      // Retornar como JSON base64
      final data = {
        'ciphertext': base64Encode(secretBox.cipherText),
        'nonce': base64Encode(secretBox.nonce),
        'mac': base64Encode(secretBox.mac.bytes),
      };

      return jsonEncode(data);
    } catch (e) {
      throw Exception('Erro ao encriptar: $e');
    }
  }

  // Decriptar texto
  Future<String> decrypt(String encryptedJson, SecretKey key) async {
    try {
      final data = jsonDecode(encryptedJson) as Map<String, dynamic>;

      final secretBox = SecretBox(
        base64Decode(data['ciphertext'] as String),
        nonce: base64Decode(data['nonce'] as String),
        mac: Mac(base64Decode(data['mac'] as String)),
      );

      final decrypted = await _algorithm.decrypt(
        secretBox,
        secretKey: key,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('Erro ao decriptar: $e');
    }
  }

  // Encriptar bytes (para arquivos)
  Future<Map<String, dynamic>> encryptBytes(
    Uint8List data,
    SecretKey key,
  ) async {
    try {
      final secretBox = await _algorithm.encrypt(
        data,
        secretKey: key,
      );

      return {
        'ciphertext': secretBox.cipherText,
        'nonce': secretBox.nonce,
        'mac': secretBox.mac.bytes,
      };
    } catch (e) {
      throw Exception('Erro ao encriptar bytes: $e');
    }
  }

  // Decriptar bytes
  Future<Uint8List> decryptBytes(
    Map<String, dynamic> encryptedData,
    SecretKey key,
  ) async {
    try {
      final secretBox = SecretBox(
        encryptedData['ciphertext'] as Uint8List,
        nonce: encryptedData['nonce'] as List<int>,
        mac: Mac(encryptedData['mac'] as List<int>),
      );

      final decrypted = await _algorithm.decrypt(
        secretBox,
        secretKey: key,
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw Exception('Erro ao decriptar bytes: $e');
    }
  }
}
