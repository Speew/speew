import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../utils/logger_service.dart';

enum CompressionLevel {
  none,
  lowCost, // Prioriza CPU baixa, compressão moderada (ideal para repasse)
  normal, // Equilíbrio
  aggressive, // Prioriza compressão máxima, uso de CPU mais alto
}

/// Motor de Compressão para otimizar o tráfego de dados e o uso de recursos.
class CompressionEngine {
  static CompressionLevel _currentLevel = CompressionLevel.normal;
  static const int _minSizeForCompression = 512; // Mínimo de bytes para compressão

  static CompressionLevel get currentLevel => _currentLevel;

  /// Define o nível de compressão global.
  static void setCompressionLevel(CompressionLevel level) {
    _currentLevel = level;
    logger.info('Nível de compressão definido para: $level', tag: 'CompressionEngine');
  }

  /// Comprime os dados com base no nível atual.
  Uint8List compress(String data) {
    final bytes = utf8.encode(data);
    if (bytes.length < _minSizeForCompression || _currentLevel == CompressionLevel.none) {
      logger.debug('Dados pequenos ou compressão desativada, sem compressão.', tag: 'Compression');
      return Uint8List.fromList(bytes);
    }

    // Lógica de compressão baseada no nível
    Uint8List compressedBytes;
    int compressionLevel;

    switch (_currentLevel) {
      case CompressionLevel.lowCost:
        // Nível 1: Compressão mais rápida, ideal para repasse (relay mode)
        compressionLevel = 1;
        break;
      case CompressionLevel.normal:
        // Nível 6: Equilíbrio entre velocidade e taxa de compressão
        compressionLevel = 6;
        break;
      case CompressionLevel.aggressive:
        // Nível 9: Compressão máxima, maior uso de CPU
        compressionLevel = 9;
        break;
      case CompressionLevel.none:
        return Uint8List.fromList(bytes);
    }

    // Usamos GZipEncoder para simular a compressão com diferentes níveis
    compressedBytes = GZipEncoder(level: compressionLevel).encode(bytes);
    
    final reduction = 100 - (compressedBytes.length / bytes.length) * 100;
    logger.info('Compressão aplicada (Nível $compressionLevel): ${bytes.length} -> ${compressedBytes.length} bytes (${reduction.toStringAsFixed(1)}% de redução)', tag: 'Compression');

    // Adiciona um prefixo para indicar que o pacote está comprimido
    final prefix = Uint8List.fromList([0x01]); // 0x01 = Comprimido
    return Uint8List.fromList(prefix + compressedBytes);
  }

  /// Descomprime os dados se o prefixo indicar compressão.
  String decompress(Uint8List compressedData) {
    if (compressedData.isEmpty) return '';

    // Verifica o prefixo de compressão
    if (compressedData[0] == 0x01) {
      final dataWithoutPrefix = compressedData.sublist(1);
      
      try {
        // Simulação de descompressão
        final decompressedBytes = GZipDecoder().decodeBytes(dataWithoutPrefix);
        final originalData = utf8.decode(decompressedBytes);
        logger.debug('Descompressão bem-sucedida.', tag: 'Compression');
        return originalData;
      } catch (e) {
        logger.error('Falha na descompressão: $e', tag: 'Compression');
        // Se falhar, retorna o dado original (sem o prefixo)
        return utf8.decode(dataWithoutPrefix);
      }
    }

    // Se não houver prefixo, retorna o original
    return utf8.decode(compressedData);
  }
}
