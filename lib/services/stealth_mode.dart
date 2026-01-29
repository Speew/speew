import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import '../core/utils.dart';

/// Modo Stealth - Torna comunicação indetectável e indistinguível de tráfego normal
class StealthMode {
  final Random _random = Random.secure();
  bool _enabled = false;
  Timer? _coverTrafficTimer;
  
  // Configurações de stealth
  static const int minPadding = 32;
  static const int maxPadding = 1024;
  static const int minDelay = 50;
  static const int maxDelay = 500;
  static const int coverTrafficInterval = 7000; // 7 segundos
  static const double coverTrafficProbability = 0.25; // 25%
  
  final StreamController<StealthPacket> _coverTrafficController =
      StreamController<StealthPacket>.broadcast();

  Stream<StealthPacket> get coverTrafficStream => _coverTrafficController.stream;
  bool get isEnabled => _enabled;

  /// Ativar modo stealth
  void enable() {
    if (_enabled) return;
    
    _enabled = true;
    _startCoverTraffic();
    
    DebugUtils.log('⚠️ STEALTH MODE ACTIVATED', tag: 'STEALTH');
  }

  /// Desativar modo stealth
  void disable() {
    if (!_enabled) return;
    
    _enabled = false;
    _stopCoverTraffic();
    
    DebugUtils.log('STEALTH MODE DEACTIVATED', tag: 'STEALTH');
  }

  /// Processar dados de saída (adicionar ofuscação)
  Future<StealthPacket> obfuscate(Uint8List data, String peerId) async {
    if (!_enabled) {
      return StealthPacket(
        data: data,
        peerId: peerId,
        isCoverTraffic: false,
      );
    }

    // 1. Traffic Shaping - Adicionar padding para ofuscar tamanho
    final padded = _addTrafficShaping(data);

    // 2. Timing Obfuscation - Adicionar delay aleatório
    await _addTimingJitter();

    // 3. Protocol Mimicry - Fazer parecer HTTPS
    final mimicked = _addProtocolMimicry(padded);

    // 4. Packet Fragmentation - Quebrar em fragmentos
    final fragments = _fragmentPacket(mimicked);

    DebugUtils.log('Packet obfuscated: ${data.length}B → ${mimicked.length}B', tag: 'STEALTH');

    return StealthPacket(
      data: fragments[0], // Retornar primeiro fragmento
      peerId: peerId,
      isCoverTraffic: false,
      totalFragments: fragments.length,
    );
  }

  /// Remover ofuscação de dados recebidos
  Future<Uint8List?> deobfuscate(StealthPacket packet) async {
    if (!_enabled) {
      return packet.data;
    }

    // Verificar se é cover traffic
    if (packet.isCoverTraffic) {
      DebugUtils.log('Cover traffic received (discarded)', tag: 'STEALTH');
      return null;
    }

    // 1. Remover protocol mimicry
    final unMimicked = _removeProtocolMimicry(packet.data);

    // 2. Remover padding
    final unPadded = _removeTrafficShaping(unMimicked);

    return unPadded;
  }

  /// Traffic Shaping - Adicionar padding aleatório
  Uint8List _addTrafficShaping(Uint8List data) {
    // Calcular tamanho de padding aleatório
    final paddingSize = minPadding + _random.nextInt(maxPadding - minPadding);
    
    // Gerar bytes aleatórios de padding
    final padding = Uint8List(paddingSize);
    for (int i = 0; i < paddingSize; i++) {
      padding[i] = _random.nextInt(256);
    }

    // Formato: [tamanho_original(4)][dados][padding]
    final result = Uint8List(4 + data.length + paddingSize);
    final view = ByteData.view(result.buffer);
    
    view.setUint32(0, data.length);
    result.setRange(4, 4 + data.length, data);
    result.setRange(4 + data.length, result.length, padding);

    return result;
  }

  /// Remover padding
  Uint8List _removeTrafficShaping(Uint8List padded) {
    if (padded.length < 4) return padded;

    final view = ByteData.view(padded.buffer);
    final originalSize = view.getUint32(0);

    if (originalSize > padded.length - 4) {
      return padded; // Dados corrompidos
    }

    return padded.sublist(4, 4 + originalSize);
  }

  /// Timing Obfuscation - Delay aleatório
  Future<void> _addTimingJitter() async {
    final delay = minDelay + _random.nextInt(maxDelay - minDelay);
    await Future.delayed(Duration(milliseconds: delay));
  }

  /// Protocol Mimicry - Fazer parecer HTTPS
  Uint8List _addProtocolMimicry(Uint8List data) {
    // Simular TLS handshake ou HTTP request
    final headers = [
      'GET /api/sync HTTP/1.1',
      'Host: cdn.cloudflare.com',
      'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Accept: application/json, text/plain, */*',
      'Accept-Language: en-US,en;q=0.9',
      'Accept-Encoding: gzip, deflate, br',
      'Connection: keep-alive',
      'Cache-Control: no-cache',
      '',
    ];

    final headerStr = headers.join('\r\n');
    final headerBytes = utf8.encode(headerStr);

    // Combinar: [headers HTTP][dados]
    final result = Uint8List(headerBytes.length + data.length);
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, data);

