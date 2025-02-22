import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AmbulanceDashboard extends StatefulWidget {
  const AmbulanceDashboard({super.key});

  @override
  _AmbulanceDashboardState createState() => _AmbulanceDashboardState();
}

class _AmbulanceDashboardState extends State<AmbulanceDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();

    // Listen for incoming FCM messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(notification.title ?? "New Notification"),
            content: Text(notification.body ?? "You have a new alert."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _acceptAccident(String accidentId) async {
    await _firestore.collection('accidents').doc(accidentId).update({
      'status': 'accepted',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ambulance Dashboard"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('accidents')
            .where('status', isEqualTo: 'unresolved')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var accidents = snapshot.data!.docs;

          return ListView.builder(
            itemCount: accidents.length,
            itemBuilder: (context, index) {
              var accident = accidents[index].data() as Map<String, dynamic>;
              String accidentId = accidents[index].id;
              String details = accident['details'];
              String persons = accident['persons'];

              return Card(
                elevation: 5,
                child: ListTile(
                  title: Text("Persons: $persons"),
                  subtitle: Text("Details: $details"),
                  trailing: ElevatedButton(
                    onPressed: () => _acceptAccident(accidentId),
                    child: const Text("Accept"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
