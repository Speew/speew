import 'dart:math';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';
import '../config/app_config.dart';

/// Serviço para o Modo Ultra Stealth.
/// Aplica técnicas de ofuscação e randomização para dificultar o rastreamento.
class StealthModeService {
  final P2PService _p2pService;
  final Random _random = Random();

  StealthModeService(this._p2pService);

  /// Processa o pacote de dados para o modo stealth.
  String processStealthPacket(String originalData) {
    if (!AppConfig.stealthMode) {
      return originalData;
    }

    // 1. Pacotes com tamanho padronizado (Padding)
    final targetSize = 1024; // Exemplo: todos os pacotes têm 1KB
    final currentSize = originalData.length;
    
    if (currentSize < targetSize) {
      final paddingSize = targetSize - currentSize;
      final padding = List.generate(paddingSize, (_) => 'X').join(); // Padding com 'X'
      originalData += padding;
      logger.debug('Pacote padronizado com padding de $paddingSize bytes.', tag: 'Stealth');
    }

    // 2. Ofuscação leve no header (simulação)
    final obfuscatedHeader = 'STLTH${_random.nextInt(999)}';
    final stealthData = '$obfuscatedHeader:$originalData';
    
    // 3. Randomização de rota (simulação de seleção de rota não-ótima)
    _p2pService.randomizeNextRoute();

    return stealthData;
  }

  /// Aplica um jitter (tempo de envio aleatório) antes de enviar.
  Future<void> applyJitter() async {
    if (!AppConfig.stealthMode) {
      return;
    }
    
    final jitterMs = _random.nextInt(200) + 50; // Jitter entre 50ms e 250ms
    logger.debug('Aplicando jitter de $jitterMs ms.', tag: 'Stealth');
    await Future.delayed(Duration(milliseconds: jitterMs));
  }

  /// Envia keep-alives falsos em intervalos aleatórios.
  void sendFakeKeepAlives() {
    if (!AppConfig.stealthMode) {
      return;
    }
    
    // Simulação: Envia keep-alives falsos a cada 5-15 segundos
    Timer.periodic(Duration(seconds: _random.nextInt(10) + 5), (timer) {
      if (!AppConfig.stealthMode) {
        timer.cancel();
        return;
      }
      final fakePeerId = 'FAKE_PEER_${_random.nextInt(9999)}';
      _p2pService.sendData(
        peerId: fakePeerId,
        data: 'FAKE_KEEPALIVE',
        metadata: {'stealth': true},
      );
      logger.debug('Enviando keep-alive falso para $fakePeerId', tag: 'Stealth');
    });
  }
}
