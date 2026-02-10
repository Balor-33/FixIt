import 'package:cloud_firestore/cloud_firestore.dart';

class IssueModel {
  final String? id;
  final String customerId;
  final String? assignedProfessionalId;

  final int emergencyLevel; // 1 = Low, 2 = Medium, 3 = High

  final String title;
  final String description;
  final String category;
  final String address;

  /// Status lifecycle:
  /// open → accepted → working → completed
  /// rejected / cancelled
  final String status;

  final List<String> imageUrls;
  // New structured image metadata (each item: {url: string, labels: [{label, confidence}]})
  final List<Map<String, dynamic>>? images;

  final DateTime createdAt;
  final DateTime updatedAt;

  // NEW (optional lifecycle fields)
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  // NEW (review system)
  final double? rating;
  final String? review;

  IssueModel({
    this.id,
    required this.customerId,
    required this.emergencyLevel,
    required this.title,
    required this.description,
    required this.category,
    required this.address,
    required this.status,
    required this.imageUrls,
    this.images,
    required this.createdAt,
    required this.updatedAt,
    this.assignedProfessionalId,
    this.acceptedAt,
    this.completedAt,
    this.rating,
    this.review,
  });

  // -------------------- TO MAP --------------------
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'assignedProfessionalId': assignedProfessionalId,
      'emergencyLevel': emergencyLevel,
      'title': title,
      'description': description,
      'category': category,
      'address': address,
      'status': status,
      'imageUrls': imageUrls,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'rating': rating,
      'review': review,
    };
  }

  // -------------------- FROM FIRESTORE --------------------
  factory IssueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return IssueModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      assignedProfessionalId: data['assignedProfessionalId'],
      emergencyLevel: data['emergencyLevel'] ?? 1,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      address: data['address'] ?? '',
      status: data['status'] ?? 'open',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      images: (data['images'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      rating: (data['rating'] as num?)?.toDouble(),
      review: data['review'],
    );
  }

  // -------------------- COPY WITH --------------------
  IssueModel copyWith({
    String? id,
    String? customerId,
    String? assignedProfessionalId,
    int? emergencyLevel,
    String? title,
    String? description,
    String? category,
    String? address,
    String? status,
    List<String>? imageUrls,
    List<Map<String, dynamic>>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    double? rating,
    String? review,
  }) {
    return IssueModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      assignedProfessionalId:
          assignedProfessionalId ?? this.assignedProfessionalId,
      emergencyLevel: emergencyLevel ?? this.emergencyLevel,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      address: address ?? this.address,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      rating: rating ?? this.rating,
      review: review ?? this.review,
    );
  }
}
