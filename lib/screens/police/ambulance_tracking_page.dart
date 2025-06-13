import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:math';

class AmbulanceTrackingPage extends StatefulWidget {
  final String ambulanceId;

  const AmbulanceTrackingPage({
    Key? key,
    required this.ambulanceId,
  }) : super(key: key);

  @override
  _AmbulanceTrackingPageState createState() => _AmbulanceTrackingPageState();
}

class _AmbulanceTrackingPageState extends State<AmbulanceTrackingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  Position? _policeLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _locationTimer;
  StreamSubscription? _policeStream;
  StreamSubscription? _ambulanceStream;
  PolylinePoints polylinePoints = PolylinePoints();

  // Custom marker icons
  BitmapDescriptor? ambulanceIcon;
  BitmapDescriptor? accidentIcon;
  BitmapDescriptor? policeIcon;

  // Define a constant size for all markers
  static const int markerSize = 80;

  // Google Maps API key
  static const String googleMapsApiKey = 'AIzaSyAO6GWUCO-D89NzEPybYOU1MkIgKno7o0o';

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    await _loadCustomMarkers();
    await _getCurrentLocation();
    _startLocationUpdates();
    _startAmbulanceTracking();
  }

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
    }
  }

  Future<List<LatLng>> getRouteCoordinates(LatLng origin, LatLng destination) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&alternatives=true'
          '&optimize=true'
          '&key=$googleMapsApiKey';

      developer.log('Fetching route with URL: $url');

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        
        if (decoded['status'] == 'OK') {
          final routes = decoded['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0];
            final encodedPolyline = route['overview_polyline']['points'] as String;
            
            final List<PointLatLng> decodedPolyline = polylinePoints.decodePolyline(encodedPolyline);
            
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

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _policeLocation = position;
        _updateMarkers();
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );
      }
    } catch (e) {
      developer.log('Error getting location: $e');
    }
  }

  void _startLocationUpdates() {
    // Update police location every 5 seconds
    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _getCurrentLocation();
    });

    // Listen to police location stream
    _policeStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _policeLocation = position;
        _updateMarkers();
      });
    });
  }

  void _startAmbulanceTracking() {
    _ambulanceStream = _firestore
        .collection('police')
        .where('ambulance_id', isEqualTo: widget.ambulanceId)
        .snapshots()
        .listen((snapshot) async {
      try {
        if (snapshot.docs.isEmpty) {
          developer.log('No ambulance found with ID: ${widget.ambulanceId}');
          return;
        }

        final data = snapshot.docs.first.data();
        
        // Get ambulance's current location
        final locationData = data['location'] as Map<String, dynamic>?;
        // Get accident location
        final accidentData = data['accident_details'] as Map<String, dynamic>?;
        final accidentDestination = accidentData?['destination'] as Map<String, dynamic>?;

        if (locationData != null && accidentDestination != null) {
          final ambulanceLocation = LatLng(
            locationData['latitude'] as double,
            locationData['longitude'] as double,
          );

          final accidentLocation = LatLng(
            accidentDestination['latitude'] as double,
            accidentDestination['longitude'] as double,
          );

          // Get route between current ambulance location and accident location
          final routeCoordinates = await getRouteCoordinates(
            ambulanceLocation,
            accidentLocation
          );

          if (!mounted) return;

          setState(() {
            _markers.clear();

            // Add ambulance marker
            if (ambulanceIcon != null) {
              _markers.add(
                Marker(
                  markerId: MarkerId('ambulance_${widget.ambulanceId}'),
                  position: ambulanceLocation,
                  icon: ambulanceIcon!,
                  infoWindow: InfoWindow(
                    title: 'Ambulance ${widget.ambulanceId}',
                    snippet: 'Status: ${data['status'] ?? 'Unknown'}',
                  ),
                ),
              );
            }

            // Add accident location marker
            if (accidentIcon != null) {
              _markers.add(
                Marker(
                  markerId: MarkerId('accident_${data['accident_id']}'),
                  position: accidentLocation,
                  icon: accidentIcon!,
                  infoWindow: InfoWindow(
                    title: 'Accident Location',
                    snippet: 'Intensity: ${accidentData?['intensity'] ?? 'Unknown'}',
                  ),
                ),
              );
            }

            // Update polyline with the route
            _polylines.clear();
            if (routeCoordinates.isNotEmpty) {
              _polylines.add(
                Polyline(
                  polylineId: PolylineId('route_${widget.ambulanceId}'),
                  points: routeCoordinates,
                  color: Colors.red,
                  width: 5,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  geodesic: true,
                ),
              );
            }
          });

          // Update camera to show the entire route
          _updateCameraToShowAll(routeCoordinates);
        }
      } catch (e) {
        developer.log('Error in ambulance tracking: $e');
      }
    });
  }

  void _updateMarkers() {
    if (_policeLocation == null) return;

    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'police_location');

      if (policeIcon != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('police_location'),
            position: LatLng(_policeLocation!.latitude, _policeLocation!.longitude),
            icon: policeIcon!,
            infoWindow: InfoWindow(
              title: 'Police Location',
              snippet: 'Your current location',
            ),
          ),
        );
      }
    });
  }

  void _updateCameraToShowAll(List<LatLng> routePoints) {
    if (routePoints.isEmpty || _mapController == null) return;

    // Calculate bounds including route points and markers
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    // Include route points
    for (var point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Include markers
    for (var marker in _markers) {
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
      appBar: AppBar(
        title: Text('Tracking Ambulance ${widget.ambulanceId}'),
        backgroundColor: const Color(0xFF3C74AD),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(11.073329, 77.002174), // Initial position
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            compassEnabled: true,
            zoomControlsEnabled: true,
            trafficEnabled: true,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _policeStream?.cancel();
    _ambulanceStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
} 