import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

class NavigationPage extends StatefulWidget {
  final String accidentId;
  final double latitude;
  final double longitude;

  NavigationPage({required this.accidentId, required this.latitude, required this.longitude});

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? mapController;
  LatLng? _ambulanceLocation;
  List<LatLng> polylineCoordinates = [];
  StreamSubscription<Position>? positionStream;

  @override
  void initState() {
    super.initState();
    _getAmbulanceLocation();
  }

  /// Get ambulance's current location and update the route
  Future<void> _getAmbulanceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _ambulanceLocation = LatLng(position.latitude, position.longitude);
    });

    positionStream = Geolocator.getPositionStream().listen((Position newPosition) {
      setState(() {
        _ambulanceLocation = LatLng(newPosition.latitude, newPosition.longitude);
      });
      _getRoute();
    });

    _getRoute();
  }

  /// Fetch route from Google Maps API
  Future<void> _getRoute() async {
    if (_ambulanceLocation == null) return;

    String apiKey = "YOUR_GOOGLE_MAPS_API_KEY"; // Replace with your API key
    String url = "https://routes.googleapis.com/directions/v2:computeRoutes?key=$apiKey";

    Map<String, dynamic> body = {
      "origin": {"location": {"latLng": {"latitude": _ambulanceLocation!.latitude, "longitude": _ambulanceLocation!.longitude}}},
      "destination": {"location": {"latLng": {"latitude": widget.latitude, "longitude": widget.longitude}}},
      "travelMode": "DRIVE",
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json", "X-Goog-Api-Key": apiKey},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String polylineEncoded = data["routes"][0]["polyline"]["encodedPolyline"];
        List<List<double>> decodedPoints = decodePolyline(polylineEncoded)
            .map((e) => [e[0].toDouble(), e[1].toDouble()]).toList();
        setState(() {
          polylineCoordinates = decodedPoints.map((point) => LatLng(point[0], point[1])).toList();
        });
      } else {
        print("Failed to fetch route: ${response.body}");
      }
    } catch (e) {
      print("Error fetching route: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Navigation')),
      body: _ambulanceLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(target: _ambulanceLocation!, zoom: 14.5),
        markers: {
          Marker(markerId: MarkerId("ambulance"), position: _ambulanceLocation!),
          Marker(markerId: MarkerId("accident"), position: LatLng(widget.latitude, widget.longitude)),
        },
        polylines: {
          Polyline(polylineId: PolylineId("route"), points: polylineCoordinates, color: Colors.blue, width: 5),
        },
      ),
    );
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }
}
