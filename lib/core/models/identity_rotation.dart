/// Representa uma rotação de identidade para privacidade aprimorada
/// Permite que usuários troquem periodicamente suas chaves públicas e IDs efêmeros
/// mantendo a reputação através de mapeamento privado
class IdentityRotation {
  /// ID da rotação
  final String rotationId;
  
  /// ID do usuário original (permanente, privado)
  final String originalUserId;
  
  /// ID efêmero anterior
  final String? previousEphemeralId;
  
  /// ID efêmero atual
  final String currentEphemeralId;
  
  /// Chave pública anterior
  final String? previousPublicKey;
  
  /// Chave pública atual (Ed25519)
  final String currentPublicKey;
  
  /// Timestamp da rotação
  final DateTime rotationTimestamp;
  
  /// Assinatura da rotação com a chave privada anterior (prova de continuidade)
  final String? previousKeySignature;
  
  /// Assinatura da rotação com a chave privada atual
  final String currentKeySignature;
  
  /// Número sequencial da rotação (1, 2, 3...)
  final int rotationSequence;
  
  /// Período de validade da identidade efêmera (em dias)
  final int validityPeriodDays;
  
  /// Data de expiração da identidade efêmera
  final DateTime expirationDate;
  
  /// Mapeamento de reputação (criptografado localmente)
  /// Permite manter a reputação entre rotações
  final double? reputationCarryOver;
  
  /// Status: active, expired, revoked
  final String status;
  
  /// Lista de peers que foram notificados desta rotação
  final List<String> notifiedPeers;

  IdentityRotation({
    required this.rotationId,
    required this.originalUserId,
    this.previousEphemeralId,
    required this.currentEphemeralId,
    this.previousPublicKey,
    required this.currentPublicKey,
    required this.rotationTimestamp,
    this.previousKeySignature,
    required this.currentKeySignature,
    required this.rotationSequence,
    this.validityPeriodDays = 30,
    required this.expirationDate,
    this.reputationCarryOver,
    required this.status,
    required this.notifiedPeers,
  });

  /// Verifica se a identidade está ativa
  bool get isActive => status == 'active' && !isExpired;

  /// Verifica se a identidade expirou
  bool get isExpired => DateTime.now().isAfter(expirationDate);

  /// Verifica se esta é a primeira rotação
  bool get isFirstRotation => rotationSequence == 1 && previousEphemeralId == null;

  /// Calcula dias restantes até expiração
  int get daysUntilExpiration {
    final now = DateTime.now();
    if (now.isAfter(expirationDate)) return 0;
    return expirationDate.difference(now).inDays;
  }

  /// Verifica se precisa rotacionar em breve (menos de 7 dias)
  bool get needsRotationSoon => daysUntilExpiration <= 7;

  /// Converte para Map
  Map<String, dynamic> toMap() {
    return {
      'rotation_id': rotationId,
      'original_user_id': originalUserId,
      'previous_ephemeral_id': previousEphemeralId,
      'current_ephemeral_id': currentEphemeralId,
      'previous_public_key': previousPublicKey,
      'current_public_key': currentPublicKey,
      'rotation_timestamp': rotationTimestamp.toIso8601String(),
      'previous_key_signature': previousKeySignature,
      'current_key_signature': currentKeySignature,
      'rotation_sequence': rotationSequence,
      'validity_period_days': validityPeriodDays,
      'expiration_date': expirationDate.toIso8601String(),
      'reputation_carry_over': reputationCarryOver,
      'status': status,
      'notified_peers': notifiedPeers.join(','),
    };
  }

  /// Cria a partir de Map
  factory IdentityRotation.fromMap(Map<String, dynamic> map) {
    return IdentityRotation(
      rotationId: map['rotation_id'] as String,
      originalUserId: map['original_user_id'] as String,
      previousEphemeralId: map['previous_ephemeral_id'] as String?,
      currentEphemeralId: map['current_ephemeral_id'] as String,
      previousPublicKey: map['previous_public_key'] as String?,
      currentPublicKey: map['current_public_key'] as String,
      rotationTimestamp: DateTime.parse(map['rotation_timestamp'] as String),
      previousKeySignature: map['previous_key_signature'] as String?,
      currentKeySignature: map['current_key_signature'] as String,
      rotationSequence: map['rotation_sequence'] as int,
      validityPeriodDays: map['validity_period_days'] as int? ?? 30,
      expirationDate: DateTime.parse(map['expiration_date'] as String),
      reputationCarryOver: map['reputation_carry_over'] as double?,
      status: map['status'] as String,
      notifiedPeers: (map['notified_peers'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
    );
  }

  /// Cria uma cópia com campos atualizados
  IdentityRotation copyWith({
    String? rotationId,
    String? originalUserId,
    String? previousEphemeralId,
    String? currentEphemeralId,
    String? previousPublicKey,
    String? currentPublicKey,
    DateTime? rotationTimestamp,
    String? previousKeySignature,
    String? currentKeySignature,
    int? rotationSequence,
    int? validityPeriodDays,
    DateTime? expirationDate,
    double? reputationCarryOver,
    String? status,
    List<String>? notifiedPeers,
  }) {
    return IdentityRotation(
      rotationId: rotationId ?? this.rotationId,
      originalUserId: originalUserId ?? this.originalUserId,
      previousEphemeralId: previousEphemeralId ?? this.previousEphemeralId,
      currentEphemeralId: currentEphemeralId ?? this.currentEphemeralId,
      previousPublicKey: previousPublicKey ?? this.previousPublicKey,
      currentPublicKey: currentPublicKey ?? this.currentPublicKey,
      rotationTimestamp: rotationTimestamp ?? this.rotationTimestamp,
      previousKeySignature: previousKeySignature ?? this.previousKeySignature,
      currentKeySignature: currentKeySignature ?? this.currentKeySignature,
      rotationSequence: rotationSequence ?? this.rotationSequence,
      validityPeriodDays: validityPeriodDays ?? this.validityPeriodDays,
      expirationDate: expirationDate ?? this.expirationDate,
      reputationCarryOver: reputationCarryOver ?? this.reputationCarryOver,
      status: status ?? this.status,
      notifiedPeers: notifiedPeers ?? this.notifiedPeers,
    );
  }

  @override
  String toString() {
    return 'IdentityRotation(seq: $rotationSequence, ephemeral: $currentEphemeralId, status: $status, expires: ${expirationDate.toIso8601String()})';
  }
}
