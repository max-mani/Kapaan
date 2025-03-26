import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'navigationpage.dart'; // Import the navigation page

class AmbulanceDashboard extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ambulance Dashboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('ambulances').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No ambulance requests found.'));
          }

          final ambulances = snapshot.data!.docs;

          return ListView.builder(
            itemCount: ambulances.length,
            itemBuilder: (context, index) {
              final ambulanceDoc = ambulances[index];
              final ambulance = ambulanceDoc.data() as Map<String, dynamic>;

              final String accidentId = ambulance['accident_id'] ?? "Unknown";
              final String intensity = ambulance['intensity'] ?? "Unknown";
              final int personsInvolved = ambulance['persons_involved'] ?? 0;
              final double detectionAccuracy =
              (ambulance['detection_accuracy'] ?? 0.0).toDouble();

              final double latitude = (ambulance['location']?['latitude'] ?? 0.0).toDouble();
              final double longitude = (ambulance['location']?['longitude'] ?? 0.0).toDouble();

              return Card(
                margin: EdgeInsets.all(8.0),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🚑 Ambulance Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Accident ID: $accidentId', style: TextStyle(fontSize: 16)),
                      Text('Intensity: $intensity', style: TextStyle(fontSize: 16)),
                      Text('Persons Involved: $personsInvolved', style: TextStyle(fontSize: 16)),
                      Text('Detection Accuracy: ${detectionAccuracy.toStringAsFixed(2)}%', style: TextStyle(fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Location: ($latitude, $longitude)', style: TextStyle(fontSize: 16)),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await _firestore.collection('ambulances').doc(ambulanceDoc.id).delete();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('🚫 Ambulance Request Rejected'),
                                duration: Duration(seconds: 2),
                              ));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: Text('Reject'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await _updatePoliceCollection(ambulanceDoc.id, latitude, longitude);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NavigationPage(
                                    accidentId: accidentId,
                                    latitude: latitude,
                                    longitude: longitude,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updatePoliceCollection(String ambulanceId, double latitude, double longitude) async {
    await _firestore.collection('police').doc(ambulanceId).set({
      'ambulance_id': ambulanceId,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'status': 'Accepted',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
