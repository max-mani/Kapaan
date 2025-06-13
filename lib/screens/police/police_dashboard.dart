import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart'; // For formatting timestamp
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';  // Add this import for json
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'ambulance_tracking_page.dart';
import 'package:kapaan/services/location_service.dart';
import 'dart:developer' as developer;
import 'package:kapaan/services/auth_service.dart';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class PoliceDashboard extends StatefulWidget {
  const PoliceDashboard({super.key});

  @override
  _PoliceDashboardState createState() => _PoliceDashboardState();
}

class _PoliceDashboardState extends State<PoliceDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final AuthService _auth = AuthService();
  GoogleMapController? _mapController;
  LatLng? _policeLocation;
  bool _isLoading = false;
  String _errorMessage = '';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  StreamSubscription<QuerySnapshot>? _policeSubscription;
  PolylinePoints polylinePoints = PolylinePoints();
  
  // Store routes for each ambulance
  Map<String, List<LatLng>> _ambulanceRoutes = {};

  // Custom marker icons
  BitmapDescriptor? ambulanceIcon;
  BitmapDescriptor? accidentIcon;
  BitmapDescriptor? policeIcon;

  // Define a constant size for all markers
  static const int markerSize = 80; // Updated to match ambulance dashboard

  // Google Maps API key
  static const String googleMapsApiKey = 'AIzaSyAO6GWUCO-D89NzEPybYOU1MkIgKno7o0o';

  Future<Uint8List> resizeImage(Uint8List data) async {
    final ui.Codec codec = await ui.instantiateImageCodec(data);
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image image = fi.image;

    final double scale = markerSize / max(image.width, image.height);
    final int targetWidth = (image.width * scale).round();
    final int targetHeight = (image.height * scale).round();

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    canvas.drawImageRect(
      image,
      Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTRB(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image resizedImage = await picture.toImage(targetWidth, targetHeight);
    final ByteData? byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  @override
  void initState() {
    super.initState();
    _initializeLocationAndMarkers();
    _setupPoliceStream();
  }

  void _setupPoliceStream() {
    _policeSubscription = _firestore.collection('police').snapshots().listen((snapshot) {
      if (mounted) {
        _updateMarkers(snapshot.docs);
      }
    });
  }

  Future<void> _initializeLocationAndMarkers() async {
    try {
      await _requestLocationPermission();
      await _loadCustomMarkers();
      await _getCurrentLocation();
    } catch (e) {
      developer.log('Error in initialization: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing: $e';
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      setState(() {
        _errorMessage = 'Location services are disabled. Please enable location services.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permissions are denied. Please enable them in settings.';
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'Location permissions are permanently denied. Please enable them in settings.';
      });
      return;
    }
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final ByteData ambulanceData = await rootBundle.load('assets/images/ambulance.png');
      final ByteData accidentData = await rootBundle.load('assets/images/accident.png');
      final ByteData policeData = await rootBundle.load('assets/images/policeman.png');

      // Resize all images to the same size while maintaining aspect ratio
      final Uint8List resizedAmbulanceData = await resizeImage(ambulanceData.buffer.asUint8List());
      final Uint8List resizedAccidentData = await resizeImage(accidentData.buffer.asUint8List());
      final Uint8List resizedPoliceData = await resizeImage(policeData.buffer.asUint8List());

      if (mounted) {
        setState(() {
          ambulanceIcon = BitmapDescriptor.fromBytes(resizedAmbulanceData);
          accidentIcon = BitmapDescriptor.fromBytes(resizedAccidentData);
          policeIcon = BitmapDescriptor.fromBytes(resizedPoliceData);
        });
      }
    } catch (e) {
      developer.log('Error loading markers: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading markers: $e';
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _policeLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });

        if (_mapController != null && _policeLocation != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_policeLocation!, 15),
          );
        }
      }
    } catch (e) {
      developer.log('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error getting location: $e';
        });
      }
    }
  }

  Future<List<LatLng>> getRouteCoordinates(LatLng origin, LatLng destination) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&alternatives=true'  // Get alternative routes
          '&optimize=true'      // Optimize the route
          '&key=$googleMapsApiKey';

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        
        if (decoded['status'] == 'OK') {
          final routes = decoded['routes'] as List;
          if (routes.isNotEmpty) {
            // Get the first (best) route
            final route = routes[0];
            final encodedPolyline = route['overview_polyline']['points'] as String;
            
            // Decode the polyline points
            final List<PointLatLng> decodedPolyline = polylinePoints.decodePolyline(encodedPolyline);
            
            // Convert to LatLng list
            return decodedPolyline
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
          }
        } else {
          developer.log('Directions API error: ${decoded['status']}');
        }
      }
      throw Exception('Failed to get route');
    } catch (e) {
      developer.log('Error getting route: $e');
      return [];
    }
  }

  void _updateMarkers(List<QueryDocumentSnapshot> documents) async {
    if (!mounted) return;

    final Set<Marker> newMarkers = {};
    final Set<Polyline> newPolylines = {};
    Map<String, List<LatLng>> newRoutes = {};

    // Add police location marker
    if (_policeLocation != null && policeIcon != null) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('police_location'),
          position: _policeLocation!,
          icon: policeIcon!,
          infoWindow: InfoWindow(
            title: 'Police Location',
            snippet: 'Your current location',
          ),
        ),
      );
    }

    // Process each document
    for (var doc in documents) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final ambulanceId = data['ambulance_id'] as String? ?? 'Unknown';
        final locationData = data['location'] as Map<String, dynamic>?;
        final accidentData = data['accident_details'] as Map<String, dynamic>?;

        if (locationData != null && accidentData != null) {
          // Add ambulance marker
          final ambulanceLocation = LatLng(
            locationData['latitude'] as double,
            locationData['longitude'] as double,
          );

          if (ambulanceIcon != null) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('ambulance_$ambulanceId'),
                position: ambulanceLocation,
                icon: ambulanceIcon!,
                infoWindow: InfoWindow(
                  title: 'Ambulance: $ambulanceId',
                  snippet: 'Status: ${data['status'] ?? 'Unknown'}',
                ),
              ),
            );
          }

          // Add accident marker
          final accidentLocation = LatLng(
            accidentData['destination']['latitude'] as double,
            accidentData['destination']['longitude'] as double,
          );

          if (accidentIcon != null) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('accident_${data['accident_id']}'),
                position: accidentLocation,
                icon: accidentIcon!,
                infoWindow: InfoWindow(
                  title: 'Accident Location',
                  snippet: 'Intensity: ${accidentData['intensity']}',
                ),
              ),
            );
          }

          // Get route between ambulance and accident location
          final routeCoordinates = await getRouteCoordinates(ambulanceLocation, accidentLocation);
          if (routeCoordinates.isNotEmpty) {
            newRoutes[ambulanceId] = routeCoordinates;
            
            newPolylines.add(
              Polyline(
                polylineId: PolylineId('route_$ambulanceId'),
                points: routeCoordinates,
                color: Colors.blue,
                width: 4,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                geodesic: true,
                patterns: [
                  PatternItem.dash(20.0),
                  PatternItem.gap(10.0),
                ],
              ),
            );
          } else {
            developer.log('No route found for ambulance $ambulanceId');
          }
        }
      } catch (e) {
        developer.log('Error processing document: $e');
      }
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
      _ambulanceRoutes = newRoutes;
    });

    // Update camera to show all markers and routes
    _updateCameraToShowAllMarkers();
  }

  void _updateCameraToShowAllMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    // Calculate bounds
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

    // Add padding to bounds
    final double padding = 0.01; // Approximately 1km padding
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
        50, // padding in pixels
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FC4EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C74AD),
        title: Text('Police Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () => _auth.signOut(context),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: Icon(Icons.my_location, color: Colors.white),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: _buildMap(),
          ),
          Expanded(
            flex: 1,
            child: _buildAmbulanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage,
                style: TextStyle(color: Color(0xFF3C74AD)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeLocationAndMarkers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3C74AD),
                  foregroundColor: Colors.white,
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C74AD)),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _policeLocation ?? LatLng(11.0168445, 76.9558321),
        zoom: 15,
      ),
      markers: _markers,
      polylines: _polylines,
      onMapCreated: (controller) {
        _mapController = controller;
        if (_markers.isNotEmpty) {
          // Use a small delay to ensure the map is properly initialized
          Future.delayed(Duration(milliseconds: 500), () {
            _updateCameraToShowAllMarkers();
          });
        } else if (_policeLocation != null) {
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(_policeLocation!, 15),
          );
        }
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapType: MapType.normal,
      compassEnabled: true,
      zoomControlsEnabled: true,
      trafficEnabled: true,
    );
  }

  Widget _buildAmbulanceList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('police').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs;

        return Container(
          color: Colors.white,
          child: ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final data = documents[index].data() as Map<String, dynamic>;
              final ambulanceId = data['ambulance_id'] as String? ?? 'Unknown';
              final status = data['status'] as String? ?? 'Unknown';
              final timestamp = data['timestamp'] as Timestamp?;

              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Ambulance: $ambulanceId'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $status'),
                      if (timestamp != null)
                        Text('Time: ${DateFormat('MMM d, y HH:mm:ss').format(timestamp.toDate())}'),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3C74AD),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AmbulanceTrackingPage(
                            ambulanceId: ambulanceId,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.location_on, size: 20),
                    label: Text('Track'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _policeSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}