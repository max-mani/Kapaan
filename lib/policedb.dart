import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart'; // For formatting timestamp

class PoliceDashboard extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Police Dashboard'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('police').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No ambulance data found.'));
          }

          final policeDocuments = snapshot.data!.docs;
          Set<Marker> markers = {};
          List<Widget> ambulanceDetails = [];

          for (var doc in policeDocuments) {
            final ambulanceId = doc['ambulance_id'] as String? ?? 'Unknown';
            final locationData = doc['location'] as Map<String, dynamic>?;
            final status = doc['status'] as String? ?? 'Unknown';
            final timestamp = doc['timestamp'] as Timestamp?;

            // Extract latitude and longitude
            final latitude = locationData?['latitude'] as double?;
            final longitude = locationData?['longitude'] as double?;

            // Format Timestamp
            String formattedTimestamp = timestamp != null
                ? DateFormat('MMM dd, yyyy HH:mm:ss').format(timestamp.toDate())
                : 'No Timestamp';

            if (latitude != null && longitude != null) {
              final LatLng ambulanceLocation = LatLng(latitude, longitude);
              markers.add(
                Marker(
                  markerId: MarkerId(ambulanceId),
                  position: ambulanceLocation,
                  infoWindow: InfoWindow(
                    title: 'Ambulance ID: $ambulanceId',
                    snippet: 'Status: $status\nLat: $latitude, Lng: $longitude',
                  ),
                ),
              );
            }

            // Add Ambulance Details Card
            ambulanceDetails.add(
              Card(
                margin: EdgeInsets.all(8.0),
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambulance ID: $ambulanceId',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text('Status: $status'),
                      if (latitude != null && longitude != null)
                        Text('Location: ($latitude, $longitude)'),
                      Text('Timestamp: $formattedTimestamp'),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              // **Google Map Showing Ambulance Locations**
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: markers.isNotEmpty
                      ? CameraPosition(target: markers.first.position, zoom: 14.0)
                      : CameraPosition(target: LatLng(13.02528, 80.1964032), zoom: 14.0),
                  markers: markers,
                ),
              ),

              // **Ambulance Details List**
              Expanded(
                child: ListView(
                  children: ambulanceDetails,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
