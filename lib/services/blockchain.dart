import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../core/utils.dart';

class MessageBlockchain {
  final List<Block> _chain = [];
  final int _difficulty = 2; 

  List<Block> get chain => List.unmodifiable(_chain);
  int get length => _chain.length;

  void initialize() {
    if (_chain.isEmpty) {
      final genesis = Block(
        index: 0,
        timestamp: DateTime.now(),
        data: {'type': 'genesis', 'message': 'Speew Chat Blockchain'},
        previousHash: '0',
      );
      
      _chain.add(genesis);
      
      DebugUtils.log('Blockchain initialized with genesis block', tag: 'BLOCKCHAIN');
    }
  }

  Future<Block> addMessage({
    required String messageId,
    required String senderId,
    required String receiverId,
    required String contentHash,
    required DateTime timestamp,
  }) async {
    final lastBlock = _chain.last;
    
    final newBlock = Block(
      index: _chain.length,
      timestamp: timestamp,
      data: {
        'message_id': messageId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content_hash': contentHash,
      },
      previousHash: lastBlock.hash,
    );

    await _mineBlock(newBlock);

    _chain.add(newBlock);

    DebugUtils.log(
      'Block #${newBlock.index} added to chain (nonce: ${newBlock.nonce})',
      tag: 'BLOCKCHAIN',
    );

    return newBlock;
  }

  Future<void> _mineBlock(Block block) async {
    final target = '0' * _difficulty;
    
    while (!block.hash.startsWith(target)) {
      block.nonce++;
      block.calculateHash();

      if (block.nonce % 1000 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    DebugUtils.log(
      'Block mined! Hash: ${block.hash} (${block.nonce} attempts)',
      tag: 'BLOCKCHAIN',
    );
  }

  bool verifyChain() {
    for (int i = 1; i < _chain.length; i++) {
      final currentBlock = _chain[i];
      final previousBlock = _chain[i - 1];

      final calculatedHash = _calculateBlockHash(currentBlock);
      if (currentBlock.hash != calculatedHash) {
        DebugUtils.logError('Block #$i hash is invalid!');
        return false;
      }

      if (currentBlock.previousHash != previousBlock.hash) {
        DebugUtils.logError('Block #$i previous hash mismatch!');
        return false;
      }

      final target = '0' * _difficulty;
      if (!currentBlock.hash.startsWith(target)) {
        DebugUtils.logError('Block #$i proof of work invalid!');
        return false;
      }
    }

    DebugUtils.log('Blockchain verification: PASSED ✅', tag: 'BLOCKCHAIN');
    return true;
  }

  bool verifyMessage(String messageId) {
    for (final block in _chain) {
      if (block.data['message_id'] == messageId) {
        
        final calculatedHash = _calculateBlockHash(block);
        return block.hash == calculatedHash;
      }
    }
    return false;
  }

  Block? getBlock(int index) {
    if (index < 0 || index >= _chain.length) return null;
    return _chain[index];
  }

  List<Block> getConversationBlocks(String peerId) {
    return _chain.where((block) {
      final senderId = block.data['sender_id'];
      final receiverId = block.data['receiver_id'];
      return senderId == peerId || receiverId == peerId;
    }).toList();
  }

  String _calculateBlockHash(Block block) {
    final data = {
      'index': block.index,
      'timestamp': block.timestamp.millisecondsSinceEpoch,
      'data': block.data,
      'previous_hash': block.previousHash,
      'nonce': block.nonce,
    };

    final jsonStr = jsonEncode(data);
    final bytes = utf8.encode(jsonStr);
    final hash = sha256.convert(bytes);

    return hash.toString();
  }

  Map<String, dynamic> exportChain() {
    return {
      'length': _chain.length,
      'difficulty': _difficulty,
      'blocks': _chain.map((b) => b.toJson()).toList(),
    };
  }

  void importChain(Map<String, dynamic> data) {
    _chain.clear();

    final blocks = data['blocks'] as List;
    for (final blockData in blocks) {
      _chain.add(Block.fromJson(blockData));
    }

    DebugUtils.log('Blockchain imported (${_chain.length} blocks)', tag: 'BLOCKCHAIN');
  }

  Map<String, dynamic> getStatistics() {
    return {
      'total_blocks': _chain.length,
      'difficulty': _difficulty,
      'is_valid': verifyChain(),
      'genesis_time': _chain.isNotEmpty
          ? _chain.first.timestamp.toIso8601String()
          : null,
      'last_block_time': _chain.isNotEmpty
          ? _chain.last.timestamp.toIso8601String()
          : null,
    };
  }
}

class Block {
  final int index;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final String previousHash;
  int nonce;
  String hash;

  Block({
    required this.index,
    required this.timestamp,
    required this.data,
    required this.previousHash,
    this.nonce = 0,
  }) : hash = '' {
    calculateHash();
  }

  void calculateHash() {
    final blockData = {
      'index': index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'data': data,
      'previous_hash': previousHash,
      'nonce': nonce,
    };

    final jsonStr = jsonEncode(blockData);
    final bytes = utf8.encode(jsonStr);
    hash = sha256.convert(bytes).toString();
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'data': data,
    'previous_hash': previousHash,
    'nonce': nonce,
    'hash': hash,
  };

  factory Block.fromJson(Map<String, dynamic> json) {
    final block = Block(
      index: json['index'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      data: Map<String, dynamic>.from(json['data']),
      previousHash: json['previous_hash'],
      nonce: json['nonce'],
    );
    block.hash = json['hash'];
    return block;
  }
}

class MerkleTree {
  final List<String> _leaves;
  List<String> _tree = [];

  MerkleTree(this._leaves) {
    _buildTree();
  }

  String get root => _tree.isNotEmpty ? _tree.last : '';

  void _buildTree() {
    if (_leaves.isEmpty) return;

    _tree = List.from(_leaves);

    while (_tree.length > 1) {
      final nextLevel = <String>[];

      for (int i = 0; i < _tree.length; i += 2) {
        if (i + 1 < _tree.length) {
          
          final combined = _tree[i] + _tree[i + 1];
          final hash = sha256.convert(utf8.encode(combined)).toString();
          nextLevel.add(hash);
        } else {
          
          nextLevel.add(_tree[i]);
        }
      }

      _tree.addAll(nextLevel);
    }
  }

  List<String> generateProof(int index) {
    final proof = <String>[];
    int currentIndex = index;
    int levelSize = _leaves.length;
    int offset = 0;

    while (levelSize > 1) {
      final isRightNode = currentIndex % 2 == 1;
      final siblingIndex = isRightNode ? currentIndex - 1 : currentIndex + 1;

      if (siblingIndex < levelSize) {
        proof.add(_tree[offset + siblingIndex]);
      }

      currentIndex = currentIndex ~/ 2;
      offset += levelSize;
      levelSize = (levelSize + 1) ~/ 2;
    }

    return proof;
  }

  static bool verifyProof(String leaf, List<String> proof, String root) {
    String current = leaf;

    for (final sibling in proof) {
      final combined = current + sibling;
      current = sha256.convert(utf8.encode(combined)).toString();
    }

    return current == root;
  }
}