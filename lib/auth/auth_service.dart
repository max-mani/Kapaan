import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kaappan/admin_dashboard.dart';
import 'package:kaappan/police_dashboard.dart';
import 'package:kaappan/ambulance_dashboard.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Google Sign-In
  Future<UserCredential?> loginWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // User canceled sign-in

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Get FCM token
        String? fcmToken = await _firebaseMessaging.getToken();

        // Store user details and FCM token in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL,
          'fcmToken': fcmToken,
        }, SetOptions(merge: true));

        // Assign role if not exists
        await _checkAndAssignRole(user);

        // Redirect user to respective dashboard
        await _redirectToDashboard(user.uid, context);
      }

      return userCredential;
    } catch (e) {
      print("Google Sign-In Error: $e");
    }
    return null;
  }

  // Email/Password Signup
  Future<User?> createUserWithEmailAndPassword(
      String email, String password, BuildContext context, String role) async {
    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(email: email, password: password);

      String? fcmToken = await _firebaseMessaging.getToken();

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'fcmToken': fcmToken,
      });

      return userCredential.user;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Signup Failed: $e")));
      return null;
    }
  }

  // Email/Password Login
  Future<User?> loginUserWithEmailAndPassword(
      String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Get FCM token
        String? fcmToken = await _firebaseMessaging.getToken();

        // Update token in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': fcmToken,
        }, SetOptions(merge: true));

        // Fetch user role from Firestore
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          String role = userDoc['role'];
          redirectToDashboard(role, context);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Role not assigned")));
        }
      }
      return user;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login Failed: ${e.toString()}")));
      return null;
    }
  }

  // Assign default role if not found in Firestore
  Future<void> _checkAndAssignRole(User user) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists || !userDoc.data().toString().contains('role')) {
      await _firestore.collection('users').doc(user.uid).set({
        'role': 'Police', // Default role
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Redirect Based on Role
  Future<void> _redirectToDashboard(String userId, BuildContext context) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

    if (userDoc.exists) {
      String role = userDoc['role'];
      redirectToDashboard(role, context);
    }
  }

  void redirectToDashboard(String role, BuildContext context) {
    if (role == "Admin") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => AdminDashboard()));
    } else if (role == "Police") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => PoliceDashboard()));
    } else if (role == "Ambulance service") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => AmbulanceDashboard()));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid Role Assigned")));
    }
  }

  // Logout (Updated: Renamed from signOut to signout)
  Future<void> signout(BuildContext context) async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print("Sign Out Error: $e");
    }
  }

  // Reset Password
  Future<void> resetPassword(String email, BuildContext context) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent! Check your inbox.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  // Debug Firestore
  Future<void> debugFirestore(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    print("Firestore Data: ${userDoc.data()}");
  }
}
