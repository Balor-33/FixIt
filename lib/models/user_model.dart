import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role;
  final String displayName; // ✅ Made required (removed nullable)
  final String? phoneNumber;
  final String? photoUrl;
  final GeoPoint? location;
  final String? address;
  final String? service;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.displayName, // ✅ Made required
    this.phoneNumber,
    this.photoUrl,
    this.location,
    this.address,
    this.service,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'location': location,
      'address': address,
      'service': service,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // In user_model.dart
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      // ✅ Handle both 'displayName' and 'name' fields
      displayName: map['displayName'] ?? map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['phone'],
      photoUrl: map['photoUrl'],
      location: map['location'],
      address: map['address'],
      service: map['service'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    GeoPoint? location,
    String? address,
    String? service,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      address: address ?? this.address,
      service: service ?? this.service,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
