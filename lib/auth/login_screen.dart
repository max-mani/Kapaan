import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:kaappan/auth/auth_service.dart';
import 'package:kaappan/home_screen.dart'; // Home screen after login
import 'package:kaappan/auth/signup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importing the SignupScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopSection(),
              _buildLoginForm(),
            ],
          ),
        ),
      ),
    );
  }

  // Top Section with Logo and App Name
  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 30, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/logo.jpg"),
                fit: BoxFit.fill,
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            'Kaappan',
            style: TextStyle(
              color: Color(0xFF161000),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // Login Form
  Widget _buildLoginForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
      child: Column(
        children: [
          const Text(
            'Welcome!!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _buildInputField('Email/Username', _email),
          const SizedBox(height: 25),
          _buildInputField('Password', _password, isPassword: true),
          const SizedBox(height: 25),
          _buildLoginButton(),
          const SizedBox(height: 20),
          _buildForgotPassword(),  // Added Forgot Password button here
          const SizedBox(height: 20),
          _buildSignUpPrompt(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),
          _buildGoogleSignInButton(),
        ],
      ),
    );
  }

  // Forgot Password Link
  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => _showForgotPasswordDialog(context),
        child: const Text(
          "Forgot Password?",
          style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Password Reset Dialog
  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(hintText: "Enter your email"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _auth.resetPassword(emailController.text, context);
              Navigator.pop(context); // Close dialog after sending email
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  // Input Field Widget
  Widget _buildInputField(String label, TextEditingController controller, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: label,
            ),
          ),
        ),
      ],
    );
  }

  // Login Button
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: () => _login(context),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Login', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // Sign-Up Prompt
  Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?", style: TextStyle(fontSize: 16)),
        GestureDetector(
          onTap: () => goToSignup(context),
          child: const Text(" Sign up", style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // Divider with "or"
  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.grey)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('or', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        const Expanded(child: Divider(color: Colors.grey)),
      ],
    );
  }

  // Google Sign-In Button
  Widget _buildGoogleSignInButton() {
    return GestureDetector(
      onTap: () async {
        await _auth.loginWithGoogle(context);  // This handles the role-based redirection after Google Sign-In
      },
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Sign in with Google', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  void goToSignup(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
  }

  Future<void> _login(BuildContext context) async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    final user = await _auth.loginUserWithEmailAndPassword(
        _email.text, _password.text, context);

    if (user != null) {
      log("User Logged In");

      // Fetch user role and navigate accordingly
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'];
        _auth.redirectToDashboard(role,context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Role not assigned. Contact admin.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email or password")),
      );
    }
  }

}
