import 'package:flutter/material.dart';

/// Modelo de dados para um Leilão Simbólico.
class AuctionModel {
  final String auctionId;
  final String initiatorId;
  final String title;
  final String description;
  final String tokenId;
  final double startingPrice;
  final DateTime startTime;
  final DateTime endTime;
  final double currentBid;
  final String? currentBidderId;
  final double networkFee;
  bool isActive;

  AuctionModel({
    required this.auctionId,
    required this.initiatorId,
    required this.title,
    required this.description,
    required this.tokenId,
    required this.startingPrice,
    required this.startTime,
    required this.endTime,
    this.currentBid = 0.0,
    this.currentBidderId,
    this.networkFee = 0.01, // 1% de taxa para a rede mesh
    this.isActive = true,
  });

  // Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'auctionId': auctionId,
      'initiatorId': initiatorId,
      'title': title,
      'description': description,
      'tokenId': tokenId,
      'startingPrice': startingPrice,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'currentBid': currentBid,
      'currentBidderId': currentBidderId,
      'networkFee': networkFee,
      'isActive': isActive,
    };
  }

  // Factory para criar a partir de JSON
  factory AuctionModel.fromJson(Map<String, dynamic> json) {
    return AuctionModel(
      auctionId: json['auctionId'] as String,
      initiatorId: json['initiatorId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      tokenId: json['tokenId'] as String,
      startingPrice: json['startingPrice'] as double,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      currentBid: json['currentBid'] as double,
      currentBidderId: json['currentBidderId'] as String?,
      networkFee: json['networkFee'] as double,
      isActive: json['isActive'] as bool,
    );
  }
}
