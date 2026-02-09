import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import '../core/utils.dart';

class StealthService {
  final Random _random = Random.secure();
  bool _isEnabled = false;
  Timer? _dummyTrafficTimer;

  static const int minPaddingSize = 16;
  static const int maxPaddingSize = 512;
  static const int minJitterMs = 10;
  static const int maxJitterMs = 500;
  static const int dummyTrafficIntervalMs = 5000; 
  static const double dummyTrafficProbability = 0.3; 

  final StreamController<StealthPacket> _outgoingController =
      StreamController<StealthPacket>.broadcast();

  Stream<StealthPacket> get outgoingStream => _outgoingController.stream;

  void enable() {
    if (_isEnabled) return;
    
    _isEnabled = true;
    _startDummyTraffic();
    
    DebugUtils.log('Stealth mode ENABLED', tag: 'STEALTH');
  }

  void disable() {
    if (!_isEnabled) return;
    
    _isEnabled = false;
    _stopDummyTraffic();
    
    DebugUtils.log('Stealth mode DISABLED', tag: 'STEALTH');
  }

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

    final fragments = _fragmentData(data);

    final paddedFragments = fragments.map(_addPadding).toList();

    await _applyJitter();

    final obfuscated = _obfuscateProtocol(paddedFragments.first);

    return StealthPacket(
      peerId: peerId,
      data: obfuscated,
      isDummy: false,
      fragmentIndex: 0,
      totalFragments: paddedFragments.length,
    );
  }

  Future<Uint8List?> processIncoming(StealthPacket packet) async {
    if (!_isEnabled) {
      return packet.data;
    }

    if (packet.isDummy) {
      DebugUtils.log('Dummy traffic received (ignored)', tag: 'STEALTH');
      return null;
    }

    final deobfuscated = _deobfuscateProtocol(packet.data);

    final unpadded = _removePadding(deobfuscated);

    return unpadded;
  }

  List<Uint8List> _fragmentData(Uint8List data) {
    const fragmentSize = 1024; 
    
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

  Uint8List _addPadding(Uint8List data) {
    
    final paddingSize = minPaddingSize + 
        _random.nextInt(maxPaddingSize - minPaddingSize);

    final padding = Uint8List(paddingSize);
    for (int i = 0; i < paddingSize; i++) {
      padding[i] = _random.nextInt(256);
    }

    final result = Uint8List(4 + data.length + paddingSize);
    final view = ByteData.view(result.buffer);

    view.setUint32(0, data.length);

    result.setRange(4, 4 + data.length, data);

    result.setRange(4 + data.length, result.length, padding);

    return result;
  }

  Uint8List _removePadding(Uint8List paddedData) {
    if (paddedData.length < 4) {
      return paddedData;
    }

    final view = ByteData.view(paddedData.buffer);
    final originalSize = view.getUint32(0);

    if (originalSize > paddedData.length - 4) {
      return paddedData; 
    }

    return paddedData.sublist(4, 4 + originalSize);
  }

  Future<void> _applyJitter() async {
    final jitterMs = minJitterMs + 
        _random.nextInt(maxJitterMs - minJitterMs);
    
    await Future.delayed(Duration(milliseconds: jitterMs));
  }

  Uint8List _obfuscateProtocol(Uint8List data) {
    
    const fakeHeader = 'GET /api/v1/sync HTTP/1.1\r\n'
                      'Host: api.example.com\r\n'
                      'User-Agent: Mozilla/5.0\r\n'
                      'Accept: application/json\r\n'
                      '\r\n';
    
    final headerBytes = Uint8List.fromList(fakeHeader.codeUnits);

    final result = Uint8List(headerBytes.length + data.length);
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, data);

    return result;
  }

  Uint8List _deobfuscateProtocol(Uint8List data) {
    
    final headerEnd = _findHeaderEnd(data);
    
    if (headerEnd == -1) {
      return data; 
    }

    return data.sublist(headerEnd + 4); 
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

  void _startDummyTraffic() {
    _dummyTrafficTimer?.cancel();
    
    _dummyTrafficTimer = Timer.periodic(
      Duration(milliseconds: dummyTrafficIntervalMs),
      (_) => _generateDummyTraffic(),
    );
  }

  void _stopDummyTraffic() {
    _dummyTrafficTimer?.cancel();
    _dummyTrafficTimer = null;
  }

  void _generateDummyTraffic() {
    
    if (_random.nextDouble() > dummyTrafficProbability) {
      return;
    }

    final size = 256 + _random.nextInt(512);
    final dummyData = Uint8List(size);
    for (int i = 0; i < size; i++) {
      dummyData[i] = _random.nextInt(256);
    }

    final padded = _addPadding(dummyData);
    final obfuscated = _obfuscateProtocol(padded);

    _outgoingController.add(StealthPacket(
      peerId: 'broadcast', 
      data: obfuscated,
      isDummy: true,
    ));

    DebugUtils.log('Dummy traffic generated', tag: 'STEALTH');
  }

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