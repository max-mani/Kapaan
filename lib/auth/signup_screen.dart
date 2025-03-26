import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kaappan/auth/auth_service.dart';
import 'package:kaappan/home_screen.dart';
import 'package:kaappan/auth/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = AuthService();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  String _selectedRole = "Police";

  final List<String> _roles = ["Admin", "Police", "Ambulance service"];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              _buildTopSection(),
              const SizedBox(height: 20),
              _buildInputField('Full Name', _name),
              const SizedBox(height: 20),
              _buildInputField('Email', _email),
              const SizedBox(height: 20),
              _buildInputField('Phone Number', _phone, isNumber: true),
              const SizedBox(height: 20),
              _buildInputField('Password', _password, isPassword: true),
              const SizedBox(height: 20),
              _buildRoleDropdown(),
              const SizedBox(height: 30),
              _buildSignupButton(),
              const SizedBox(height: 20),
              _buildLoginPrompt(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Column(
      children: [
        Text(
          'Sign Up',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Create an account to get started!',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool isPassword = false, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            hintText: label,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _selectedRole,
            onChanged: (String? newValue) {
              setState(() {
                _selectedRole = newValue!;
              });
            },
            items: _roles.map((role) {
              return DropdownMenuItem(value: role, child: Text(role));
            }).toList(),
            isExpanded: true,
            underline: Container(),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton() {
    return GestureDetector(
      onTap: () => _signup(context),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Color(0xFF2463EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          ),
          child: const Text("Login", style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }

  Future<void> _signup(BuildContext context) async {
    final user = await _auth.createUserWithEmailAndPassword(
        _email.text,
        _password.text,context,
        _selectedRole
    );
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _name.text,
        'email': _email.text,
        'phone': _phone.text,
        'role': _selectedRole,
      });
      log("User Signed Up and stored in Firestore");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}
