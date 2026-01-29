import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import '../core/utils.dart';

/// Serviço Stealth - Torna comunicação indetectável
/// Features:
/// - Traffic padding (ofuscar tamanho de mensagens)
/// - Timing jitter (ofuscar padrões temporais)
/// - Dummy traffic (gerar tráfego falso)
/// - Message fragmentation (quebrar padrões)
/// - Protocol obfuscation (parecer tráfego comum)
class StealthService {
  final Random _random = Random.secure();
  bool _isEnabled = false;
  Timer? _dummyTrafficTimer;
  
  // Configurações
  static const int minPaddingSize = 16;
  static const int maxPaddingSize = 512;
  static const int minJitterMs = 10;
  static const int maxJitterMs = 500;
  static const int dummyTrafficIntervalMs = 5000; // 5 segundos
  static const double dummyTrafficProbability = 0.3; // 30% chance

  final StreamController<StealthPacket> _outgoingController =
      StreamController<StealthPacket>.broadcast();

  Stream<StealthPacket> get outgoingStream => _outgoingController.stream;

  /// Ativar modo stealth
  void enable() {
    if (_isEnabled) return;
    
    _isEnabled = true;
    _startDummyTraffic();
    
    DebugUtils.log('Stealth mode ENABLED', tag: 'STEALTH');
  }

  /// Desativar modo stealth
  void disable() {
    if (!_isEnabled) return;
    
    _isEnabled = false;
    _stopDummyTraffic();
    
    DebugUtils.log('Stealth mode DISABLED', tag: 'STEALTH');
  }

  /// Processar mensagem de saída (adicionar ofuscação)
  Future<StealthPacket> processOutgoing(
    String peerId,
    Uint8List data,
  ) async {
    if (!_isEnabled) {
      return StealthPacket(
        peerId: peerId,
        data: data,
        isDummy: false,
      );
    }

    // 1. Fragmentar se necessário
    final fragments = _fragmentData(data);

    // 2. Adicionar padding para ofuscar tamanho
    final paddedFragments = fragments.map(_addPadding).toList();

    // 3. Adicionar jitter temporal
    await _applyJitter();

    // 4. Ofuscar protocolo (adicionar headers falsos)
    final obfuscated = _obfuscateProtocol(paddedFragments.first);

    return StealthPacket(
      peerId: peerId,
      data: obfuscated,
      isDummy: false,
      fragmentIndex: 0,
      totalFragments: paddedFragments.length,
    );
  }

  /// Processar mensagem de entrada (remover ofuscação)
  Future<Uint8List?> processIncoming(StealthPacket packet) async {
    if (!_isEnabled) {
      return packet.data;
    }

    // Verificar se é dummy traffic
    if (packet.isDummy) {
      DebugUtils.log('Dummy traffic received (ignored)', tag: 'STEALTH');
      return null;
    }

    // 1. Remover ofuscação de protocolo
    final deobfuscated = _deobfuscateProtocol(packet.data);

    // 2. Remover padding
    final unpadded = _removePadding(deobfuscated);

    return unpadded;
  }

  /// Fragmentar dados em chunks menores
  List<Uint8List> _fragmentData(Uint8List data) {
    const fragmentSize = 1024; // 1KB por fragmento
    
    if (data.length <= fragmentSize) {
      return [data];
    }

    final fragments = <Uint8List>[];
    int offset = 0;

    while (offset < data.length) {
      final remaining = data.length - offset;
      final length = remaining < fragmentSize ? remaining : fragmentSize;
      fragments.add(data.sublist(offset, offset + length));
      offset += length;
    }

    DebugUtils.log('Data fragmented: ${fragments.length} fragments', tag: 'STEALTH');
    return fragments;
  }

  /// Adicionar padding aleatório
  Uint8List _addPadding(Uint8List data) {
    // Tamanho de padding aleatório
    final paddingSize = minPaddingSize + 
        _random.nextInt(maxPaddingSize - minPaddingSize);

    // Gerar padding aleatório
    final padding = Uint8List(paddingSize);
    for (int i = 0; i < paddingSize; i++) {
      padding[i] = _random.nextInt(256);
    }

    // Combinar: [tamanho_original(4 bytes)][dados][padding]
    final result = Uint8List(4 + data.length + paddingSize);
    final view = ByteData.view(result.buffer);
    
    // Escrever tamanho original
    view.setUint32(0, data.length);
    
    // Escrever dados
    result.setRange(4, 4 + data.length, data);
    
    // Escrever padding
    result.setRange(4 + data.length, result.length, padding);

    return result;
  }

