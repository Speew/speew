import 'dart:math';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';
import '../config/app_config.dart';

/// Serviço para o Modo Ultra Stealth.
/// Aplica técnicas de ofuscação e randomização para dificultar o rastreamento.
class TrafficObfuscator {
  final P2PService _p2pService;
  bool _extremeObfuscation = false; // Toggle Manual: "Modo de Ofuscação Extrema"

  void setExtremeObfuscation(bool enabled) {
    _extremeObfuscation = enabled;
    logger.info('Modo de Ofuscação Extrema ${enabled ? 'ativado' : 'desativado'}.', tag: 'Obfuscator');
  }
  final Random _random = Random();

  TrafficObfuscator(this._p2pService);

  /// Processa o pacote de dados para o modo stealth (Ofuscação V2).
  String processObfuscatedPacket(String originalData) {
    final bool isActive = AppConfig.stealthMode || _extremeObfuscation;
    if (!isActive) {
      return originalData;
    }

    // 1. Packet Padding (Preenchimento)
    final currentSize = originalData.length;
    
    // Tamanhos discretos para Packet Padding (MTU-like)
    // 1500 bytes (MTU) é o máximo, usaremos 3 tamanhos discretos:
    const int smallSize = 512;
    const int mediumSize = 1024;
    const int largeSize = 1500;
    
    final List<int> discreteSizes = [smallSize, mediumSize, largeSize];
    
    // Escolhe o menor tamanho discreto que é maior que o pacote atual
    int targetSize = discreteSizes.firstWhere(
      (size) => size >= currentSize,
      orElse: () => largeSize, // Se for maior que o maior, usa o maior
    );

    // Se o modo extremo estiver ativo, força o padding máximo (1500 bytes)
    if (_extremeObfuscation) {
      targetSize = largeSize;
    }
    
    if (currentSize < targetSize) {
      final paddingSize = targetSize - currentSize;
      // Padding com bytes aleatórios para evitar análise de padrões
      final padding = List.generate(paddingSize, (_) => String.fromCharCode(_random.nextInt(256))).join();
      originalData += padding;
      logger.debug('Pacote padronizado com padding de $paddingSize bytes (Tamanho Final: $targetSize).', tag: 'Obfuscator');
    }

    // 2. Ofuscação leve no header (simulação)
    final obfuscatedHeader = 'STLTHV2${_random.nextInt(999)}';
    final obfuscatedData = '$obfuscatedHeader:$originalData';
    
    // 3. Randomização de rota (simulação de seleção de rota não-ótima)
    _p2pService.randomizeNextRoute();

    return obfuscatedData;
  }

  /// Aplica um jitter (tempo de envio aleatório) antes de enviar.
  Future<void> applyJitter() async {
    final bool isActive = AppConfig.stealthMode || _extremeObfuscation;
    if (!isActive) {
      return;
    }
    
    // Timing Jitter: Atraso aleatório de 5ms a 50ms (padrão)
    int maxJitter = 50;
    int minJitter = 5;

    // Se o modo extremo estiver ativo, usa Jitter Alto (ex: 50ms a 250ms)
    if (_extremeObfuscation) {
      maxJitter = 250;
      minJitter = 50;
    }

    final jitterMs = _random.nextInt(maxJitter - minJitter) + minJitter;
    logger.debug('Aplicando jitter de $jitterMs ms.', tag: 'Obfuscator');
    await Future.delayed(Duration(milliseconds: jitterMs));
  }

  /// Envia keep-alives falsos em intervalos aleatórios.
  void sendFakeKeepAlives() {
    final bool isActive = AppConfig.stealthMode || _extremeObfuscation;
    if (!isActive) {
      return;
    }
    
    // Simulação: Envia keep-alives falsos a cada 5-15 segundos
    Timer.periodic(Duration(seconds: _random.nextInt(10) + 5), (timer) {
      final bool currentActive = AppConfig.stealthMode || _extremeObfuscation;
      if (!currentActive) {
        timer.cancel();
        return;
      }
      final fakePeerId = 'FAKE_PEER_${_random.nextInt(9999)}';
      _p2pService.sendData(
        peerId: fakePeerId,
        data: 'FAKE_KEEPALIVE',
        metadata: {'stealth': true},
      );
      logger.debug('Enviando keep-alive falso para $fakePeerId', tag: 'Obfuscator');
    });
  }
}
