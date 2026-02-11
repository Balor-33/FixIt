// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
    };
  }

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  MessageModel copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? text,
    DateTime? sentAt,
    bool? isRead,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
