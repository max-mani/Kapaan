import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapaan/services/auth_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required UserRole role,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserProfile({
    required String uid,
    String? fullName,
    String? phone,
    UserRole? role,
  }) async {
    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['fullName'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (role != null) updates['role'] = role.toString().split('.').last;

    await _firestore.collection('users').doc(uid).update(updates);
  }
} 