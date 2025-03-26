import 'dart:convert'; // For base64 decoding
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ControlRoomDashboard extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control Room Dashboard'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('accidents').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No accidents found.'));
          }

          final accidents = snapshot.data!.docs;

          return ListView.builder(
            itemCount: accidents.length,
            itemBuilder: (context, index) {
              final accidentDoc = accidents[index];
              final accident = accidentDoc.data() as Map<String, dynamic>;

              // ✅ Using your approach for latitude & longitude
              final double? latitude = accident['location']?['latitude']?.toDouble();
              final double? longitude = accident['location']?['longitude']?.toDouble();

              final String intensity = accident['intensity'] ?? "Unknown";
              final double detectionPercentage =
              (accident['average_detection_percentage'] ?? 0.0).toDouble();
              final int personsInvolved = (accident['persons_involved'] ?? 0);
              final List<dynamic> detectedFrames = accident['detected_frames'] ?? [];

              return Card(
                margin: EdgeInsets.all(8.0),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accident Detected: ${accident['accident_detected'] == true ? 'Yes' : 'No'}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Intensity: $intensity',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Detection Accuracy: ${detectionPercentage.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Persons Involved: $personsInvolved',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        latitude != null && longitude != null
                            ? 'Location: ($latitude, $longitude)'
                            : 'Location: Not Available',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),

                      // Displaying images from base64
                      if (detectedFrames.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detected Frames:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              height: 150,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: detectedFrames.length,
                                itemBuilder: (context, frameIndex) {
                                  final imageBase64 = detectedFrames[frameIndex] as String;
                                  return Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Image.memory(
                                      base64Decode(imageBase64),
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(Icons.error),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                      SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: () async {
                          await _allocateAmbulance(accidentDoc.id, accident);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🚑 Ambulance Allocated Successfully!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text('Allocate Ambulance'),
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

  Future<void> _allocateAmbulance(String accidentId, Map<String, dynamic> accidentData) async {
    // ✅ Using your approach to fetch latitude & longitude
    final double? latitude = accidentData['location']?['latitude']?.toDouble();
    final double? longitude = accidentData['location']?['longitude']?.toDouble();

    await _firestore.collection('ambulances').add({
      'accident_id': accidentId,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'intensity': accidentData['intensity'] ?? "Unknown",
      'persons_involved': accidentData['persons_involved'] ?? 0,
      'detection_accuracy': accidentData['average_detection_percentage'] ?? 0.0,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Pending', // Can be updated later by ambulance personnel
    });

    // Optionally, mark the accident as reported
    await _firestore.collection('accidents').doc(accidentId).update({
      'reported': true,
    });
  }
}