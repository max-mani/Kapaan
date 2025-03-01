import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kaappan/navigationpage.dart';

class AmbulanceDashboard extends StatefulWidget {
  const AmbulanceDashboard({super.key});

  @override
  _AmbulanceDashboardState createState() => _AmbulanceDashboardState();
}

class _AmbulanceDashboardState extends State<AmbulanceDashboard> {
  late GoogleMapController _mapController;
  final LatLng _initialPosition = const LatLng(11.0168, 76.9558);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      _getLocation();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high));
      setState(() {
        _markers.add(Marker(
          markerId: MarkerId("ambulance"),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: "Your Location"),
        ));
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _updateMarkers(List<QueryDocumentSnapshot> accidents) {
    if (!mounted) return;
    setState(() {
      _markers.addAll(accidents.map((accident) {
        var data = accident.data() as Map<String, dynamic>;
        return Marker(
          markerId: MarkerId(accident.id),
          position: LatLng(data['latitude'], data['longitude']),
          infoWindow: InfoWindow(
            title: "Accident - ${data['persons']} persons",
            snippet: data['details'],
          ),
        );
      }));
    });
  }

  Future<void> _acceptAccident(String accidentId, double latitude, double longitude) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      print("User authenticated: $uid");

      // 🔹 Ensure ambulanceId is stored in users collection
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        "ambulanceId": uid,
          // 🔥 Set role explicitly
      }, SetOptions(merge: true));

      // 🔹 Update accident report
      /*await FirebaseFirestore.instance.collection('accidents').doc(accidentId).update({
        'status': 'accepted',
        'acceptedBy': uid,

      });*/

      print("Firestore update successful");


      print("Navigating to NavigationPage...");
      WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NavigationPage(
                destination: LatLng(latitude, longitude),
                ambulanceId: uid,
              ),
            ),
          );
        });

    } else {
      print("Authentication error: User not logged in");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Authentication error: User not logged in")),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ambulance Dashboard"),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14.0),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('accidents').where('status', isEqualTo: 'unresolved').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var accidents = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _updateMarkers(accidents);
                });
                if (accidents.isEmpty) {
                  return const Center(child: Text("No accidents reported", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)));
                }
                return ListView.builder(
                  itemCount: accidents.length,
                  itemBuilder: (context, index) {
                    var accident = accidents[index].data() as Map<String, dynamic>;
                    String accidentId = accidents[index].id;
                    return Card(
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: Colors.orange[100],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Emergency Alert", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800])),
                            const SizedBox(height: 8),
                            Text("Persons Involved: ${accident['persons']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Details: ${accident['details']}"),
                            const SizedBox(height: 4),
                            Text(
                              "Police Location: Lat: ${accident['policeLatitude']}, Lng: ${accident['policeLongitude']}",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.directions),
                                label: const Text("Accept & Navigate"),
                                onPressed: () => _acceptAccident(accidentId, accident['latitude'], accident['longitude']),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
