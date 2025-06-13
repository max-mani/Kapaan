import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:developer' as developer;

class NavigationPage extends StatefulWidget {
  final String accidentId;
  final double latitude;
  final double longitude;

  const NavigationPage({
    Key? key,
    required this.accidentId,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? mapController;
  LatLng? _ambulanceLocation;
  List<LatLng> polylineCoordinates = [];
  Map<String, List<LatLng>> alternativeRoutes = {};
  StreamSubscription<Position>? positionStream;
  String estimatedDuration = "Calculating...";
  String estimatedDistance = "Calculating...";
  int selectedRouteIndex = 0;
  List<Color> routeColors = [Colors.blue, Colors.green, Colors.red, Colors.purple];
  bool isLoading = true;
  Timer? _refreshTimer;
  String navigationMode = "Initializing...";
  List<Map<String, dynamic>> routeInfo = [];
  
  Map<String, List<Map<String, dynamic>>> trafficSegments = {};
  int bestRouteIndex = 0;
  BitmapDescriptor? ambulanceIcon;
  BitmapDescriptor? accidentIcon;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  String _currentLoadingStep = '';
  int _currentStepIndex = 0;
  final List<Map<String, dynamic>> _loadingSteps = [
    {'title': 'Updating Location', 'description': 'Getting current position...', 'color': Colors.blue, 'duration': 600},
    {'title': 'Calculating Routes', 'description': 'Finding possible paths...', 'color': Colors.purple, 'duration': 400},
    {'title': 'Analyzing Traffic', 'description': 'Checking road conditions...', 'color': Colors.orange, 'duration': 400},
    {'title': 'Finding Best Route', 'description': 'Optimizing for fastest arrival...', 'color': Colors.green, 'duration': 600},
    {'title': 'Calculating ETA', 'description': 'Estimating arrival time...', 'color': Colors.teal, 'duration': 400},
    {'title': 'Finalizing Details', 'description': 'Preparing navigation...', 'color': Colors.indigo, 'duration': 600},
  ];
  bool _isLoadingComplete = false;

  static const int markerSize = 80;

  final Completer<GoogleMapController> _controller = Completer();
  final PolylinePoints _polylinePoints = PolylinePoints();
  final String _googleMapsApiKey = "AIzaSyAO6GWUCO-D89NzEPybYOU1MkIgKno7o0o";   

  @override
  void initState() {
    super.initState();
    print("NavigationPage initState");
    _loadCustomMarkers().then((_) {
      _getAmbulanceLocation();
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _refreshTimer?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _getAmbulanceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location services are disabled"))
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permissions are denied"))
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location permissions are permanently denied"))
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _ambulanceLocation = LatLng(position.latitude, position.longitude);
      _updateMarkers();
    });

    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position newPosition) {
      setState(() {
        _ambulanceLocation = LatLng(newPosition.latitude, newPosition.longitude);
        _updateMarkers();
      });
    });

    _getRoute();
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
      print("Loading custom markers...");
      final ByteData ambulanceData = await rootBundle.load('assets/images/ambulance.png');
      final ByteData accidentData = await rootBundle.load('assets/images/accident.png');

      print("Resizing marker images...");
      final Uint8List resizedAmbulanceData = await resizeImage(ambulanceData.buffer.asUint8List());
      final Uint8List resizedAccidentData = await resizeImage(accidentData.buffer.asUint8List());

      print("Creating BitmapDescriptor from resized images...");
      ambulanceIcon = BitmapDescriptor.fromBytes(resizedAmbulanceData);
      accidentIcon = BitmapDescriptor.fromBytes(resizedAccidentData);

      print("Updating markers after loading...");
      if (mounted) {
        _updateMarkers();
      }
    } catch (e) {
      print('Error loading markers: $e');
      ambulanceIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      accidentIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  void _updateMarkers() {
    if (!mounted) return;

    print("Updating markers. Ambulance location: $_ambulanceLocation");
    setState(() {
      _markers = {};

      // Add ambulance marker if location is available
      if (_ambulanceLocation != null) {
        print("Adding ambulance marker at: ${_ambulanceLocation!.latitude}, ${_ambulanceLocation!.longitude}");
        _markers.add(
          Marker(
            markerId: const MarkerId('ambulance'),
            position: _ambulanceLocation!,
            icon: ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(
              title: 'Ambulance',
              snippet: 'Your Location',
            ),
          ),
        );
      }

      // Add accident marker
      print("Adding accident marker at: ${widget.latitude}, ${widget.longitude}");
      _markers.add(
        Marker(
          markerId: const MarkerId('accident'),
          position: LatLng(widget.latitude, widget.longitude),
          icon: accidentIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Accident',
            snippet: 'Destination',
          ),
        ),
      );

      print("Total markers: ${_markers.length}");
    });

    // Update camera to show both markers
    if (_markers.isNotEmpty && mapController != null) {
      _fitBoundsToMarkers();
    }
  }