    return result;
  }

  /// Remover protocol mimicry
  Uint8List _removeProtocolMimicry(Uint8List data) {
    // Procurar fim dos headers HTTP (\r\n\r\n)
    for (int i = 0; i < data.length - 3; i++) {
      if (data[i] == 13 && data[i + 1] == 10 &&
          data[i + 2] == 13 && data[i + 3] == 10) {
        return data.sublist(i + 4);
      }
    }

    return data; // Sem headers encontrados
  }

  /// Fragmentar pacote em chunks menores
  List<Uint8List> _fragmentPacket(Uint8List data) {
    const fragmentSize = 512;
    
    if (data.length <= fragmentSize) {
      return [data];
    }

    final fragments = <Uint8List>[];
    int offset = 0;

    while (offset < data.length) {
      final remaining = data.length - offset;
      final size = remaining < fragmentSize ? remaining : fragmentSize;
      fragments.add(data.sublist(offset, offset + size));
      offset += size;
    }

    return fragments;
  }

  /// Iniciar geração de cover traffic (tráfego falso)
  void _startCoverTraffic() {
    _coverTrafficTimer?.cancel();
    
    _coverTrafficTimer = Timer.periodic(
      Duration(milliseconds: coverTrafficInterval),
      (_) => _generateCoverTraffic(),
    );
  }

  /// Parar cover traffic
  void _stopCoverTraffic() {
    _coverTrafficTimer?.cancel();
    _coverTrafficTimer = null;
  }

  /// Gerar tráfego de cobertura (dummy packets)
  void _generateCoverTraffic() {
    // Gerar apenas com certa probabilidade
    if (_random.nextDouble() > coverTrafficProbability) {
      return;
    }

    // Gerar dados aleatórios
    final size = 128 + _random.nextInt(512);
    final dummyData = Uint8List(size);
    for (int i = 0; i < size; i++) {
      dummyData[i] = _random.nextInt(256);
    }

    // Adicionar padding e mimicry
    final padded = _addTrafficShaping(dummyData);
    final mimicked = _addProtocolMimicry(padded);

    _coverTrafficController.add(StealthPacket(
      data: mimicked,
      peerId: 'broadcast',
      isCoverTraffic: true,
    ));

    DebugUtils.log('Cover traffic generated', tag: 'STEALTH');
  }

  /// Análise de tráfego (para debugging)
  Map<String, dynamic> getTrafficAnalysis() {
    return {
      'enabled': _enabled,
      'padding_range': '$minPadding-$maxPadding bytes',
      'timing_jitter': '$minDelay-${maxDelay}ms',
      'cover_interval': '${coverTrafficInterval}ms',
      'cover_probability': '${(coverTrafficProbability * 100).toInt()}%',
      'mimicry': 'HTTPS/TLS',
    };
  }

  void dispose() {
    _stopCoverTraffic();
    _coverTrafficController.close();
  }
}

class StealthPacket {
  final Uint8List data;
  final String peerId;
  final bool isCoverTraffic;
  final int? totalFragments;
  final int? fragmentIndex;

  StealthPacket({
    required this.data,
    required this.peerId,
    required this.isCoverTraffic,
    this.totalFragments,
    this.fragmentIndex,
  });

  bool get isFragmented => (totalFragments ?? 1) > 1;
}

/// Análise de padrões de tráfego (para detecção)
class TrafficAnalyzer {
  final List<DateTime> _packetTimes = [];
  final List<int> _packetSizes = [];
  static const int maxHistory = 100;

  void recordPacket(int size) {
    _packetTimes.add(DateTime.now());
    _packetSizes.add(size);

    if (_packetTimes.length > maxHistory) {
      _packetTimes.removeAt(0);
      _packetSizes.removeAt(0);
    }
  }

  /// Calcular entropia do tamanho dos pacotes
  double calculateSizeEntropy() {
    if (_packetSizes.isEmpty) return 0.0;

    final freq = <int, int>{};
    for (final size in _packetSizes) {
      freq[size] = (freq[size] ?? 0) + 1;
    }

    double entropy = 0.0;
    final total = _packetSizes.length;

    for (final count in freq.values) {
      final p = count / total;
      entropy -= p * (p > 0 ? (p * log(p) / log(2)) : 0);
    }

    return entropy;
  }

  /// Calcular variância dos intervalos entre pacotes
  double calculateTimingVariance() {
    if (_packetTimes.length < 2) return 0.0;

    final intervals = <int>[];
    for (int i = 1; i < _packetTimes.length; i++) {
      final diff = _packetTimes[i].difference(_packetTimes[i - 1]);
      intervals.add(diff.inMilliseconds);
    }

    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals
        .map((i) => pow(i - mean, 2))
        .reduce((a, b) => a + b) / intervals.length;

    return variance;
  }

  Map<String, dynamic> getAnalysis() {
    return {
      'packet_count': _packetSizes.length,
      'size_entropy': calculateSizeEntropy().toStringAsFixed(2),
      'timing_variance': calculateTimingVariance().toStringAsFixed(2),
      'avg_size': _packetSizes.isEmpty 
          ? 0 
          : (_packetSizes.reduce((a, b) => a + b) / _packetSizes.length).round(),
    };
  }
}

double log(double x) => x > 0 ? (x.toString().length * 0.3).toDouble() : 0.0;
