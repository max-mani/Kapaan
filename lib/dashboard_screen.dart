import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kaappan/auth/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  const DashboardScreen({super.key, required this.role});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role} Dashboard'),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: _buildDrawer(),
      body: _buildDashboardContent(),
    );
  }

  // Navigation Drawer
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.account_circle, size: 50, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'User',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.local_police, 'Police', 'Police'),
          _buildDrawerItem(Icons.local_hospital, 'Ambulance Service', 'Ambulance'),
          _buildDrawerItem(Icons.admin_panel_settings, 'Admin', 'Admin'),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout'),
            onTap: () async {
              await _authService.signout(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  // Drawer Item Widget
  Widget _buildDrawerItem(IconData icon, String title, String role) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(role: role)),
        );
      },
    );
  }

  // Dashboard Content Based on Role
  Widget _buildDashboardContent() {
    switch (widget.role) {
      case 'Police':
        return _buildPoliceDashboard();
      case 'Ambulance':
        return _buildAmbulanceDashboard();
      case 'Admin':
        return _buildAdminDashboard();
      default:
        return Center(child: Text('Invalid Role'));
    }
  }

  // Police Dashboard
  Widget _buildPoliceDashboard() {
    return Center(
      child: Text('Police Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }

  // Ambulance Dashboard
  Widget _buildAmbulanceDashboard() {
    return Center(
      child: Text('Ambulance Service Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }

  // Admin Dashboard
  Widget _buildAdminDashboard() {
    return Center(
      child: Text('Admin Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}
