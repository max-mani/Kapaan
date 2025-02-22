import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NavigationPage extends StatefulWidget {
  final LatLng destination;
  final String ambulanceId;

  const NavigationPage({super.key, required this.destination, required this.ambulanceId});

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? mapController;
  LatLng? currentPosition;
  Set<Polyline> polylines = {};
  double eta = 0.0;
  BitmapDescriptor? ambulanceIcon;
  final String googleMapsApiKey = 'AIzaSyDVdFz1bUL5257HGHpuPXNbAwYiBX_XF40';

  @override
  void initState() {
    super.initState();
    loadAmbulanceMarker();
    trackAmbulanceLocation();
  }

  // Load custom ambulance marker
  void loadAmbulanceMarker() async {
    BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/ambulance_icon.png",
    );
    setState(() {
      ambulanceIcon = customIcon;
    });
  }

  // Track ambulance location
  Future<void> trackAmbulanceLocation() async {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) async {
      if (position.latitude == 0.0 && position.longitude == 0.0) return;
      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
      });
      updateRoute(position);
      calculateETA(position);
    });
  }

  // Calculate ETA
  void calculateETA(Position position) {
    const double avgSpeedKmH = 40.0;
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    ) / 1000;

    setState(() {
      eta = distance / avgSpeedKmH * 60;
    });
  }

  // Fetch route from Google Directions API
  Future<void> updateRoute(Position position) async {
    if (currentPosition == null) return;

    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${currentPosition!.latitude},${currentPosition!.longitude}&destination=${widget.destination.latitude},${widget.destination.longitude}&mode=driving&key=$googleMapsApiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isNotEmpty) {
        List<LatLng> routeCoordinates = [];
        var points = data['routes'][0]['overview_polyline']['points'];
        routeCoordinates = decodePolyline(points);

        setState(() {
          polylines.clear();
          polylines.add(Polyline(
            polylineId: const PolylineId("ambulance_route"),
            color: Colors.blue,
            width: 5,
            points: routeCoordinates,
          ));
        });
      }
    } else {
      print("Error fetching route: ${response.reasonPhrase}");
    }
  }

  // Decode polyline points
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polylineCoordinates = [];
    List<int> polyline = encoded.codeUnits;
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int byte;
      do {
        byte = polyline[index++] - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = polyline[index++] - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylineCoordinates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Navigation"), backgroundColor: Colors.blue),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(target: widget.destination, zoom: 14.0),
            markers: {
              Marker(markerId: const MarkerId("destination"), position: widget.destination),
              if (currentPosition != null)
                Marker(
                  markerId: const MarkerId("current"),
                  position: currentPosition!,
                  icon: ambulanceIcon ?? BitmapDescriptor.defaultMarker,
                ),
            },
            polylines: polylines,
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital, color: Colors.red, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          "Accident Location",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "ETA: ${eta.toStringAsFixed(1)} mins",
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
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
