import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapaan/screens/admin/admin_dashboard.dart';
import 'package:kapaan/screens/police/police_dashboard.dart';
import 'package:kapaan/screens/ambulance/ambulance_dashboard.dart';
import 'package:kapaan/screens/auth/login_screen.dart';
import 'dart:developer' as developer;

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Email/Password Signup
  Future<bool> createUserWithEmailAndPassword(
      String email, String password, BuildContext context, String role, {
      required String fullName,
      required String phone,
  }) async {
    try {
      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'fullName': fullName,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

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
  Future<void> loginUserWithEmailAndPassword(
    String email,
    String password,
    BuildContext context,
    String selectedRole,
  ) async {
    try {
      developer.log('Attempting login for email: $email with role: $selectedRole');

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
      if (userRole?.toLowerCase() != selectedRole.toLowerCase()) {
        throw 'Invalid role for this account';
      }

      // If we get here, credentials and role are valid
      if (context.mounted) {
        developer.log('Login successful, redirecting to dashboard');
        redirectToDashboard(selectedRole, context);
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
          context, MaterialPageRoute(builder: (context) => AdminDashboard()));
    } else if (normalizedRole == "police") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => PoliceDashboard()));
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
  Future<void> signout(BuildContext context) async {
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

  Future<void> debugFirestore(String userId) async {
    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(userId).get();
    print("Firestore Data: ${userDoc.data()}");
  }
}
