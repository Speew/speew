import 'package:flutter/material.dart';

/// Modelo de dados para um item no Marketplace P2P.
class MarketItem {
  final String itemId;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final String tokenId;
  final DateTime listedDate;
  final bool isActive;
  final double requiredReputation;

  MarketItem({
    required this.itemId,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.tokenId,
    required this.listedDate,
    this.isActive = true,
    this.requiredReputation = 50.0,
  });

  // Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'tokenId': tokenId,
      'listedDate': listedDate.toIso8601String(),
      'isActive': isActive,
      'requiredReputation': requiredReputation,
    };
  }

  // Factory para criar a partir de JSON
  factory MarketItem.fromJson(Map<String, dynamic> json) {
    return MarketItem(
      itemId: json['itemId'] as String,
      sellerId: json['sellerId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: json['price'] as double,
      tokenId: json['tokenId'] as String,
      listedDate: DateTime.parse(json['listedDate'] as String),
      isActive: json['isActive'] as bool,
      requiredReputation: json['requiredReputation'] as double,
    );
  }
}
