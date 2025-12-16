import '../../models/coin_transaction.dart';
import '../../models/distributed_ledger_entry.dart';
import '../../models/lamport_clock.dart';
import '../crypto/crypto_service.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Serviço de Ledger Simbólico Distribuído (não-blockchain)
/// Gerencia transações com garantias criptográficas sem custo computacional de blockchain
class DistributedLedgerService {
  static final DistributedLedgerService _instance = DistributedLedgerService._internal();
  factory DistributedLedgerService() => _instance;
  DistributedLedgerService._internal();

  final _crypto = CryptoService();
  final _uuid = const Uuid();
  
  /// Mapa de sequências por usuário (para IDs sequenciais)
  final Map<String, int> _userSequences = {};
  
  /// Cache de hashes de entradas anteriores por usuário
  final Map<String, String> _lastEntryHashes = {};
  
  /// Cache de nonces usados (prevenção de replay)
  final Set<String> _usedNonces = {};

  // ==================== CRIAÇÃO DE ENTRADAS ====================

  /// Cria uma nova entrada no ledger a partir de uma transação
  Future<DistributedLedgerEntry> createLedgerEntry({
    required CoinTransaction transaction,
    required LamportTimestamp lamportTimestamp,
    required String senderPrivateKey,
    String? receiverPrivateKey,
  }) async {
    // Gerar ID sequencial para o remetente
    final sequenceNumber = _getNextSequence(transaction.senderId);
    
    // Gerar nonce único
    final nonce = _generateNonce();
    
    // Obter hash da entrada anterior (se existir)
    final previousHash = _lastEntryHashes[transaction.senderId];
    
    // Criar entrada preliminar
    final entryId = _uuid.v4();
    
    // Assinar com chave do remetente
    final senderSignature = await _signEntry(
      entryId: entryId,
      sequenceNumber: sequenceNumber,
      transactionId: transaction.transactionId,
      senderId: transaction.senderId,
      receiverId: transaction.receiverId,
      amount: transaction.amount,
      coinTypeId: transaction.coinTypeId,
      lamportTimestamp: lamportTimestamp,
      nonce: nonce,
      privateKey: senderPrivateKey,
    );
    
    // Assinar com chave do receptor (se fornecida)
    String? receiverSignature;
    if (receiverPrivateKey != null) {
      receiverSignature = await _signEntry(
        entryId: entryId,
        sequenceNumber: sequenceNumber,
        transactionId: transaction.transactionId,
        senderId: transaction.senderId,
        receiverId: transaction.receiverId,
        amount: transaction.amount,
        coinTypeId: transaction.coinTypeId,
        lamportTimestamp: lamportTimestamp,
        nonce: nonce,
        privateKey: receiverPrivateKey,
      );
    }
    
    // Criar entrada completa
    final entry = DistributedLedgerEntry(
      entryId: entryId,
      sequenceNumber: sequenceNumber,
      transactionId: transaction.transactionId,
      senderId: transaction.senderId,
      receiverId: transaction.receiverId,
      amount: transaction.amount,
      coinTypeId: transaction.coinTypeId,
      lamportTimestamp: lamportTimestamp,
      wallClockTime: DateTime.now(),
      senderSignature: senderSignature,
      receiverSignature: receiverSignature,
      previousEntryHash: previousHash,
      entryHash: '', // Será calculado
      propagationWitnesses: [],
      nonce: nonce,
      status: receiverSignature != null ? 'accepted' : 'pending',
    );
    
    // Calcular hash da entrada
    final entryHash = _calculateEntryHash(entry);
    final finalEntry = entry.copyWith(entryHash: entryHash);
    
    // Atualizar cache
    _lastEntryHashes[transaction.senderId] = entryHash;
    _usedNonces.add(nonce);
    
    return finalEntry;
  }

  /// Aceita uma entrada pendente (adiciona assinatura do receptor)
  Future<DistributedLedgerEntry> acceptLedgerEntry({
    required DistributedLedgerEntry entry,
    required String receiverPrivateKey,
  }) async {
    if (entry.isAccepted) {
      throw Exception('Entrada já foi aceita');
    }
    
    // Assinar com chave do receptor
    final receiverSignature = await _signEntry(
      entryId: entry.entryId,
      sequenceNumber: entry.sequenceNumber,
      transactionId: entry.transactionId,
      senderId: entry.senderId,
      receiverId: entry.receiverId,
      amount: entry.amount,
      coinTypeId: entry.coinTypeId,
      lamportTimestamp: entry.lamportTimestamp,
      nonce: entry.nonce,
      privateKey: receiverPrivateKey,
    );
    
    // Atualizar entrada
    final acceptedEntry = entry.copyWith(
      receiverSignature: receiverSignature,
      status: 'accepted',
    );
    
    // Recalcular hash
    final newHash = _calculateEntryHash(acceptedEntry);
    return acceptedEntry.copyWith(entryHash: newHash);
  }

  // ==================== VERIFICAÇÃO ====================

