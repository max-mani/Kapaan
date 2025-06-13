import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapaan/screens/admin/admin_dashboard.dart';
import 'package:kapaan/screens/police/police_dashboard.dart';
import 'package:kapaan/screens/ambulance/ambulance_dashboard.dart';
import 'package:kapaan/screens/auth/login_screen.dart';
import 'dart:developer' as developer;

enum UserRole {
  none,
  admin,
  police,
  ambulance,
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email/Password Signup
  Future<bool> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
    required BuildContext context,
  }) async {
    try {
      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile in Firestore
      final userData = {
        'email': email,
        'role': role.toLowerCase(),
        'fullName': fullName,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user!.uid,
      };

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);

      developer.log('New user created: $email with role: $role');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully")),
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      developer.log('Firebase Auth Error during signup: $e');
      String errorMessage = 'An error occurred during signup';
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email already exists';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      return false;
    } catch (e) {
      developer.log('Error during signup: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
      return false;
    }
  }

  // Email/Password Login
  Future<void> loginUserWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    required BuildContext context,
  }) async {
    try {
      developer.log('Attempting login for email: $email with role: $role');

      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user role from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw 'User profile not found';
      }

      final userRole = userDoc.data()?['role'];
      if (userRole?.toLowerCase() != role.toLowerCase()) {
        throw 'Invalid role for this account';
      }

      // If we get here, credentials and role are valid
      if (context.mounted) {
        developer.log('Login successful, redirecting to dashboard');
        redirectToDashboard(role, context);
      }

    } on FirebaseAuthException catch (e) {
      developer.log('Firebase Auth Error during login: $e');
      String errorMessage = 'An error occurred during login';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Invalid password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      developer.log('Unexpected error during login: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // Redirect Based on Role
  void redirectToDashboard(String role, BuildContext context) {
    developer.log('Redirecting to dashboard for role: $role');
    
    final normalizedRole = role.toLowerCase();
    if (normalizedRole == "admin") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
    } else if (normalizedRole == "police") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const PoliceDashboard()));
    } else if (normalizedRole == "ambulance service") {
      // Get ambulance ID from user's email
      final ambulanceId = _auth.currentUser?.email?.replaceAll(RegExp(r'[^0-9]'), '');
      final formattedAmbulanceId = 'AMB${ambulanceId?.padLeft(3, '0')}';
      
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => AmbulanceDashboard(ambulanceId: formattedAmbulanceId)));
    } else {
      developer.log('Invalid role for redirection: $role');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Role Assigned")));
    }
  }

  // Logout
  Future<void> signOut(BuildContext context) async {
    try {
      await _auth.signOut();
      // Navigate to login screen and clear the navigation stack
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      developer.log("Sign Out Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error signing out: ${e.toString()}")),
        );
      }
    }
  }

  // Password Reset
  Future<void> resetPassword(String email, BuildContext context) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset instructions sent to your email")),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error sending password reset email';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  // Update user role in Firestore
  Future<void> _updateUserRole(String uid, UserRole role) async {
    await _firestore.collection('users').doc(uid).set({
      'role': role.toString().split('.').last,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get user role from Firestore
  Future<UserRole> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['role'] != null) {
        return UserRole.values.firstWhere(
          (role) => role.toString().split('.').last == doc.data()?['role'],
          orElse: () => UserRole.none,
        );
      }
      return UserRole.none;
    } catch (e) {
      print('Error getting user role: $e');
      return UserRole.none;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e as FirebaseAuthException);
    }
  }

  // Handle Firebase Auth errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
} 