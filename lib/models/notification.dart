import 'package:flutter/foundation.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // SYSTEM, ACTIVITY, FINANCIAL, HIERARCHY
  final String? recipientRole;
  final String? recipientId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.recipientRole,
    this.recipientId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      recipientRole: json['recipient_role'],
      recipientId: json['recipient_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'recipient_role': recipientRole,
      'recipient_id': recipientId,
      'is_read': isRead,
    };
  }
}
