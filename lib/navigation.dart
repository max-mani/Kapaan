import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For GeoPoint

class NavigationPage extends StatelessWidget {
  final GeoPoint location; // Accept GeoPoint as a parameter

  // Constructor with named parameter
  NavigationPage({required this.location});

  @override
  Widget build(BuildContext context) {
    // Convert GeoPoint to LatLng for Google Maps
    final LatLng accidentLocation = LatLng(location.latitude, location.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation to Accident'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: accidentLocation, // Set the initial map position to the accident location
          zoom: 14.0, // Adjust the zoom level as needed
        ),
        markers: {
          Marker(
            markerId: MarkerId('accidentLocation'),
            position: accidentLocation, // Add a marker at the accident location
            infoWindow: InfoWindow(
              title: 'Accident Location',
              snippet: 'Lat: ${location.latitude}, Lng: ${location.longitude}',
            ),
          ),
        },
      ),
    );
  }
}