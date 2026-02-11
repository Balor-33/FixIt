import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/issue_model.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import 'notification_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /* ==========================================================
   * USER - CRUD OPERATIONS
   * ========================================================== */

  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());

    // Update FCM token after user creation
    await _notificationService.updateUserToken(user.uid);

    print('✅ User created with FCM token');
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  // ✅ NEW: Update user profile (name, phone, etc.)
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? phoneNumber,
    String? address,
    GeoPoint? location,
    String? photoUrl,
  }) async {
    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) updates['displayName'] = displayName;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (address != null) updates['address'] = address;
    if (location != null) updates['location'] = location;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _db.collection('users').doc(uid).update(updates);
    print('✅ User profile updated');
  }

  // ✅ NEW: Update only display name
  Future<void> updateUserName(String uid, String displayName) async {
    await _db.collection('users').doc(uid).update({
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✅ User name updated to: $displayName');
  }

  // ✅ NEW: Update only phone number
  Future<void> updateUserPhone(String uid, String phoneNumber) async {
    await _db.collection('users').doc(uid).update({
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✅ User phone updated');
  }

  // ✅ NEW: Update user address and location
  Future<void> updateUserAddress({
    required String uid,
    required String address,
    GeoPoint? location,
  }) async {
    final Map<String, dynamic> updates = {
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (location != null) updates['location'] = location;

    await _db.collection('users').doc(uid).update(updates);
    print('✅ User address updated');
  }

  // ✅ NEW: Update professional's service category
  Future<void> updateUserService(String uid, String service) async {
    await _db.collection('users').doc(uid).update({
      'service': service,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✅ User service category updated to: $service');
  }

  // ✅ NEW: Delete user account
  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
    print('✅ User deleted');
  }

  // ✅ NEW: Check if user exists
  Future<bool> userExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  // ✅ NEW: Get all users by role
  Future<List<UserModel>> getUsersByRole(String role) async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: role)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  // ✅ NEW: Get professionals by service category
  Future<List<UserModel>> getProfessionalsByService(String service) async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'professional')
        .where('service', isEqualTo: service)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  /* ==========================================================
   * ISSUES – CUSTOMER
   * ========================================================== */

  Future<String> createIssue(IssueModel issue) async {
    final ref = await _db.collection('issues').add({
      ...issue.toMap(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Cloud Function will automatically notify professionals via topic
    print('✅ Issue created: ${ref.id}');

    return ref.id;
  }

  Stream<List<IssueModel>> getCustomerIssues(String customerId) {
    return _db
        .collection('issues')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => IssueModel.fromFirestore(d)).toList(),
        );
  }

  Future<IssueModel?> getIssue(String issueId) async {
    final doc = await _db.collection('issues').doc(issueId).get();
    if (!doc.exists) return null;
    return IssueModel.fromFirestore(doc);
  }

  Future<void> updateIssue(String issueId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('issues').doc(issueId).update(data);
  }

  /* ==========================================================
   * ISSUES – PROFESSIONAL
   * ========================================================== */

  Stream<List<IssueModel>> getAllOpenIssues() {
    return _db
        .collection('issues')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => IssueModel.fromFirestore(d)).toList(),
        );
  }

  Stream<List<IssueModel>> getOpenIssuesByCategory(String category) {
    return _db
        .collection('issues')
        .where('status', isEqualTo: 'open')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => IssueModel.fromFirestore(d)).toList(),
        );
  }

  Stream<List<IssueModel>> getProfessionalJobs(String professionalId) {
    return _db
        .collection('issues')
        .where('assignedProfessionalId', isEqualTo: professionalId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => IssueModel.fromFirestore(d)).toList(),
        );
  }

  /* ==========================================================
   * PROFESSIONAL ACTIONS
   * ========================================================== */

  Future<void> acceptIssue(String issueId, String professionalId) async {
    await _db.collection('issues').doc(issueId).update({
      'status': 'accepted',
      'assignedProfessionalId': professionalId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Cloud Function will notify the customer
    print('✅ Issue accepted by professional');
  }

  Future<void> rejectIssue(String issueId) async {
    await _db.collection('issues').doc(issueId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Issue rejected');
  }

  Future<void> startWorkingOnIssue(String issueId) async {
    await _db.collection('issues').doc(issueId).update({
      'status': 'working',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Started working on issue');
  }

  Future<void> completeIssue(String issueId) async {
    await _db.collection('issues').doc(issueId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Issue completed');
  }

  /* ==========================================================
   * REVIEWS + PROFESSIONAL RATING
   * ========================================================== */

  Future<void> submitReview({
    required String issueId,
    required String professionalId,
    required int rating,
    String? comment,
  }) async {
    await _db.collection('reviews').add({
      'issueId': issueId,
      'professionalId': professionalId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final profileRef = _db
        .collection('professional_profiles')
        .doc(professionalId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(profileRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final completedJobs = (data['completedJobs'] ?? 0) + 1;
      final oldRating = (data['rating'] ?? rating).toDouble();

      final newRating =
          ((oldRating * (completedJobs - 1)) + rating) / completedJobs;

      tx.update(profileRef, {
        'rating': newRating,
        'completedJobs': completedJobs,
        'totalJobs': (data['totalJobs'] ?? 0) + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Notify professional about the review
    await createNotification(
      userId: professionalId,
      title: 'New Review',
      body: 'You received a $rating-star review!',
      type: 'review',
      data: {'issueId': issueId, 'rating': rating},
    );
  }

  /* ==========================================================
   * NOTIFICATIONS
   * ========================================================== */

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Cloud Function will automatically send FCM notification
    print('✅ Notification created in Firestore');
  }

  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<void> markNotificationAsRead(String id) async {
    await _db.collection('notifications').doc(id).update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final notifications = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    return snapshot.size;
  }

  /* ==========================================================
   * PROFESSIONAL PROFILE
   * ========================================================== */

  Future<Map<String, dynamic>?> getProfessionalProfile(
    String professionalId,
  ) async {
    final doc = await _db
        .collection('professional_profiles')
        .doc(professionalId)
        .get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  Future<void> updateProfessionalProfile(
    String professionalId,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('professional_profiles')
        .doc(professionalId)
        .update(data);
  }

  /* ==========================================================
   * TOPIC SUBSCRIPTIONS (for category-based notifications)
   * ========================================================== */

  Future<void> subscribeToProfessionalCategory(String category) async {
    await _notificationService.subscribeToTopic('category_$category');
  }

  Future<void> unsubscribeFromProfessionalCategory(String category) async {
    await _notificationService.unsubscribeFromTopic('category_$category');
  }

  /* ==========================================================
   * CHAT - ROOMS & MESSAGES
   * ========================================================== */

  /// Create or get existing chat room for an issue
  Future<String> getOrCreateChatRoom({
    required String issueId,
    required String customerId,
    required String professionalId,
  }) async {
    try {
      // Use issue ID as chat room ID for simplicity
      final chatRoomId = 'chat_$issueId';
      final chatRoomRef = _db.collection('chat_rooms').doc(chatRoomId);

      // Check if it exists
      final doc = await chatRoomRef.get();

      if (doc.exists) {
        print('✅ Chat room found: $chatRoomId');
        return chatRoomId;
      }

      // Create new chat room with the predictable ID
      await chatRoomRef.set({
        'issueId': issueId,
        'customerId': customerId,
        'professionalId': professionalId,
        'lastMessage': null,
        'lastMessageTime': null,
        'unreadCountCustomer': 0,
        'unreadCountProfessional': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Chat room created: $chatRoomId');
      return chatRoomId;
    } catch (e) {
      print('❌ Error in getOrCreateChatRoom: $e');
      rethrow;
    }
  }

  /// Get chat room by ID
  Future<ChatRoomModel?> getChatRoom(String chatRoomId) async {
    try {
      final doc = await _db.collection('chat_rooms').doc(chatRoomId).get();
      if (!doc.exists) return null;
      return ChatRoomModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting chat room: $e');
      return null;
    }
  }

  /// Get chat room for a specific issue
  Future<ChatRoomModel?> getChatRoomByIssue(String issueId) async {
    try {
      final chatRoomId = 'chat_$issueId';
      final doc = await _db.collection('chat_rooms').doc(chatRoomId).get();

      if (!doc.exists) return null;
      return ChatRoomModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting chat room by issue: $e');
      return null;
    }
  }

  /// Stream all chat rooms for a user (both as customer and professional)
  Stream<List<ChatRoomModel>> getUserChatRooms(String userId) {
    // Query for rooms where user is customer
    final customerQuery = _db
        .collection('chat_rooms')
        .where('customerId', isEqualTo: userId);

    // Query for rooms where user is professional
    final professionalQuery = _db
        .collection('chat_rooms')
        .where('professionalId', isEqualTo: userId);

    return customerQuery.snapshots().asyncMap((customerSnapshot) async {
      final professionalSnapshot = await professionalQuery.get();

      final allDocs = [...customerSnapshot.docs, ...professionalSnapshot.docs];

      return allDocs.map((doc) => ChatRoomModel.fromFirestore(doc)).toList()
        ..sort((a, b) {
          if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });
    });
  }

  /// Send a message in a chat room
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    try {
      // Validate inputs
      if (text.trim().isEmpty) {
        print('⚠️ Cannot send empty message');
        return;
      }

      // Add message to messages collection
      final messageRef = await _db.collection('messages').add({
        'chatRoomId': chatRoomId,
        'senderId': senderId,
        'text': text.trim(),
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('✅ Message added to Firestore: ${messageRef.id}');

      // Get chat room to determine who is customer/professional
      final chatRoom = await getChatRoom(chatRoomId);
      if (chatRoom == null) {
        print('⚠️ Chat room not found when sending message');
        return;
      }

      // Update chat room with last message and increment unread count
      final isCustomerSending = senderId == chatRoom.customerId;

      await _db.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        isCustomerSending ? 'unreadCountProfessional' : 'unreadCountCustomer':
            FieldValue.increment(1),
      });

      print('✅ Chat room updated with last message');

      // Send notification to receiver
      try {
        final issue = await getIssue(chatRoom.issueId);
        final sender = await getUser(senderId);
        final senderName = sender?.displayName ?? 'Someone';

        await createNotification(
          userId: receiverId,
          title: 'New Message from $senderName',
          body: text.length > 50 ? '${text.substring(0, 50)}...' : text,
          type: 'chat',
          data: {
            'chatRoomId': chatRoomId,
            'issueId': chatRoom.issueId,
            'issueTitle': issue?.title ?? 'Issue',
          },
        );

        print('✅ Notification sent to receiver');
      } catch (e) {
        print('⚠️ Error sending notification: $e');
        // Don't throw - message was already sent successfully
      }

      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Stream messages for a chat room
  Stream<List<MessageModel>> getChatMessages(String chatRoomId) {
    return _db
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) {
          final messages = snap.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
          print('📨 Loaded ${messages.length} messages for $chatRoomId');
          return messages;
        });
  }

  /// Mark messages as read in a chat room
  Future<void> markMessagesAsRead({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      final chatRoom = await getChatRoom(chatRoomId);
      if (chatRoom == null) {
        print('⚠️ Chat room not found');
        return;
      }

      final isCustomer = userId == chatRoom.customerId;

      // Mark all unread messages from the other user as read
      final unreadMessages = await _db
          .collection('messages')
          .where('chatRoomId', isEqualTo: chatRoomId)
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) {
        print('✅ No unread messages to mark');
        return;
      }

      final batch = _db.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      // Reset unread count in chat room
      await _db.collection('chat_rooms').doc(chatRoomId).update({
        isCustomer ? 'unreadCountCustomer' : 'unreadCountProfessional': 0,
      });

      print('✅ Marked ${unreadMessages.docs.length} messages as read');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  /// Get total unread message count across all chats for a user
  Future<int> getTotalUnreadMessageCount(String userId) async {
    try {
      final chatRooms = await _db
          .collection('chat_rooms')
          .where('customerId', isEqualTo: userId)
          .get();

      final professionalRooms = await _db
          .collection('chat_rooms')
          .where('professionalId', isEqualTo: userId)
          .get();

      int totalUnread = 0;

      for (var doc in chatRooms.docs) {
        final data = doc.data();
        totalUnread += (data['unreadCountCustomer'] ?? 0) as int;
      }

      for (var doc in professionalRooms.docs) {
        final data = doc.data();
        totalUnread += (data['unreadCountProfessional'] ?? 0) as int;
      }

      return totalUnread;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Delete a chat room and all its messages
  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      // Delete all messages in the chat room
      final messages = await _db
          .collection('messages')
          .where('chatRoomId', isEqualTo: chatRoomId)
          .get();

      final batch = _db.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete the chat room itself
      await _db.collection('chat_rooms').doc(chatRoomId).delete();

      print('✅ Chat room and ${messages.docs.length} messages deleted');
    } catch (e) {
      print('❌ Error deleting chat room: $e');
    }
  }
}
