// lib/models/chat_room_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String issueId;
  final String customerId;
  final String professionalId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCountCustomer;
  final int unreadCountProfessional;
  final DateTime createdAt;

  ChatRoomModel({
    required this.id,
    required this.issueId,
    required this.customerId,
    required this.professionalId,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCountCustomer = 0,
    this.unreadCountProfessional = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'issueId': issueId,
      'customerId': customerId,
      'professionalId': professionalId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unreadCountCustomer': unreadCountCustomer,
      'unreadCountProfessional': unreadCountProfessional,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      issueId: data['issueId'] ?? '',
      customerId: data['customerId'] ?? '',
      professionalId: data['professionalId'] ?? '',
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCountCustomer: data['unreadCountCustomer'] ?? 0,
      unreadCountProfessional: data['unreadCountProfessional'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  ChatRoomModel copyWith({
    String? id,
    String? issueId,
    String? customerId,
    String? professionalId,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCountCustomer,
    int? unreadCountProfessional,
    DateTime? createdAt,
  }) {
    return ChatRoomModel(
      id: id ?? this.id,
      issueId: issueId ?? this.issueId,
      customerId: customerId ?? this.customerId,
      professionalId: professionalId ?? this.professionalId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCountCustomer: unreadCountCustomer ?? this.unreadCountCustomer,
      unreadCountProfessional:
          unreadCountProfessional ?? this.unreadCountProfessional,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
