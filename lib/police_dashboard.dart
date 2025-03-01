import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kaappan/navigationpage.dart';

class PoliceDashboard extends StatefulWidget {
  const PoliceDashboard({super.key});

  @override
  _PoliceDashboardState createState() => _PoliceDashboardState();
}

class _PoliceDashboardState extends State<PoliceDashboard> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(11.0168, 76.9558); // Coimbatore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers for text fields
  TextEditingController personsController = TextEditingController();
  TextEditingController detailsController = TextEditingController();
  String location = "Fetching location...";
  bool incidentReported = false; // To show "Incident Reported" text after reporting

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      // Proceed to get the location if permission is granted
      _getLocation();
    } else if (status.isDenied) {
      // Optionally, show an alert or prompt the user to enable permission
      print('Location permission denied.');
    } else if (status.isPermanentlyDenied) {
      // Redirect user to app settings to enable the permission
      openAppSettings();
    }
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location services are disabled. Please enable GPS.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Location permission denied.")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permission permanently denied. Enable it in settings.")),
        );
        return;
      }

      // 🔹 Get the Current Position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      setState(() {
        location = "Latitude: ${position.latitude}, Longitude: ${position.longitude}";
      });

      // 🔹 Store the Police Location in Firestore
      await _storePoliceLocation(position);

    } catch (e) {
      print('Error getting location: $e');

      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        setState(() {
          location = "Latitude: ${lastKnown.latitude}, Longitude: ${lastKnown.longitude} (Last Known)";
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to get location. Try again.")),
        );
      }
    }
  }

  Future<void> _storePoliceLocation(Position position) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("User not authenticated.");
      return;
    }

    try {
      await _firestore.collection('police_locations').doc(uid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("Police location updated in Firestore.");
    } catch (e) {
      print("Error storing police location: $e");
    }
  }

  Future<void> _reportAccident(Position position) async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
            code: 'USER_NOT_LOGGED_IN', message: 'User is not authenticated');
      }

      print("User authenticated: $uid");

      String persons = personsController.text.trim();
      String details = detailsController.text.trim();

      if (persons.isEmpty || details.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter all details")),
        );
        return;
      }

      // 🔹 Get the Police's Current Location
      Position policePosition = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      // 🔹 Add accident report to Firestore, including police location
      await FirebaseFirestore.instance.collection('accidents').add({
        'location': GeoPoint(position.latitude, position.longitude), // Accident Location
        'policeLatitude': policePosition.latitude,  // Store Police Latitude
        'policeLongitude': policePosition.longitude, // Store Police Longitude
        'status': 'unresolved',
        'reportedBy': uid,
        'reportedTimestamp': FieldValue.serverTimestamp(),
        'persons': persons,
        'details': details,
      });

      print("Accident report successfully submitted with police location");

      personsController.clear();
      detailsController.clear();

      setState(() {
        incidentReported = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Accident reported successfully!")),
      );
    } catch (e) {
      print("Error reporting accident: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _resolveAccident(String accidentId) async {
    // Update the status of the accident to 'resolved'
    await _firestore.collection('accidents').doc(accidentId).update({
      'status': 'resolved',
    });
  }

  @override
  void initState() {
    super.initState();
    _requestLocationPermission(); // Request location permission on init
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Police Dashboard"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Implement logout functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Google Maps section
          Expanded(
            flex: 2,
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14.0,
              ),
              markers: {}, // Will be dynamically added
            ),
          ),
          // Unresolved and Resolved Accidents Tabs
          Expanded(
            flex: 4,
            child: DefaultTabController(
              length: 3,
              child: Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  flexibleSpace: const TabBar(
                    tabs: [
                      Tab(text: "Report Accident"),
                      Tab(text: "Unresolved"),
                      Tab(text: "Resolved"),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    // Report Accident Tab
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Location info
                            Text(
                              "Location: $location",
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 20),

                            // Number of persons field
                            TextField(
                              controller: personsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Number of Persons",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Incident details field
                            TextField(
                              controller: detailsController,
                              decoration: const InputDecoration(
                                labelText: "Incident Details",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Report Accident Button
                            ElevatedButton(
                              onPressed: () async {
                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission = await Geolocator.requestPermission();
                                  if (permission == LocationPermission.denied) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Location permission denied")),
                                    );
                                    return;
                                  }
                                }

                                if (permission == LocationPermission.deniedForever) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Location permissions are permanently denied")),
                                  );
                                  return;
                                }

                                // ✅ Get the current location
                                Position position = await Geolocator.getCurrentPosition(
                                  locationSettings: AndroidSettings(
                                    accuracy: LocationAccuracy.best,
                                    forceLocationManager: true,
                                  ),
                                );


                                // ✅ Report accident
                                await _reportAccident(position);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              ),
                              child: const Text("Report an Accident"),
                            ),

                            // "Incident Reported" text
                            if (incidentReported)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Text(
                                  "Incident Reported Successfully!",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Unresolved Accidents Tab
                    SingleChildScrollView(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('accidents')
                            .where('status', isEqualTo: 'unresolved')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text("No unresolved accidents"));
                          }

                          var accidents = snapshot.data!.docs;

                          return ListView.builder(
                            shrinkWrap: true, // Prevents overflow
                            itemCount: accidents.length,
                            itemBuilder: (context, index) {
                              var accident = accidents[index].data() as Map<String, dynamic>;
                              String accidentId = accidents[index].id;
                              String details = accident['details'] ?? "No details provided";
                              String persons = accident['persons'] ?? "Unknown";
                              String status = accident['status'] ?? "unresolved";
                              GeoPoint location = accident['location'];
                              double latitude = location.latitude;
                              double longitude = location.longitude;

                              String? ambulanceDriverName = accident['ambulanceDriverName'];
                              String? ambulanceDriverMobile = accident['ambulanceDriverMobile'];

                              return Card(
                                elevation: 5,
                                color: status == 'accepted' ? Colors.green[100] : Colors.red[100],
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        title: Text("Persons: $persons"),
                                        subtitle: Text("Details: $details"),
                                      ),
                                      Text(
                                        "Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}",
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10),
                                      if (ambulanceDriverName != null && ambulanceDriverMobile != null)
                                        ListTile(
                                          title: Text("Ambulance Driver: $ambulanceDriverName"),
                                          subtitle: Text("Mobile: $ambulanceDriverMobile"),
                                        ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              try {
                                                await _firestore.collection('accidents').doc(accidentId).update({
                                                  'status': 'resolved',
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Accident marked as resolved!")),
                                                );
                                              } catch (e) {
                                                print("Firestore update error: $e"); // Debug in console
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text("Error updating: ${e.toString()}")),
                                                );
                                              }
                                            },
                                            child: const Text("Mark as Resolved"),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => NavigationPage(
                                                    destination: LatLng(latitude, longitude),
                                                    ambulanceId: 'ambulanceId', // Replace with actual ambulance ID
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Text("Navigate"),
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
                    )
                    ,

                    // Resolved Accidents Tab
                    SingleChildScrollView(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('accidents')
                            .where('status', isEqualTo: 'resolved')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text("No resolved accidents"));
                          }

                          var accidents = snapshot.data!.docs;

                          return ListView.builder(
                            shrinkWrap: true, // Prevents overflow
                            itemCount: accidents.length,
                            itemBuilder: (context, index) {
                              var accident = accidents[index].data() as Map<String, dynamic>;
                              String details = accident['details'];
                              String persons = accident['persons'];

                              return Card(
                                elevation: 5,
                                color: Colors.green[100],
                                child: ListTile(
                                  title: Text("Persons: $persons"),
                                  subtitle: Text("Details: $details"),
                                  trailing: const Text("Resolved"),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}