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

  // Lifecycle fields
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  // Review system
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

  // ✅ FROM MAP (for better flexibility)
  factory IssueModel.fromMap(Map<String, dynamic> data, {String? docId}) {
    return IssueModel(
      id: docId,
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

  // -------------------- ✅ HELPER GETTERS --------------------

  /// Get emergency level as text
  String get emergencyLevelText {
    switch (emergencyLevel) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  /// Get emergency level color
  int get emergencyLevelColor {
    switch (emergencyLevel) {
      case 1:
        return 0xFF4CAF50; // Green
      case 2:
        return 0xFFFFA726; // Orange
      case 3:
        return 0xFFEF5350; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Get status color
  int get statusColor {
    switch (status.toLowerCase()) {
      case 'open':
        return 0xFFFFA726; // Orange
      case 'accepted':
        return 0xFF42A5F5; // Blue
      case 'working':
        return 0xFF9C27B0; // Purple
      case 'completed':
        return 0xFF66BB6A; // Green
      case 'rejected':
        return 0xFFEF5350; // Red
      case 'cancelled':
        return 0xFF757575; // Grey
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Get formatted status text
  String get statusText {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  /// Check if issue is open
  bool get isOpen => status.toLowerCase() == 'open';

  /// Check if issue is accepted
  bool get isAccepted => status.toLowerCase() == 'accepted';

  /// Check if issue is being worked on
  bool get isWorking => status.toLowerCase() == 'working';

  /// Check if issue is completed
  bool get isCompleted => status.toLowerCase() == 'completed';

  /// Check if issue is rejected
  bool get isRejected => status.toLowerCase() == 'rejected';

  /// Check if issue is cancelled
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  /// Check if issue has been assigned to a professional
  bool get isAssigned => assignedProfessionalId != null;

  /// Check if issue has images
  bool get hasImages => imageUrls.isNotEmpty;

  /// Get number of images
  int get imageCount => imageUrls.length;

  /// Check if issue has been rated
  bool get isRated => rating != null;

  /// Get formatted rating (e.g., "4.5 ⭐")
  String get formattedRating {
    if (rating == null) return 'Not rated';
    return '${rating!.toStringAsFixed(1)} ⭐';
  }

  /// Get time elapsed since creation
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get formatted created date (e.g., "Jan 5, 2024")
  String get formattedCreatedDate {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  /// Get duration from created to completed
  String? get completionDuration {
    if (completedAt == null) return null;
    final duration = completedAt!.difference(createdAt);

    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  /// Get short description (max 100 characters)
  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 97)}...';
  }

  // -------------------- ✅ VALIDATION --------------------

  /// Validate if issue data is complete
  bool get isValid {
    return customerId.isNotEmpty &&
        title.isNotEmpty &&
        description.isNotEmpty &&
        category.isNotEmpty &&
        address.isNotEmpty &&
        emergencyLevel >= 1 &&
        emergencyLevel <= 3;
  }

  // -------------------- ✅ DEBUG --------------------

  @override
  String toString() {
    return 'IssueModel(id: $id, title: $title, status: $status, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IssueModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
