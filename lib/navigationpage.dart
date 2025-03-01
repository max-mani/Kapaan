import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationPage extends StatefulWidget {
  final LatLng destination;
  final String ambulanceId;

  const NavigationPage({required this.destination, required this.ambulanceId, Key? key}) : super(key: key);

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? mapController;
  Location location = Location();
  LatLng? currentPosition;
  Set<Marker> markers = {};
  bool arrived = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationTracking();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationData position = await location.getLocation();
      setState(() {
        currentPosition = LatLng(position.latitude!, position.longitude!);
        markers.add(
          Marker(
            markerId: const MarkerId("ambulance"),
            position: currentPosition!,
            infoWindow: const InfoWindow(title: "Your Location"),
          ),
        );
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  void _startLocationTracking() {
    location.onLocationChanged.listen((LocationData position) {
      if (position.latitude != null && position.longitude != null) {
        setState(() {
          currentPosition = LatLng(position.latitude!, position.longitude!);
        });
        _updateAmbulanceLocation(position.latitude!, position.longitude!);
      }
    });
  }

  Future<void> _updateAmbulanceLocation(double lat, double lng) async {
    await FirebaseFirestore.instance.collection('ambulances').doc(widget.ambulanceId).set({
      'latitude': lat,
      'longitude': lng,
      'status': 'en route',
    });
  }

  Future<void> _markAsArrived() async {
    await FirebaseFirestore.instance.collection('ambulances').doc(widget.ambulanceId).update({
      'status': 'arrived',
    });
    setState(() {
      arrived = true;
    });
  }

  void _openGoogleMaps() async {
    String googleUrl = "https://www.google.com/maps/dir/?api=1&destination=${widget.destination.latitude},${widget.destination.longitude}&travelmode=driving";
    if (await canLaunch(googleUrl)) {
      await launch(googleUrl);
    } else {
      throw 'Could not open Google Maps';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation"),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(
              target: widget.destination,
              zoom: 14.0,
            ),
            markers: {
              Marker(
                markerId: const MarkerId("destination"),
                position: widget.destination,
                infoWindow: const InfoWindow(title: "Accident Location"),
              ),
              if (currentPosition != null)
                Marker(
                  markerId: const MarkerId("ambulance"),
                  position: currentPosition!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: "Your Location"),
                ),
            },
            myLocationEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text("Start Navigation"),
                  onPressed: _openGoogleMaps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text("Arrived"),
                  onPressed: arrived ? null : _markAsArrived,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: arrived ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
