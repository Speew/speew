import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final _algorithm = Chacha20.poly1305Aead();
  SecretKey? _secretKey;

  Future<void> initialize() async {
    _secretKey = await _algorithm.newSecretKey();
  }

  Future<String> encrypt(String plaintext) async {
    if (_secretKey == null) {
      throw Exception('CryptoService not initialized');
    }

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _secretKey!,
    );

    final combined = <int>[];
    combined.addAll(secretBox.nonce);
    combined.addAll(secretBox.cipherText);
    combined.addAll(secretBox.mac.bytes);

    return base64Encode(combined);
  }

  Future<String> decrypt(String ciphertext) async {
    if (_secretKey == null) {
      throw Exception('CryptoService not initialized');
    }

    final combined = base64Decode(ciphertext);
    final nonce = combined.sublist(0, 12);
    final cipher = combined.sublist(12, combined.length - 16);
    final mac = combined.sublist(combined.length - 16);

    final secretBox = SecretBox(
      cipher,
      nonce: nonce,
      mac: Mac(mac),
    );

    final plaintext = await _algorithm.decrypt(
      secretBox,
      secretKey: _secretKey!,
    );

    return utf8.decode(plaintext);
  }
}
