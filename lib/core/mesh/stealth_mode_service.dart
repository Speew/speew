// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// '../utils/logger_service.dart'
class LoggerService {
  void info(String message, {String? tag, dynamic error}) => print('[INFO][${tag ?? 'App'}] $message ${error ?? ''}');
  void warn(String message, {String? tag, dynamic error}) => print('[WARN][${tag ?? 'App'}] $message ${error ?? ''}');
  void error(String message, {String? tag, dynamic error}) => print('[ERROR][${tag ?? 'App'}] $message ${error ?? ''}');
  void debug(String message, {String? tag, dynamic error}) {
    if (kDebugMode) print('[DEBUG][${tag ?? 'App'}] $message ${error ?? ''}');
  }
}
final logger = LoggerService();

// '../config/app_config.dart'
class AppConfig {
  static bool stealthMode = true; 
}

// '../p2p/p2p_service.dart'
class P2PService {
  void randomizeNextRoute() {
    logger.debug('P2PService: Rota randomizada (não-ótima) selecionada.', tag: 'P2P');
  }

  Future<void> sendData({
    required String peerId,
    required String data,
    Map<String, dynamic>? metadata,
  }) async {
    if (metadata?['stealth'] == true) {
      // Simulação: Não espera e não loga como sucesso real para tráfego decoy
    } else {
      await Future.delayed(Duration(milliseconds: 10));
    }
    logger.debug('P2PService: Dados enviados para $peerId.', tag: 'P2P');
  }
}

// ==================== StealthModeService ====================

/// Serviço para o Modo Ultra Stealth.
/// Aplica técnicas de ofuscação e randomização para dificultar o rastreamento.
class StealthModeService {
  final P2PService _p2pService;
  final Random _random = Random();
  Timer? _fakeKeepAliveTimer;

  StealthModeService(this._p2pService) {
    // Inicia a randomização de keep-alives se o modo estiver ativo ao inicializar
    if (AppConfig.stealthMode) {
      sendFakeKeepAlives();
    }
  }

  /// Processa o pacote de dados para o modo stealth.
  String processStealthPacket(String originalData) {
    if (!AppConfig.stealthMode) {
      return originalData;
    }

    // 1. Pacotes com tamanho padronizado (Padding)
    const targetSize = 1024; 
    final currentSize = originalData.length;
    
    if (currentSize < targetSize) {
      final paddingSize = targetSize - currentSize;
      final padding = List.generate(paddingSize, (_) => 'X').join(); 
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
    
    final jitterMs = _random.nextInt(200) + 50; 
    logger.debug('Aplicando jitter de $jitterMs ms.', tag: 'Stealth');
    await Future.delayed(Duration(milliseconds: jitterMs));
  }

  /// Envia keep-alives falsos em intervalos aleatórios.
  void sendFakeKeepAlives() {
    if (!AppConfig.stealthMode) {
      _fakeKeepAliveTimer?.cancel();
      return;
    }
    
    // Cancela o timer existente antes de criar um novo para evitar duplicação
    _fakeKeepAliveTimer?.cancel(); 

    // Simulação: Envia keep-alives falsos a cada 5-15 segundos
    _fakeKeepAliveTimer = Timer.periodic(Duration(seconds: _random.nextInt(10) + 5), (timer) {
      if (!AppConfig.stealthMode) {
        timer.cancel();
        return;
      }
      final fakePeerId = 'FAKE_PEER_${_random.nextInt(9999)}';
      _p2pService.sendData(
        peerId: fakePeerId,
        data: 'FAKE_KEEPALIVE',
        metadata: {'stealth': true}, // Marcador para o P2PService
      );
      logger.debug('Enviando keep-alive falso para $fakePeerId (Decoy traffic)', tag: 'Stealth');
    });
  }
  
  /// Lógica para desligar o modo stealth e o tráfego decoy
  void disableStealthMode() {
    AppConfig.stealthMode = false;
    _fakeKeepAliveTimer?.cancel();
    logger.info('Modo Stealth desativado. Tráfego decoy parado.', tag: 'Stealth');
  }
  
  void dispose() {
    _fakeKeepAliveTimer?.cancel();
  }
}
