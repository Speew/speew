import 'lamport_clock.dart';

/// Entrada no ledger distribuído (não-blockchain)
/// Cada entrada representa uma transação simbólica com garantias criptográficas
class DistributedLedgerEntry {
  /// ID único da entrada no ledger
  final String entryId;
  
  /// Número sequencial da entrada (por usuário)
  final int sequenceNumber;
  
  /// ID da transação associada
  final String transactionId;
  
  /// ID do remetente
  final String senderId;
  
  /// ID do receptor
  final String receiverId;
  
  /// Quantidade transferida
  final double amount;
  
  /// Tipo de moeda
  final String coinTypeId;
  
  /// Timestamp Lamport
  final LamportTimestamp lamportTimestamp;
  
  /// Timestamp de relógio de parede
  final DateTime wallClockTime;
  
  /// Assinatura do remetente
  final String senderSignature;
  
  /// Assinatura do receptor (quando aceita)
  final String? receiverSignature;
  
  /// Hash da entrada anterior (para formar cadeia)
  final String? previousEntryHash;
  
  /// Hash desta entrada (SHA-256 de todos os campos)
  final String entryHash;
  
  /// Lista de IDs de peers que propagaram esta entrada (prova de propagação)
  final List<String> propagationWitnesses;
  
  /// Nonce para prevenir replay attacks
  final String nonce;
  
  /// Status: pending, accepted, rejected, conflicted
  final String status;

  DistributedLedgerEntry({
    required this.entryId,
    required this.sequenceNumber,
    required this.transactionId,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.coinTypeId,
    required this.lamportTimestamp,
    required this.wallClockTime,
    required this.senderSignature,
    this.receiverSignature,
    this.previousEntryHash,
    required this.entryHash,
    required this.propagationWitnesses,
    required this.nonce,
    required this.status,
  });

  /// Verifica se a entrada foi aceita
  bool get isAccepted => status == 'accepted' && receiverSignature != null;

  /// Verifica se há conflito
  bool get hasConflict => status == 'conflicted';

  /// Verifica se a entrada está completa (com ambas as assinaturas)
  bool get isComplete => senderSignature.isNotEmpty && receiverSignature != null;

  /// Converte para Map
  Map<String, dynamic> toMap() {
    return {
      'entry_id': entryId,
      'sequence_number': sequenceNumber,
      'transaction_id': transactionId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'amount': amount,
      'coin_type_id': coinTypeId,
      'lamport_timestamp': lamportTimestamp.toMap(),
      'wall_clock_time': wallClockTime.toIso8601String(),
      'sender_signature': senderSignature,
      'receiver_signature': receiverSignature,
      'previous_entry_hash': previousEntryHash,
      'entry_hash': entryHash,
      'propagation_witnesses': propagationWitnesses.join(','),
      'nonce': nonce,
      'status': status,
    };
  }

  /// Cria a partir de Map
  factory DistributedLedgerEntry.fromMap(Map<String, dynamic> map) {
    return DistributedLedgerEntry(
      entryId: map['entry_id'] as String,
      sequenceNumber: map['sequence_number'] as int,
      transactionId: map['transaction_id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      amount: map['amount'] as double,
      coinTypeId: map['coin_type_id'] as String,
      lamportTimestamp: LamportTimestamp.fromMap(map['lamport_timestamp'] as Map<String, dynamic>),
      wallClockTime: DateTime.parse(map['wall_clock_time'] as String),
      senderSignature: map['sender_signature'] as String,
      receiverSignature: map['receiver_signature'] as String?,
      previousEntryHash: map['previous_entry_hash'] as String?,
      entryHash: map['entry_hash'] as String,
      propagationWitnesses: (map['propagation_witnesses'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      nonce: map['nonce'] as String,
      status: map['status'] as String,
    );
  }

  /// Cria uma cópia com campos atualizados
  DistributedLedgerEntry copyWith({
    String? entryId,
    int? sequenceNumber,
    String? transactionId,
    String? senderId,
    String? receiverId,
    double? amount,
    String? coinTypeId,
    LamportTimestamp? lamportTimestamp,
    DateTime? wallClockTime,
    String? senderSignature,
    String? receiverSignature,
    String? previousEntryHash,
    String? entryHash,
    List<String>? propagationWitnesses,
    String? nonce,
    String? status,
  }) {
    return DistributedLedgerEntry(
      entryId: entryId ?? this.entryId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      transactionId: transactionId ?? this.transactionId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      amount: amount ?? this.amount,
      coinTypeId: coinTypeId ?? this.coinTypeId,
      lamportTimestamp: lamportTimestamp ?? this.lamportTimestamp,
      wallClockTime: wallClockTime ?? this.wallClockTime,
      senderSignature: senderSignature ?? this.senderSignature,
      receiverSignature: receiverSignature ?? this.receiverSignature,
      previousEntryHash: previousEntryHash ?? this.previousEntryHash,
      entryHash: entryHash ?? this.entryHash,
      propagationWitnesses: propagationWitnesses ?? this.propagationWitnesses,
      nonce: nonce ?? this.nonce,
      status: status ?? this.status,
    );
  }

  /// Gera string canônica para hashing (todos os campos em ordem determinística)
  String toCanonicalString() {
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
      wallClockTime.toIso8601String(),
      senderSignature,
      receiverSignature ?? '',
      previousEntryHash ?? '',
      propagationWitnesses.join(','),
      nonce,
    ].join('|');
  }

  @override
  String toString() {
    return 'LedgerEntry(id: $entryId, seq: $sequenceNumber, tx: $transactionId, status: $status)';
  }
}
