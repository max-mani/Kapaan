import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PoliceDashboard extends StatefulWidget {
  const PoliceDashboard({Key? key}) : super(key: key);

  @override
  _PoliceDashboardState createState() => _PoliceDashboardState();
}

class _PoliceDashboardState extends State<PoliceDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _configureFirebaseListeners();
  }

  // Request permission for notifications
  void _requestNotificationPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("Notification permission granted.");
    } else {
      print("Notification permission denied.");
    }
  }

  // Configure Firebase Cloud Messaging listeners
  void _configureFirebaseListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("New Notification: ${message.notification?.title}, ${message.notification?.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.notification?.body ?? "New Notification")),
      );
    });
  }

  // Report an accident and notify ambulance services
  Future<void> _reportAccident(String location, String details) async {
    await _firestore.collection('accidents').add({
      'location': location,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _sendNotification();
  }

  // Send notification to all ambulance drivers
  Future<void> _sendNotification() async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'Ambulance service')
        .get();

    for (var doc in snapshot.docs) {
      String? ambulanceToken = doc['fcmToken'];
      if (ambulanceToken != null) {
        await _firestore.collection('notifications').add({
          'token': ambulanceToken,
          'title': 'Accident Reported',
          'body': 'A new accident has been reported. Check your dashboard for details.',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Notification sent to ambulance services!")),
    );
  }

  // Log out function
  Future<void> _logout() async {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController locationController = TextEditingController();
    TextEditingController detailsController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Police Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: "Accident Location",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: "Accident Details",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (locationController.text.isNotEmpty &&
                        detailsController.text.isNotEmpty) {
                      _reportAccident(locationController.text, detailsController.text);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter all details")),
                      );
                    }
                  },
                  child: const Text("Report Accident"),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('accidents')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No accident reports yet."));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text("Location: ${data['location']}"),
                        subtitle: Text("Details: ${data['details']}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: _sendNotification,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