  /// Remover padding
  Uint8List _removePadding(Uint8List paddedData) {
    if (paddedData.length < 4) {
      return paddedData;
    }

    final view = ByteData.view(paddedData.buffer);
    final originalSize = view.getUint32(0);

    if (originalSize > paddedData.length - 4) {
      return paddedData; // Dados corrompidos
    }

    return paddedData.sublist(4, 4 + originalSize);
  }

  /// Aplicar jitter temporal (delay aleatório)
  Future<void> _applyJitter() async {
    final jitterMs = minJitterMs + 
        _random.nextInt(maxJitterMs - minJitterMs);
    
    await Future.delayed(Duration(milliseconds: jitterMs));
  }

  /// Ofuscar protocolo (fazer parecer HTTP)
  Uint8List _obfuscateProtocol(Uint8List data) {
    // Simular headers HTTP
    const fakeHeader = 'GET /api/v1/sync HTTP/1.1\r\n'
                      'Host: api.example.com\r\n'
                      'User-Agent: Mozilla/5.0\r\n'
                      'Accept: application/json\r\n'
                      '\r\n';
    
    final headerBytes = Uint8List.fromList(fakeHeader.codeUnits);
    
    // Combinar header fake + dados
    final result = Uint8List(headerBytes.length + data.length);
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, data);

    return result;
  }

  /// Remover ofuscação de protocolo
  Uint8List _deobfuscateProtocol(Uint8List data) {
    // Procurar por \r\n\r\n (fim de headers HTTP)
    final headerEnd = _findHeaderEnd(data);
    
    if (headerEnd == -1) {
      return data; // Sem headers fake
    }

    return data.sublist(headerEnd + 4); // +4 para pular \r\n\r\n
  }

  int _findHeaderEnd(Uint8List data) {
    for (int i = 0; i < data.length - 3; i++) {
      if (data[i] == 13 && data[i + 1] == 10 &&
          data[i + 2] == 13 && data[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  /// Iniciar geração de tráfego dummy
  void _startDummyTraffic() {
    _dummyTrafficTimer?.cancel();
    
    _dummyTrafficTimer = Timer.periodic(
      Duration(milliseconds: dummyTrafficIntervalMs),
      (_) => _generateDummyTraffic(),
    );
  }

  /// Parar geração de tráfego dummy
  void _stopDummyTraffic() {
    _dummyTrafficTimer?.cancel();
    _dummyTrafficTimer = null;
  }

  /// Gerar tráfego dummy (falso)
  void _generateDummyTraffic() {
    // Gerar com probabilidade configurada
    if (_random.nextDouble() > dummyTrafficProbability) {
      return;
    }

    // Gerar dados aleatórios
    final size = 256 + _random.nextInt(512);
    final dummyData = Uint8List(size);
    for (int i = 0; i < size; i++) {
      dummyData[i] = _random.nextInt(256);
    }

    // Adicionar padding e ofuscação
    final padded = _addPadding(dummyData);
    final obfuscated = _obfuscateProtocol(padded);

    _outgoingController.add(StealthPacket(
      peerId: 'broadcast', // Enviar para todos
      data: obfuscated,
      isDummy: true,
    ));

    DebugUtils.log('Dummy traffic generated', tag: 'STEALTH');
  }

  /// Obter estatísticas de stealth
  Map<String, dynamic> getStatistics() {
    return {
      'enabled': _isEnabled,
      'padding_range': '$minPaddingSize-$maxPaddingSize bytes',
      'jitter_range': '$minJitterMs-${maxJitterMs}ms',
      'dummy_interval': '${dummyTrafficIntervalMs}ms',
      'dummy_probability': '${(dummyTrafficProbability * 100).toInt()}%',
    };
  }

  void dispose() {
    _stopDummyTraffic();
    _outgoingController.close();
  }
}

/// Pacote stealth
class StealthPacket {
  final String peerId;
  final Uint8List data;
  final bool isDummy;
  final int? fragmentIndex;
  final int? totalFragments;

  StealthPacket({
    required this.peerId,
    required this.data,
    required this.isDummy,
    this.fragmentIndex,
    this.totalFragments,
  });

  bool get isFragmented => totalFragments != null && totalFragments! > 1;
}