  /// Verifica a integridade de uma entrada do ledger
  Future<bool> verifyLedgerEntry({
    required DistributedLedgerEntry entry,
    required String senderPublicKey,
    String? receiverPublicKey,
  }) async {
    // 1. Verificar hash da entrada
    final calculatedHash = _calculateEntryHash(entry);
    if (calculatedHash != entry.entryHash) {
      return false;
    }
    
    // 2. Verificar nonce (prevenção de replay)
    if (_usedNonces.contains(entry.nonce)) {
      // Nonce já foi usado (possível replay attack)
      return false;
    }
    
    // 3. Verificar assinatura do remetente
    final senderData = _getSignatureData(
      entryId: entry.entryId,
      sequenceNumber: entry.sequenceNumber,
      transactionId: entry.transactionId,
      senderId: entry.senderId,
      receiverId: entry.receiverId,
      amount: entry.amount,
      coinTypeId: entry.coinTypeId,
      lamportTimestamp: entry.lamportTimestamp,
      nonce: entry.nonce,
    );
    
    final senderValid = await _crypto.verifySignature(
      senderData,
      entry.senderSignature,
      senderPublicKey,
    );
    
    if (!senderValid) {
      return false;
    }
    
    // 4. Verificar assinatura do receptor (se presente)
    if (entry.receiverSignature != null && receiverPublicKey != null) {
      final receiverValid = await _crypto.verifySignature(
        senderData,
        entry.receiverSignature!,
        receiverPublicKey,
      );
      
      if (!receiverValid) {
        return false;
      }
    }
    
    // 5. Verificar sequência (se temos histórico)
    if (_userSequences.containsKey(entry.senderId)) {
      final expectedSequence = _userSequences[entry.senderId]! + 1;
      if (entry.sequenceNumber != expectedSequence) {
        return false;
      }
    }
    
    return true;
  }

  /// Verifica se há duplicação de transação
  bool isDuplicateTransaction(String transactionId, List<DistributedLedgerEntry> existingEntries) {
    return existingEntries.any((e) => e.transactionId == transactionId);
  }

  /// Verifica a cadeia de entradas de um usuário
  bool verifyEntryChain(List<DistributedLedgerEntry> entries) {
    if (entries.isEmpty) return true;
    
    // Ordenar por sequência
    final sortedEntries = List<DistributedLedgerEntry>.from(entries)
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    
    // Verificar sequência contínua
    for (int i = 0; i < sortedEntries.length; i++) {
      if (sortedEntries[i].sequenceNumber != i + 1) {
        return false;
      }
      
      // Verificar hash anterior
      if (i > 0) {
        if (sortedEntries[i].previousEntryHash != sortedEntries[i - 1].entryHash) {
          return false;
        }
      }
    }
    
    return true;
  }

  // ==================== PROPAGAÇÃO ====================

  /// Adiciona testemunha de propagação
  DistributedLedgerEntry addPropagationWitness(
    DistributedLedgerEntry entry,
    String witnessId,
  ) {
    if (entry.propagationWitnesses.contains(witnessId)) {
      return entry;
    }
    
    final updatedWitnesses = [...entry.propagationWitnesses, witnessId];
    return entry.copyWith(propagationWitnesses: updatedWitnesses);
  }

  /// Verifica se a entrada tem propagação suficiente (mínimo 3 testemunhas)
  bool hasSufficientPropagation(DistributedLedgerEntry entry) {
    return entry.propagationWitnesses.length >= 3;
  }

  // ==================== FUNÇÕES AUXILIARES ====================

  /// Gera próximo número sequencial para um usuário
  int _getNextSequence(String userId) {
    if (!_userSequences.containsKey(userId)) {
      _userSequences[userId] = 0;
    }
    _userSequences[userId] = _userSequences[userId]! + 1;
    return _userSequences[userId]!;
  }

  /// Gera nonce único
  String _generateNonce() {
    return _uuid.v4();
  }

  /// Assina uma entrada
  Future<String> _signEntry({
    required String entryId,
    required int sequenceNumber,
    required String transactionId,
    required String senderId,
    required String receiverId,
    required double amount,
    required String coinTypeId,
    required LamportTimestamp lamportTimestamp,
    required String nonce,
    required String privateKey,
  }) async {
    final data = _getSignatureData(
      entryId: entryId,
      sequenceNumber: sequenceNumber,
      transactionId: transactionId,
      senderId: senderId,
      receiverId: receiverId,
      amount: amount,
      coinTypeId: coinTypeId,
      lamportTimestamp: lamportTimestamp,
      nonce: nonce,
    );
    
    return await _crypto.signData(data, privateKey);
  }

  /// Gera string canônica para assinatura
  String _getSignatureData({
    required String entryId,
    required int sequenceNumber,
    required String transactionId,
    required String senderId,
    required String receiverId,
    required double amount,
    required String coinTypeId,
    required LamportTimestamp lamportTimestamp,
    required String nonce,
  }) {
    return [
      entryId,
      sequenceNumber.toString(),
      transactionId,
      senderId,
      receiverId,
      amount.toString(),
      coinTypeId,
      lamportTimestamp.counter.toString(),
      lamportTimestamp.nodeId,
      nonce,
    ].join('|');
  }

  /// Calcula hash SHA-256 de uma entrada
  String _calculateEntryHash(DistributedLedgerEntry entry) {
    final canonical = entry.toCanonicalString();
    return _crypto.sha256Hash(canonical);
  }

  /// Reseta o serviço (para testes)
  void reset() {
    _userSequences.clear();
    _lastEntryHashes.clear();
    _usedNonces.clear();
  }
}
