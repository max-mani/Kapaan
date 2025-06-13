import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapaan/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kapaan/screens/ambulance/navigation_page.dart';
import 'package:kapaan/widgets/loading_button.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:kapaan/services/location_service.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class AmbulanceDashboard extends StatefulWidget {
  final String ambulanceId;

  const AmbulanceDashboard({Key? key, required this.ambulanceId}) : super(key: key);

  @override
  _AmbulanceDashboardState createState() => _AmbulanceDashboardState();
}

class _AmbulanceDashboardState extends State<AmbulanceDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);
  final LocationService _locationService = LocationService();
  final AuthService _auth = AuthService();
  String _loadingMessage = '';
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  BitmapDescriptor? ambulanceIcon;
  BitmapDescriptor? accidentIcon;
  BitmapDescriptor? policeIcon;
  StreamSubscription<QuerySnapshot>? _accidentsSubscription;
  List<QueryDocumentSnapshot> _currentAccidents = [];

  static const int markerSize = 80;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _startLocationTracking();
    _loadCustomMarkers();
    _setupAccidentsListener();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _accidentsSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupAccidentsListener() {
    _accidentsSubscription = _firestore
        .collection('accidents')
        .where('reported', isEqualTo: true)
        .where('status', isEqualTo: 'Reported')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _currentAccidents = snapshot.docs;
      });
      if (_currentPosition != null) {
        _updateMapMarkers();
      }
    });
  }

  Future<bool> _checkAndRequestPermissions() async {
    try {
      // First check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location services are disabled. Please enable location services.'),
              action: SnackBarAction(
                label: 'SETTINGS',
                onPressed: () async {
                  final opened = await openAppSettings();
                  if (!opened && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open settings. Please enable location services manually.')),
                    );
                  }
                },
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return false;
      }

      // Request location permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.locationAlways,
        Permission.locationWhenInUse,
      ].request();

      // Check if any location permission is granted
      bool hasLocationPermission = statuses[Permission.location]!.isGranted ||
          statuses[Permission.locationAlways]!.isGranted ||
          statuses[Permission.locationWhenInUse]!.isGranted;

      if (!hasLocationPermission) {
        // Double check with Geolocator's permission
        LocationPermission geoPermission = await Geolocator.checkPermission();
        if (geoPermission == LocationPermission.denied) {
          geoPermission = await Geolocator.requestPermission();
        }

        if (geoPermission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location permission is required for the ambulance service.'),
                action: SnackBarAction(
                  label: 'GRANT',
                  onPressed: () => _checkAndRequestPermissions(),
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return false;
        }

        if (geoPermission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location permission is permanently denied. Please enable it in settings.'),
                action: SnackBarAction(
                  label: 'SETTINGS',
                  onPressed: () async {
                    final opened = await openAppSettings();
                    if (!opened && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open settings. Please enable location permission manually.')),
                      );
                    }
                  },
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return false;
        }
      }

      // Check for background location permission if needed
      if (statuses[Permission.locationAlways]?.isDenied ?? true) {
        final status = await Permission.locationAlways.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Background location access is recommended for better tracking.'),
                action: SnackBarAction(
                  label: 'SETTINGS',
                  onPressed: () async {
                    final opened = await openAppSettings();
                    if (!opened && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open settings. Please enable background location manually.')),
                      );
                    }
                  },
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          // We still return true as this is optional
        }
      }

      return true;
    } catch (e) {
      developer.log('Error checking permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      bool hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition != null) {
        _updateAmbulanceLocation(_currentPosition!);
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() => _currentPosition = position);
        _updateAmbulanceLocation(position);
      });

    } catch (e) {
      developer.log('Error starting location tracking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _updateAmbulanceLocation(Position position) async {
    try {
      // First check if ambulance document exists
      final ambulanceDoc = await _firestore.collection('ambulances').doc(widget.ambulanceId).get();
      
      if (!ambulanceDoc.exists) {
        // If it doesn't exist, create it with default data and location
        await _firestore.collection('ambulances').doc(widget.ambulanceId).set({
          'registration_number': widget.ambulanceId,
          'driver_name': 'Default Driver',
          'driver_phone': '1234567890',
          'status': 'Available',
          'ambulance_details': {
            'vehicle_type': 'Basic Life Support',
            'hospital_name': 'City General Hospital',
            'capacity': '2',
            'equipment': ['Oxygen', 'First Aid', 'Stretcher']
          },
          'current_location': GeoPoint(position.latitude, position.longitude),
          'last_updated': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        // If it exists, just update the location
        await _firestore.collection('ambulances').doc(widget.ambulanceId).update({
          'current_location': GeoPoint(position.latitude, position.longitude),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      developer.log('Error updating ambulance location: $e');
    }
  }

  String _calculateDistance(dynamic location) {
    if (_currentPosition == null) return 'Calculating...';
    
    double accidentLat;
    double accidentLng;
    
    if (location is GeoPoint) {
      accidentLat = location.latitude;
      accidentLng = location.longitude;
    } else if (location is Map<String, dynamic>) {
      accidentLat = location['latitude'] as double;
      accidentLng = location['longitude'] as double;
    } else {
      return 'Invalid location';
    }
    
    double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      accidentLat,
      accidentLng,
    );
    
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} meters';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    }
  }

  Future<void> _initializeFirebase() async {
    try {
      _showLoading('Initializing...');
      
      // First check if ambulance document exists
      final ambulanceDoc = await _firestore.collection('ambulances').doc(widget.ambulanceId).get();
      
      // If it doesn't exist, create it with default data
      if (!ambulanceDoc.exists) {
        await _firestore.collection('ambulances').doc(widget.ambulanceId).set({
          'registration_number': widget.ambulanceId,
          'driver_name': 'Default Driver',
          'driver_phone': '1234567890',
          'status': 'Available',
          'ambulance_details': {
            'vehicle_type': 'Basic Life Support',
            'hospital_name': 'City General Hospital',
            'capacity': '2',
            'equipment': ['Oxygen', 'First Aid', 'Stretcher']
          },
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
      
      await _firestore.collection('accidents').limit(1).get();
      _hideLoading();
    } catch (e) {
      developer.log('Error initializing Firebase: $e');
      _hideLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting to database. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoading(String message) {
    setState(() {
      _loadingMessage = message;
      _isLoadingNotifier.value = true;
    });
  }

  void _hideLoading() {
    setState(() {
      _isLoadingNotifier.value = false;
    });
  }

  Future<Uint8List> resizeImage(Uint8List imageData) async {
    final ui.Codec codec = await ui.instantiateImageCodec(imageData);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..filterQuality = FilterQuality.high;

    final double aspectRatio = image.width / image.height;
    int targetWidth = markerSize;
    int targetHeight = markerSize;

    if (aspectRatio > 1) {
      targetHeight = (markerSize / aspectRatio).round();
    } else {
      targetWidth = (markerSize * aspectRatio).round();
    }

    canvas.drawImageRect(
      image,
      Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTRB(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      paint,
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image resizedImage = await picture.toImage(targetWidth, targetHeight);
    final ByteData? byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final ByteData ambulanceData = await rootBundle.load('assets/images/ambulance.png');
      final ByteData accidentData = await rootBundle.load('assets/images/accident.png');
      final ByteData policeData = await rootBundle.load('assets/images/policeman.png');

      final Uint8List resizedAmbulanceData = await resizeImage(ambulanceData.buffer.asUint8List());
      final Uint8List resizedAccidentData = await resizeImage(accidentData.buffer.asUint8List());
      final Uint8List resizedPoliceData = await resizeImage(policeData.buffer.asUint8List());

      ambulanceIcon = BitmapDescriptor.fromBytes(resizedAmbulanceData);
      accidentIcon = BitmapDescriptor.fromBytes(resizedAccidentData);
      policeIcon = BitmapDescriptor.fromBytes(resizedPoliceData);

      if (mounted) {
        _updateMapMarkers();
      }
    } catch (e) {
      developer.log('Error loading markers: $e');
    }
  }

  void _updateMapMarkers() {
    if (!mounted || _currentPosition == null) return;
    
    setState(() {
      _markers = {};
      
      // Add ambulance marker
      _markers.add(
        Marker(
          markerId: MarkerId('ambulance_${widget.ambulanceId}'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current Position',
          ),
        ),
      );

      // Add accident markers
      for (var accident in _currentAccidents) {
        final data = accident.data() as Map<String, dynamic>;
        final location = data['location'];
        
        _markers.add(
          Marker(
            markerId: MarkerId('accident_${accident.id}'),
            position: LatLng(location['latitude'], location['longitude']),
            icon: accidentIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Accident',
              snippet: 'Click for details',
            ),
          ),
        );
      }

      _updateCameraPosition();
    });
  }

  void _updateCameraPosition() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (Marker marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    final double padding = 0.01;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAAD9F),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC95F5F),
        title: const Text('Ambulance Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _auth.signOut(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      zoom: 14,
                    ),
                    markers: _markers,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      _updateMapMarkers();
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    compassEnabled: true,
                    zoomControlsEnabled: true,
                  ),
          ),
          Expanded(
            flex: 2,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('ambulances')
                  .where('status', whereIn: ['Pending', 'En Route'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No pending accidents'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final ambulanceDoc = snapshot.data!.docs[index];
                    final data = ambulanceDoc.data() as Map<String, dynamic>;
                    
                    // Get accident data from the ambulance document
                    final accidentData = data['accident_data'] as Map<String, dynamic>?;
                    if (accidentData == null) {
                      return SizedBox.shrink();
                    }

                    final location = accidentData['location'];
                    double? latitude;
                    double? longitude;

                    if (location is GeoPoint) {
                      latitude = location.latitude;
                      longitude = location.longitude;
                    } else if (location is Map<String, dynamic>) {
                      latitude = location['latitude'] as double?;
                      longitude = location['longitude'] as double?;
                    }

                    if (latitude == null || longitude == null) {
                      return SizedBox.shrink(); // Skip invalid locations
                    }

                    final accidentId = data['accident_id'] as String?;
                    if (accidentId == null) {
                      return SizedBox.shrink();
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      color: const Color(0xFFEAAD9F),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC95F5F).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Accident Details',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    data['status'] ?? 'Unknown',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text('Location: $latitude, $longitude',
                              style: TextStyle(color: Colors.white)),
                            if (accidentData['video_data'] != null && 
                                accidentData['video_data']['frame_urls'] != null) ...[
                              Text(
                                'Detection Accuracy: ${_formatDetectionAccuracy(accidentData['video_data']['frame_urls'])}%',
                                style: TextStyle(color: Colors.white)
                              ),
                            ],
                            SizedBox(height: 8),
                            if (data['status'] == 'Pending') ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _firestore.collection('ambulances').doc(ambulanceDoc.id).update({
                                        'status': 'Rejected',
                                        'rejected_by': widget.ambulanceId,
                                        'rejected_at': FieldValue.serverTimestamp(),
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: Color(0xFFC95F5F),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Color(0xFFC95F5F),
                                    ),
                                    onPressed: () async {
                                      if (_currentPosition != null) {
                                        await _acceptAccident(context, accidentId, accidentData);
                                      }
                                    },
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ] else if (data['status'] == 'En Route') ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Color(0xFFC95F5F),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => NavigationPage(
                                            accidentId: accidentId,
                                            latitude: latitude!,
                                            longitude: longitude!,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Navigate'),
                                  ),
                                ],
                              ),
                            ],
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

  Future<void> _acceptAccident(BuildContext context, String accidentId, Map<String, dynamic> accidentData) async {
    try {
      setState(() => _isLoadingNotifier.value = true);
      developer.log('Starting accident acceptance process');
      developer.log('Accident ID: $accidentId');
      developer.log('Accident Data: $accidentData');

      if (_currentPosition == null) {
        throw Exception('Location not available');
      }

      double destinationLat;
      double destinationLng;
      final location = accidentData['location'];
      if (location is GeoPoint) {
        destinationLat = location.latitude;
        destinationLng = location.longitude;
      } else if (location is Map) {
        destinationLat = location['latitude'] as double;
        destinationLng = location['longitude'] as double;
      } else {
        throw Exception('Invalid location format');
      }

      // Create a new document in the ambulances collection for this accident
      await _firestore.collection('ambulances').doc(accidentId).set({
        'status': 'En Route',
        'ambulance_id': widget.ambulanceId,
        'accident_id': accidentId,
        'current_destination': {
          'latitude': destinationLat,
          'longitude': destinationLng,
        },
        'current_location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        },
        'location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'heading': _currentPosition!.heading,
          'speed': _currentPosition!.speed,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'last_updated': FieldValue.serverTimestamp(),
        'accepted_at': FieldValue.serverTimestamp(),
        'accident_data': accidentData
      });

      // Create the police notification
      await _firestore.collection('police').add({
        'ambulance_id': widget.ambulanceId,
        'accident_id': accidentId,
        'accident_details': {
          'destination': {
            'latitude': destinationLat,
            'longitude': destinationLng,
          },
          'detection_accuracy': accidentData['video_data'] != null && 
              accidentData['video_data']['frame_urls'] != null ? _formatDetectionAccuracy(accidentData['video_data']['frame_urls']) : '0.0',
        },
        'location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        },
        'status': 'En Route',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoadingNotifier.value = false);
      }

      // Navigate to the navigation page
      if (context.mounted) {
        // Use WidgetsBinding to ensure navigation happens after the current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => NavigationPage(
                accidentId: accidentId,
                latitude: destinationLat,
                longitude: destinationLng,
              ),
            ),
          );
        });
      }
    } catch (e, stackTrace) {
      developer.log('Error accepting accident:', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isLoadingNotifier.value = false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting accident: $e')),
        );
      }
    }
  }

  String _formatDetectionAccuracy(List<dynamic> frameUrls) {
    if (frameUrls.isEmpty) return '0.0';
    
    // Get confidence values from the first 3 frames (or less if fewer frames exist)
    List<double> confidences = [];
    for (int i = 0; i < min(3, frameUrls.length); i++) {
      if (frameUrls[i] is Map && frameUrls[i]['confidence'] != null) {
        confidences.add(frameUrls[i]['confidence'] as double);
      }
    }
    
    if (confidences.isEmpty) return '0.0';
    
    // Calculate average confidence
    double avgConfidence = confidences.reduce((a, b) => a + b) / confidences.length;
    return (avgConfidence * 100).toStringAsFixed(1);
  }
} 