  void _fitBoundsToMarkers() {
    if (_markers.isEmpty || mapController == null) return;

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

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,
      ),
    );
  }

  Future<void> _updatePolylines() async {
    if (_ambulanceLocation == null) return;

    try {
      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(_ambulanceLocation!.latitude, _ambulanceLocation!.longitude),
          destination: PointLatLng(widget.latitude, widget.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blue,
              points: polylineCoordinates,
              width: 5,
            ),
          };
        });

        // Update camera to show the entire route
        _updateCameraPosition(polylineCoordinates);
      } else {
        developer.log('No route found: ${result.errorMessage}');
      }
    } catch (e) {
      developer.log('Error updating polylines: $e');
    }
  }

  void _updateCameraPosition(List<LatLng> polylineCoordinates) {
    if (mapController == null) return;

    double minLat = _ambulanceLocation!.latitude;
    double maxLat = _ambulanceLocation!.latitude;
    double minLng = _ambulanceLocation!.longitude;
    double maxLng = _ambulanceLocation!.longitude;

    for (var point in polylineCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation to Accident: ${widget.accidentId}'),
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          _ambulanceLocation == null
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(target: _ambulanceLocation!, zoom: 14.5),
                  markers: _markers,
                  polylines: _buildPolylines(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: true,
                  onMapCreated: (controller) {
                    mapController = controller;
                    if (_ambulanceLocation != null) {
                      LatLngBounds bounds = _getBounds();
                      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
                    }
                  },
                ),
          
          Positioned(
            top: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "recenter",
                  onPressed: () {
                    if (_ambulanceLocation != null && mapController != null) {
                      mapController!.animateCamera(CameraUpdate.newCameraPosition(
                        CameraPosition(target: _ambulanceLocation!, zoom: 16),
                      ));
                    }
                  },
                  child: Icon(Icons.my_location),
                  backgroundColor: Colors.blue,
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "refresh",
                  onPressed: _getRoute,
                  child: Icon(Icons.refresh),
                  backgroundColor: Colors.green,
                  tooltip: "Recalculate route",
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "google",
                  onPressed: _forceGoogleDirections,
                  child: Icon(Icons.map),
                  backgroundColor: Colors.red,
                  tooltip: "Force Google Directions",
                ),
              ],
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: SingleChildScrollView(
                      physics: ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time, color: Colors.red, size: 20),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ETA',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            Text(
                                              estimatedDuration,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.directions_car, color: Colors.blue, size: 20),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Distance',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            Text(
                                              estimatedDistance,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                          
                          if (alternativeRoutes.length > 1 && !isLoading)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 8.0),
                                  child: Text(
                                    'Selected Route',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: routeInfo.length,
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    itemBuilder: (context, index) {
                                      bool isBestRoute = routeInfo[index]['isBestRoute'] ?? false;
                                      bool isSelected = routeInfo[index]['isSelected'] ?? false;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: InkWell(
                                          onTap: () => _selectRoute(index),
                                          child: Container(
                                            width: 120,
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.blue : Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected ? Colors.blue : Colors.grey.shade300,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (isBestRoute)
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                        margin: EdgeInsets.only(right: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green,
                                                          borderRadius: BorderRadius.circular(2),
                                                        ),
                                                        child: Text(
                                                          'BEST',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 7,
                                                          ),
                                                        ),
                                                      ),
                                                    Flexible(
                                                      child: Text(
                                                        routeInfo[index]['duration'],
                                                        style: TextStyle(
                                                          color: isSelected ? Colors.white : Colors.black87,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 2),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      routeInfo[index]['distance'],
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isSelected ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    _buildTrafficIcon(routeInfo[index]['trafficStatus'], isSelected),
                                                  ],
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  routeInfo[index]['summary'],
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isSelected ? Colors.white70 : Colors.black54,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          
                          if (selectedRouteIndex < routeInfo.length && !isLoading)
                            Container(
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Route Details',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  _buildDetailRow(
                                    Icons.route, 
                                    'Route Name', 
                                    routeInfo[selectedRouteIndex]['summary']
                                  ),
                                  _buildDetailRow(
                                    Icons.access_time, 
                                    'Travel Time', 
                                    routeInfo[selectedRouteIndex]['duration']
                                  ),
                                  _buildDetailRow(
                                    Icons.directions_car, 
                                    'Distance', 
                                    routeInfo[selectedRouteIndex]['distance']
                                  ),
                                  _buildDetailRow(
                                    Icons.traffic, 
                                    'Traffic Conditions', 
                                    routeInfo[selectedRouteIndex]['trafficStatus'] ?? 'Unknown'
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          if (isLoading && !_isLoadingComplete)
            _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // Helper method to build traffic icon
  Widget _buildTrafficIcon(String? trafficStatus, bool isSelected) {
    IconData iconData;
    Color iconColor;
    
    switch (trafficStatus) {
      case "Heavy traffic":
        iconData = Icons.traffic;
        iconColor = Colors.red;
        break;
      case "Moderate traffic":
        iconData = Icons.traffic;
        iconColor = Colors.orange;
        break;
      case "Light traffic":
        iconData = Icons.traffic;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.traffic;
        iconColor = Colors.green;
    }
    
    return Icon(
      iconData,
      size: 14,
      color: isSelected ? Colors.white70 : iconColor,
    );
  }

  // Build polylines for all routes
  Set<Polyline> _buildPolylines() {
    Set<Polyline> polylines = {};
    
    if (routeInfo.isEmpty || selectedRouteIndex >= routeInfo.length) {
      return polylines;
    }
    
    String selectedRouteName = routeInfo[selectedRouteIndex]['name'];
    
    if (trafficSegments.containsKey(selectedRouteName) && 
        trafficSegments[selectedRouteName] != null &&
        trafficSegments[selectedRouteName]!.isNotEmpty) {
      
      int segmentIndex = 0;
      for (var segment in trafficSegments[selectedRouteName]!) {
        if (segment['points'] != null && segment['points'].isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: PolylineId("segment_$segmentIndex"),
              points: segment['points'],
              color: segment['color'],
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
          segmentIndex++;
        }
      }
    } else {
      if (polylineCoordinates.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: PolylineId("selected_route"),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }
    }
    
    return polylines;
  }

  Future<void> _getRoute() async {
    if (_ambulanceLocation == null) return;
    
    setState(() {
      isLoading = true;
      _isLoadingComplete = false;
      _currentStepIndex = 0;
    });

    // Start the loading sequence
    await _updateLoadingSequence();
    
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  Future<void> _forceGoogleDirections() async {
    _getRoute(); // Just use the same method since we're only using Google Directions now
  }
  
  Future<bool> _useGoogleDirectionsOnly() async {
    try {
      String apiKey = _googleMapsApiKey;
      
      Uri uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
        'origin': '${_ambulanceLocation!.latitude},${_ambulanceLocation!.longitude}',
        'destination': '${widget.latitude},${widget.longitude}',
        'mode': 'driving',
        'alternatives': 'true',
        'units': 'metric',
        'key': apiKey,
      });
      
      print("Using Google Directions API: ${uri.toString()}");
      
      final response = await http.get(uri).timeout(Duration(seconds: 20));
      print("API Response status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("API Route status: ${data['status']}");
        
        if (data['status'] == 'OK') {
          print("Google Directions API request successful");
          _processDirectionsResponse(data);
          return true;
        } else {
          print("Google Directions API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}");
          
          if (data['status'] == 'REQUEST_DENIED') {
            String errorMessage = data['error_message'] ?? 'No specific error details provided';
            print("REQUEST_DENIED details: $errorMessage");
            
            _showApiKeyErrorDialog(errorMessage);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Google Maps API error: ${data['status']}. ${data['error_message'] ?? ''}"),
                duration: Duration(seconds: 8),
              ),
            );
          }
        }
      } else {
        print("HTTP error: ${response.statusCode}");
      }
      return false;
    } catch (e) {
      print("Error with Google Directions API: $e");
      return false;
    }
  }

  void _processDirectionsResponse(Map<String, dynamic> data) {
    var routes = data['routes'];
    if (routes != null && routes.length > 0) {
      // Clear previous alternative routes
      alternativeRoutes.clear();
      routeInfo.clear();
      trafficSegments.clear();
      
      // Find the shortest route by distance and best route by traffic
      int shortestDistanceValue = 999999999;
      int shortestRouteIndex = 0;
      
      // Find the best route (least traffic)
      int bestTrafficIndex = 0;
      int leastDurationValue = 999999999;
      
      // Process all routes from the API response
      for (int i = 0; i < routes.length; i++) {
        var route = routes[i];
        if (route['legs'] != null && route['legs'].length > 0) {
          var leg = route['legs'][0];
          int distanceValue = leg['distance']['value'];
          int durationValue = leg['duration']['value'];
          
          // Check if this is the shortest route
          if (distanceValue < shortestDistanceValue) {
            shortestDistanceValue = distanceValue;
            shortestRouteIndex = i;
          }
          
          // Check if this is the fastest route (best for traffic)
          if (durationValue < leastDurationValue) {
            leastDurationValue = durationValue;
            bestTrafficIndex = i;
          }
          
          // Get the main polyline for this route
          String encodedPolyline = route['overview_polyline']['points'];
          List<LatLng> decodedPoints = [];
          
          try {
            List<List<num>> decodedResult = decodePolyline(encodedPolyline);
            decodedPoints = decodedResult.map((point) => 
              LatLng(point[0].toDouble(), point[1].toDouble())
            ).toList();
          } catch (e) {
            PolylinePoints polylinePoints = PolylinePoints();
            List<PointLatLng> points = polylinePoints.decodePolyline(encodedPolyline);
            decodedPoints = points.map((point) => 
              LatLng(point.latitude, point.longitude)
            ).toList();
          }
          
          if (decodedPoints.isNotEmpty) {
            String distance = leg['distance']['text'];
            String duration = leg['duration']['text'];
            String summary = route['summary'] ?? 'Route ${i + 1}';
            
            String routeName = i == 0 ? "Main Route" : "Alternative ${i}";
            alternativeRoutes[routeName] = decodedPoints;
            
            List<Map<String, dynamic>> segments = [];
            
            if (leg['steps'] != null) {
              for (var step in leg['steps']) {
                double trafficRatio = _simulateTrafficCondition(step);
                
                if (step['polyline'] != null && step['polyline']['points'] != null) {
                  String stepPolyline = step['polyline']['points'];
                  List<LatLng> stepPoints = [];
                  
                  try {
                    List<List<num>> stepDecodedResult = decodePolyline(stepPolyline);
                    stepPoints = stepDecodedResult.map((point) => 
                      LatLng(point[0].toDouble(), point[1].toDouble())
                    ).toList();
                  } catch (e) {
                    try {
                      PolylinePoints polylinePoints = PolylinePoints();
                      List<PointLatLng> points = polylinePoints.decodePolyline(stepPolyline);
                      stepPoints = points.map((point) => 
                        LatLng(point.latitude, point.longitude)
                      ).toList();
                    } catch (e) {
                      continue;
                    }
                  }
                  
                  if (stepPoints.isNotEmpty) {
                    String trafficLevel = "normal";
                    Color trafficColor = Colors.green;
                    
                    if (trafficRatio >= 1.5) {
                      trafficLevel = "heavy";
                      trafficColor = Colors.red;
                    } else if (trafficRatio >= 1.2) {
                      trafficLevel = "moderate";
                      trafficColor = Colors.orange;
                    }
                    
                    segments.add({
                      'points': stepPoints,
                      'traffic_level': trafficLevel,
                      'color': trafficColor,
                      'description': step['html_instructions'] ?? 'Continue'
                    });
                  }
                }
              }
            }
            
            trafficSegments[routeName] = segments;
            
            bool hasTraffic = route.containsKey('legs') && 
                             route['legs'][0].containsKey('duration_in_traffic');
            
            String trafficStatus = _determineTrafficStatus(segments);
            
            routeInfo.add({
              'name': routeName,
              'distance': distance,
              'duration': duration,
              'summary': summary,
              'isSelected': false,
              'hasTraffic': hasTraffic,
              'trafficStatus': trafficStatus,
              'isBestRoute': false,
            });
          }
        }
      }
      
      if (routeInfo.isEmpty) {
        print("No valid routes found");
        return;
      }
      
      bestRouteIndex = min(bestTrafficIndex, routeInfo.length - 1);
      
      if (bestRouteIndex < routeInfo.length) {
        routeInfo[bestRouteIndex]['isBestRoute'] = true;
      }
      
      selectedRouteIndex = bestRouteIndex;
      if (selectedRouteIndex < routeInfo.length) {
        routeInfo[selectedRouteIndex]['isSelected'] = true;
      }
      
      if (alternativeRoutes.isNotEmpty) {
        String mainRouteName = routeInfo[selectedRouteIndex]['name'];
        polylineCoordinates = alternativeRoutes[mainRouteName] ?? [];
        
        String distance = routeInfo[selectedRouteIndex]['distance'];
        String duration = routeInfo[selectedRouteIndex]['duration'];
        
        setState(() {
          polylineCoordinates = alternativeRoutes[mainRouteName] ?? [];
          estimatedDistance = distance;
          estimatedDuration = _formatDuration(duration);
          navigationMode = "Google Maps";
        });
        
        if (mapController != null && polylineCoordinates.isNotEmpty) {
          LatLngBounds bounds = _getBoundsForPoints(polylineCoordinates);
          mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
        }
      }
    }
  }

  double _simulateTrafficCondition(Map<String, dynamic> step) {
    int hashCode = step.toString().hashCode;
    Random random = Random(hashCode.abs());
    double value = random.nextDouble();
    
    if (value < 0.7) {
      return 1.0 + (random.nextDouble() * 0.2);
    } else if (value < 0.9) {
      return 1.2 + (random.nextDouble() * 0.3);
    } else {
      return 1.5 + (random.nextDouble() * 0.5);
    }
  }
  
  String _determineTrafficStatus(List<Map<String, dynamic>> segments) {
    if (segments.isEmpty) return "No traffic data";
    
    int heavyCount = 0;
    int moderateCount = 0;
    
    for (var segment in segments) {
      if (segment['traffic_level'] == 'heavy') {
        heavyCount++;
      } else if (segment['traffic_level'] == 'moderate') {
        moderateCount++;
      }
    }
    
    if (heavyCount > segments.length * 0.25) {
      return "Heavy traffic";
    } else if ((heavyCount + moderateCount) > segments.length * 0.4) {
      return "Moderate traffic";
    } else {
      return "Light traffic";
    }
  }

  LatLngBounds _getBoundsForPoints(List<LatLng> points) {
    if (points.isEmpty) {
      // Return a default bounds if no points are available
      return LatLngBounds(
        southwest: LatLng(0, 0),
        northeast: LatLng(0, 0)
      );
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final double padding = 0.01;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng)
    );
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return "Unknown";
    
    if (duration is String) {
      RegExp hourMinRegExp = RegExp(r'(\d+)\s*h(?:ours?)?\s*(?:(\d+)\s*m(?:in(?:ute)?s?)?)?');
      var hourMinMatches = hourMinRegExp.firstMatch(duration);
      
      if (hourMinMatches != null) {
        String hours = hourMinMatches.group(1) ?? "0";
        String minutes = hourMinMatches.group(2) ?? "0";
        return "${hours} hr ${minutes} min";
      }
      
      RegExp minRegExp = RegExp(r'(\d+)\s*m(?:in(?:ute)?s?)?');
      var minMatches = minRegExp.firstMatch(duration);
      
      if (minMatches != null) {
        return "${minMatches.group(1)} min";
      }
      
      return duration;
    }
    
    if (duration is int || duration is double) {
      int seconds = duration.toInt();
      int minutes = seconds ~/ 60;
      int hours = minutes ~/ 60;
      minutes = minutes % 60;
      
      if (hours > 0) {
        return "$hours hr $minutes min";
      } else {
        return "$minutes min";
      }
    }
    
    return "Unknown";
  }

  void _showApiKeyErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Google Maps API Key Error'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('The provided API key is not authorized to use the Directions API.'),
                SizedBox(height: 12),
                Text('Error details: $errorMessage'),
                SizedBox(height: 16),
                Text('To fix this issue:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('1. Go to the Google Cloud Console'),
                Text('2. Select your project'),
                Text('3. Navigate to "APIs & Services" > "Enabled APIs"'),
                Text('4. Click "+ ENABLE APIS AND SERVICES"'),
                Text('5. Search for "Directions API" and enable it'),
                Text('6. Make sure billing is enabled for your project'),
                SizedBox(height: 12),
                Text('If the issue persists, check for:'),
                Text('• API Key restrictions (HTTP referrers, IP addresses)'),
                Text('• Billing status of your Google Cloud account'),
                Text('• Whether your account has access to the Directions API'),
                SizedBox(height: 16),
                Text('A temporary route will be shown while this issue is being fixed.', 
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue)),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Retry'),
              onPressed: () {
                Navigator.of(context).pop();
                _getRoute();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateLoadingSequence() async {
    await Future.delayed(Duration(milliseconds: 800));
    
    Future<void> navigationProcess = _performNavigationProcess();
    
    for (int i = 0; i < _loadingSteps.length; i++) {
      if (mounted) {
        setState(() {
          _currentStepIndex = i;
        });
      }
      
      await Future.delayed(Duration(milliseconds: _loadingSteps[i]['duration']));
    }
    
    await navigationProcess;
    await Future.delayed(Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() {
        _isLoadingComplete = true;
      });
    }
  }

  Future<void> _performNavigationProcess() async {
    try {
      print("Using Google Directions API exclusively...");
      bool googleSuccess = await _useGoogleDirectionsOnly();
      
      if (!googleSuccess) {
        print("Google Maps API request failed");
        _generateRoadPath();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Using an estimated route temporarily while API key issue is fixed"),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print("Error generating route: $e");
      _generateRoadPath();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating route. Using estimated path temporarily."),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: _getRoute,
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _generateRoadPath() {
    print("Generating road-like path as a temporary fallback");
    
    double straightDistance = _calculateDistance(
      _ambulanceLocation!.latitude, _ambulanceLocation!.longitude, 
      widget.latitude, widget.longitude
    );
    
    int pointCount = min(max((straightDistance / 50).round(), 20), 100);
    
    List<LatLng> roadPath = _generateSnappedToRoadPath(
      _ambulanceLocation!, 
      LatLng(widget.latitude, widget.longitude),
      pointCount
    );
    
    double pathDistance = _calculatePathDistance(roadPath);
    String distance = "${(pathDistance / 1000).toStringAsFixed(1)} km";
    
    int timeInMinutes = (pathDistance / 1000 / 40 * 60).round();
    String duration = timeInMinutes > 60 
        ? "${timeInMinutes ~/ 60} hr ${timeInMinutes % 60} min" 
        : "$timeInMinutes min";
    
    setState(() {
      polylineCoordinates = roadPath;
      estimatedDistance = distance;
      estimatedDuration = duration;
      navigationMode = "Temporary Route (API key issue)";
    });
    
    if (mapController != null) {
      LatLngBounds bounds = _getBounds();
      mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  List<LatLng> _generateSnappedToRoadPath(LatLng start, LatLng end, int pointCount) {
    List<LatLng> points = [];
    Random random = Random(start.latitude.toInt() * 1000 + end.longitude.toInt() * 1000);
    
    points.add(start);
    
    LatLng currentPoint = start;
    double remainingDistance = _calculateDistance(
      start.latitude, start.longitude,
      end.latitude, end.longitude
    );
    
    double coveredDistance = 0;
    
    while (coveredDistance < remainingDistance * 0.95) {
      double bearingToEnd = _calculateBearing(
        currentPoint.latitude, currentPoint.longitude,
        end.latitude, end.longitude
      );
      
      double roadBearing;
      
      if (random.nextDouble() < 0.7) {
        roadBearing = (((bearingToEnd + 22.5) / 45).floor() * 45) % 360;
      } else {
        roadBearing = bearingToEnd + (random.nextDouble() - 0.5) * 20;
      }
      
      double progress = coveredDistance / remainingDistance;
      double segmentLength = min(
        remainingDistance * 0.4 * (1 - progress),
        200 + random.nextDouble() * 300
      );
      
      Map<String, double> nextPoint = _destinationPoint(
        currentPoint.latitude, currentPoint.longitude,
        roadBearing, segmentLength
      );
      
      currentPoint = LatLng(nextPoint['latitude']!, nextPoint['longitude']!);
      points.add(currentPoint);
      
      coveredDistance += segmentLength;
    }
    
    points.add(end);
    points = _smoothPath(points);
    
    return points;
  }

  List<LatLng> _smoothPath(List<LatLng> points) {
    if (points.length <= 2) return points;
    
    List<LatLng> smoothed = [points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      LatLng prev = points[i - 1];
      LatLng current = points[i];
      LatLng next = points[i + 1];
      
      double lat = (prev.latitude + current.latitude * 2 + next.latitude) / 4;
      double lng = (prev.longitude + current.longitude * 2 + next.longitude) / 4;
      
      smoothed.add(LatLng(lat, lng));
    }
    
    smoothed.add(points.last);
    return smoothed;
  }

  double _calculateBearing(double startLat, double startLng, double endLat, double endLng) {
    double startLatRad = _toRadians(startLat);
    double startLngRad = _toRadians(startLng);
    double endLatRad = _toRadians(endLat);
    double endLngRad = _toRadians(endLng);
    
    double y = sin(endLngRad - startLngRad) * cos(endLatRad);
    double x = cos(startLatRad) * sin(endLatRad) -
              sin(startLatRad) * cos(endLatRad) * cos(endLngRad - startLngRad);
    
    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  Map<String, double> _destinationPoint(double lat, double lng, double bearing, double distance) {
    double earthRadius = 6371000;
    
    double bearingRad = _toRadians(bearing);
    double latRad = _toRadians(lat);
    double lngRad = _toRadians(lng);
    
    double angularDistance = distance / earthRadius;
    
    double newLatRad = asin(
      sin(latRad) * cos(angularDistance) +
      cos(latRad) * sin(angularDistance) * cos(bearingRad)
    );
    
    double newLngRad = lngRad + atan2(
      sin(bearingRad) * sin(angularDistance) * cos(latRad),
      cos(angularDistance) - sin(latRad) * sin(newLatRad)
    );
    
    return {
      'latitude': newLatRad * 180 / pi,
      'longitude': newLngRad * 180 / pi,
    };
  }

  double _calculatePathDistance(List<LatLng> points) {
    double totalDistance = 0;
    
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _calculateDistance(
        points[i].latitude, points[i].longitude,
        points[i + 1].latitude, points[i + 1].longitude
      );
    }
    
    return totalDistance * 1.1;
  }

  double _calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    const int earthRadius = 6371000;
    
    double latDiff = _toRadians(endLat - startLat);
    double lngDiff = _toRadians(endLng - startLng);
    
    double a = sin(latDiff / 2) * sin(latDiff / 2) +
              cos(_toRadians(startLat)) * cos(_toRadians(endLat)) *
              sin(lngDiff / 2) * sin(lngDiff / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    
    return distance;
  }
  
  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  LatLngBounds _getBounds() {
    double minLat = _ambulanceLocation!.latitude;
    double maxLat = widget.latitude;
    double minLng = _ambulanceLocation!.longitude;
    double maxLng = widget.longitude;
    
    if (_ambulanceLocation!.latitude > widget.latitude) {
      minLat = widget.latitude;
      maxLat = _ambulanceLocation!.latitude;
    }
    
    if (_ambulanceLocation!.longitude > widget.longitude) {
      minLng = widget.longitude;
      maxLng = _ambulanceLocation!.longitude;
    }
    
    minLat -= 0.05;
    maxLat += 0.05;
    minLng -= 0.05;
    maxLng += 0.05;
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng)
    );
  }

  void _selectRoute(int index) {
    if (index < alternativeRoutes.length && index < routeInfo.length) {
      setState(() {
        for (var info in routeInfo) {
          info['isSelected'] = false;
        }
        
        selectedRouteIndex = index;
        routeInfo[index]['isSelected'] = true;
        
        String routeName = routeInfo[index]['name'];
        polylineCoordinates = alternativeRoutes[routeName] ?? [];
        
        estimatedDistance = routeInfo[index]['distance'];
        estimatedDuration = _formatDuration(routeInfo[index]['duration']);
      });
      
      if (mapController != null) {
        LatLngBounds bounds = _getBoundsForPoints(polylineCoordinates);
        mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    }
  }

  // Extract points from steps if polyline decoding fails
  List<LatLng> _extractPointsFromSteps(List<dynamic> steps) {
    List<LatLng> points = [];
    
    for (var step in steps) {
      if (step['start_location'] != null) {
        points.add(LatLng(
          step['start_location']['lat'], 
          step['start_location']['lng']
        ));
      }
      
      if (step['end_location'] != null) {
        points.add(LatLng(
          step['end_location']['lat'], 
          step['end_location']['lng']
        ));
      }
      
      // Try to decode the polyline for this step too
      if (step['polyline'] != null && step['polyline']['points'] != null) {
        try {
          String stepPolyline = step['polyline']['points'];
          List<List<num>> decodedResult = decodePolyline(stepPolyline);
          List<LatLng> stepPoints = decodedResult.map((point) => 
            LatLng(point[0].toDouble(), point[1].toDouble())
          ).toList();
          
          points.addAll(stepPoints);
        } catch (e) {
          print("Could not decode step polyline: $e");
        }
      }
    }
    
    return points;
  }

  // Helper method to decode polylines
  List<List<num>> decodePolyline(String encoded) {
    List<List<num>> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;

      // Decode latitude
      do {
        result |= (encoded.codeUnitAt(index) - 63 - 1) << shift;
        shift += 5;
        index++;
      } while (index < len && encoded.codeUnitAt(index - 1) >= 0x20);

      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;

      do {
        result |= (encoded.codeUnitAt(index) - 63 - 1) << shift;
        shift += 5;
        index++;
      } while (index < len && encoded.codeUnitAt(index - 1) >= 0x20);

      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add([lat / 1e5, lng / 1e5]);
    }

    return points;
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _loadingSteps[_currentStepIndex]['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step ${_currentStepIndex + 1} of ${_loadingSteps.length}',
                  style: TextStyle(
                    color: _loadingSteps[_currentStepIndex]['color'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                _loadingSteps[_currentStepIndex]['title'],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _loadingSteps[_currentStepIndex]['color'],
                ),
              ),
              SizedBox(height: 12),
              Text(
                _loadingSteps[_currentStepIndex]['description'],
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              Container(
                height: 10,
                width: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Stack(
                  children: [
                    Container(
                      width: 250 * ((_currentStepIndex + 1) / _loadingSteps.length),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: LinearGradient(
                          colors: [
                            _loadingSteps[_currentStepIndex]['color'],
                            _loadingSteps[_currentStepIndex]['color'].withOpacity(0.7),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                '${((_currentStepIndex + 1) / _loadingSteps.length * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _loadingSteps[_currentStepIndex]['color'],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
} 