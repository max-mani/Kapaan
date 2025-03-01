import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kaappan/admin_dashboard.dart';
import 'package:kaappan/police_dashboard.dart';
import 'package:kaappan/ambulance_dashboard.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Google Sign-In
  Future<UserCredential?> loginWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      final googleAuth = await googleUser?.authentication;
      final cred = GoogleAuthProvider.credential(
        idToken: googleAuth?.idToken,
        accessToken: googleAuth?.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(cred);

      // Fetch or Set Default Role
      await _checkAndAssignRole(userCredential.user!);

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
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user role to Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
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
        // Fetch user role from Firestore
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          String role = userDoc['role'];

          // Redirect based on user role
          redirectToDashboard(role,context);
        } else {
          // Handle case where role isn't found
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Role not assigned")));
        }
      }
      return user;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: ${e.toString()}")));
      return null;
    }
  }



  // Assign default role if not found in Firestore (for Google Sign-In)
  Future<void> _checkAndAssignRole(User user) async {
    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'role': 'police',
        'createdAt': FieldValue.serverTimestamp(),
      }).then((_) {
        print("User role stored successfully");
      }).catchError((error) {
        print("Error storing role: $error");
      });
    }
  }



  // Redirect Based on Role
  void redirectToDashboard(String role, BuildContext context) {
    if (role == "Admin") {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => AdminDashboard()));
    } else if (role == "police") {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => PoliceDashboard()));
    } else if (role == "Ambulance service") {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => AmbulanceDashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Role Assigned")));
    }
  }

  // Logout
  Future<void> signout(BuildContext context) async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut(); // Sign out from Google as well
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print("Sign Out Error: $e");
    }
  }
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
  Future<void> debugFirestore(String userId) async {
    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(userId).get();
    print("Firestore Data: ${userDoc.data()}");
  }

}
