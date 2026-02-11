import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/issue_model.dart';
import 'notification_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /* ==========================================================
   * USER
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
}
