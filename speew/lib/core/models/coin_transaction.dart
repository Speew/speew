/// Modelo de dados para transações da moeda simbólica
/// A moeda é infinita, voluntária e só válida com aceite do destinatário
class CoinTransaction {
  /// Identificador único da transação
  final String transactionId;
  
  /// ID do usuário que envia a moeda
  final String senderId;
  
  /// ID do usuário que recebe a moeda
  final String receiverId;
  
  /// Quantidade de moeda transferida (valor simbólico)
  final double amount;
  
  /// Tipo de moeda (ADICIONADO: Fase 4)
  final String coinTypeId;
  
  /// ID da transação anterior (para transações encadeadas A → B → C) (ADICIONADO: Fase 4)
  final String? previousTransactionId;
  
  /// ID da próxima transação (para transações encadeadas) (ADICIONADO: Fase 4)
  final String? nextTransactionId;
  
  /// Timestamp da criação da transação
  final DateTime timestamp;
  
  /// Status da transação: pending, accepted, rejected
  final String status;
  
  /// Assinatura Ed25519 do remetente
  final String signatureSender;
  
  /// Assinatura Ed25519 do destinatário (quando aceita)
  final String? signatureReceiver;

  CoinTransaction({
    required this.transactionId,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.timestamp,
    required this.status,
    required this.signatureSender,
    this.signatureReceiver,
    this.coinTypeId = 'default', // ADICIONADO: Fase 4
    this.previousTransactionId, // ADICIONADO: Fase 4
    this.nextTransactionId, // ADICIONADO: Fase 4
  });

  /// Converte o objeto CoinTransaction para Map
  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'signature_sender': signatureSender,
      'signature_receiver': signatureReceiver,
      'coin_type_id': coinTypeId, // ADICIONADO: Fase 4
      'previous_transaction_id': previousTransactionId, // ADICIONADO: Fase 4
      'next_transaction_id': nextTransactionId, // ADICIONADO: Fase 4
    };
  }

  /// Cria um objeto CoinTransaction a partir de um Map
  factory CoinTransaction.fromMap(Map<String, dynamic> map) {
    return CoinTransaction(
      transactionId: map['transaction_id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      amount: map['amount'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
      signatureSender: map['signature_sender'] as String,
      signatureReceiver: map['signature_receiver'] as String?,
      coinTypeId: map['coin_type_id'] as String? ?? 'default', // ADICIONADO: Fase 4
      previousTransactionId: map['previous_transaction_id'] as String?, // ADICIONADO: Fase 4
      nextTransactionId: map['next_transaction_id'] as String?, // ADICIONADO: Fase 4
    );
  }

  /// Cria uma cópia da transação com campos atualizados
  CoinTransaction copyWith({
    String? transactionId,
    String? senderId,
    String? receiverId,
    double? amount,
    DateTime? timestamp,
    String? status,
    String? signatureSender,
    String? signatureReceiver,
    String? coinTypeId, // ADICIONADO: Fase 4
    String? previousTransactionId, // ADICIONADO: Fase 4
    String? nextTransactionId, // ADICIONADO: Fase 4
  }) {
    return CoinTransaction(
      transactionId: transactionId ?? this.transactionId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      signatureSender: signatureSender ?? this.signatureSender,
      signatureReceiver: signatureReceiver ?? this.signatureReceiver,
      coinTypeId: coinTypeId ?? this.coinTypeId, // ADICIONADO: Fase 4
      previousTransactionId: previousTransactionId ?? this.previousTransactionId, // ADICIONADO: Fase 4
      nextTransactionId: nextTransactionId ?? this.nextTransactionId, // ADICIONADO: Fase 4
    );
  }
  
  /// Verifica se esta é uma transação encadeada (ADICIONADO: Fase 4)
  bool get isChained => previousTransactionId != null || nextTransactionId != null;
  
  /// Verifica se esta é a primeira transação de uma cadeia (ADICIONADO: Fase 4)
  bool get isChainStart => previousTransactionId == null && nextTransactionId != null;
  
  /// Verifica se esta é a última transação de uma cadeia (ADICIONADO: Fase 4)
  bool get isChainEnd => previousTransactionId != null && nextTransactionId == null;
}
