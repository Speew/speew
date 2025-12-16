import '../utils/logger_service.dart';
import '../config/app_config.dart';
import 'multipath_engine.dart';
import 'priority_queue_mesh_dispatcher.dart';

/// Otimizador de Mesh para Modo Low-Power.
/// Ajusta as configurações da Mesh quando a bateria está baixa.
class LowPowerMeshOptimizer {
  final MultiPathEngine _multiPathEngine;
  final PriorityQueueMeshDispatcher _dispatcher;

  LowPowerMeshOptimizer(this._multiPathEngine, this._dispatcher);

  /// Aplica otimizações de baixo consumo.
  void applyLowPowerMode() {
    logger.warn('Modo Low-Power ativado (Bateria < 20%). Otimizações aplicadas.', tag: 'LowPower');
    
    // 1. Reduzir multi-path
    AppConfig.maxMultiPaths = 1;
    logger.debug('Multi-Path reduzido para 1.', tag: 'LowPower');

    // 2. Reduzir prioridade de arquivos
    // Simulação: Arquivos grandes (low) são pausados
    // _dispatcher.pausePriority(MeshPriority.low);
    logger.debug('Prioridade de arquivos reduzida/pausada.', tag: 'LowPower');

    // 3. Compressão mais agressiva (simulação)
    AppConfig.minSizeForCompression = 256; // Comprime pacotes menores
    logger.debug('Compressão mínima reduzida para 256 bytes.', tag: 'LowPower');

    // 4. Pausar marketplace broadcast (simulação)
    AppConfig.marketplaceBroadcastInterval = Duration(minutes: 5);
    logger.debug('Broadcast do Marketplace reduzido para 5 minutos.', tag: 'LowPower');

    // 5. Reduzir keep-alives (simulação)
    AppConfig.keepAliveInterval = Duration(minutes: 1);
    logger.debug('Intervalo de Keep-Alive aumentado para 1 minuto.', tag: 'LowPower');
  }

  /// Restaura as configurações normais.
  void restoreNormalMode() {
    logger.info('Modo Low-Power desativado. Configurações restauradas.', tag: 'LowPower');
    
    AppConfig.maxMultiPaths = 3;
    AppConfig.minSizeForCompression = 512;
    AppConfig.marketplaceBroadcastInterval = Duration(seconds: 30);
    AppConfig.keepAliveInterval = Duration(seconds: 10);
  }
}
