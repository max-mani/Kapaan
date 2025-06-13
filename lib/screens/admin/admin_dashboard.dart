import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapaan/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:kapaan/widgets/full_screen_image.dart';
import 'dart:async';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE5E5), // Light red background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7070), // Dark red background
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFFFFE5E5),
                    title: Text('Clear All Accidents',
                      style: TextStyle(color: Color(0xFFFF7070)),
                    ),
                    content: Text('Are you sure you want to clear all accidents? This action cannot be undone.',
                      style: TextStyle(color: Color(0xFFFF7070)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel',
                          style: TextStyle(color: Color(0xFFFF7070)),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _clearAllAccidents();
                        },
                        child: Text('Clear All'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  );
                },
              );
            },
            icon: Icon(Icons.clear_all, color: Colors.white),
            label: Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _auth.signOut(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('accidents').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7070)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFFFF7070)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No accidents found',
                style: TextStyle(color: Color(0xFFFF7070), fontSize: 16),
              ),
            );
          }

          final accidents = snapshot.data!.docs;

          return ListView.builder(
            itemCount: accidents.length,
            itemBuilder: (context, index) {
              final accidentDoc = accidents[index];
              final accident = accidentDoc.data() as Map<String, dynamic>;
              final location = accident['location'] as Map<String, dynamic>?;
              final detectedFrames = accident['detected_frames'] as List<dynamic>? ?? [];
              final metadata = accident['metadata'] as Map<String, dynamic>? ?? {};
              final videoData = accident['video_data'] as Map<String, dynamic>? ?? {};

              return Card(
                margin: const EdgeInsets.all(8.0),
                color: const Color(0xFFFFE5E5),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7070).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with ID
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'ID: ${accident['id'] ?? accidentDoc.id}',
                              style: TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.white),
                            onPressed: () => _clearAccident(accidentDoc.id),
                            tooltip: 'Clear this accident',
                          ),
                        ],
                      ),
                      Divider(color: Colors.white30),

                      // Location information
                      if (location != null) ...[
                        SizedBox(height: 8),
                        Text(
                          'Location: (${location['latitude']?.toStringAsFixed(6)}, ${location['longitude']?.toStringAsFixed(6)})',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],

                      SizedBox(height: 8),

                      // Metadata section
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Metadata:', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Source: ${metadata['source_type'] ?? "Unknown"}',
                              style: TextStyle(color: Colors.white)),
                            Text('Model: ${metadata['detection_model'] ?? "Unknown"}',
                              style: TextStyle(color: Colors.white)),
                            if (metadata['processed_at'] != null)
                              Text('Processed at: ${_formatTimestamp(metadata['processed_at'])}',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),

                      SizedBox(height: 8),

                      // Detected Frames
                      if (detectedFrames.isNotEmpty) ...[
                        Text(
                          'Detected Frames:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          height: 170,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: detectedFrames.length,
                            itemBuilder: (context, frameIndex) {
                              final frame = detectedFrames[frameIndex];
                              final imageUrl = frame['image_url'] as String?;
                              
                              if (imageUrl == null || imageUrl.isEmpty) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  margin: EdgeInsets.only(right: 8.0),
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: Text(
                                      'No Image',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                );
                              }

                              return Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FullScreenImage(
                                              imagePath: imageUrl,
                                              isAsset: false,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.white24),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                      : null,
                                                  color: Colors.white,
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              print('Error loading image: $error');
                                              return Container(
                                                width: 120,
                                                height: 120,
                                                color: Colors.grey[300],
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.error_outline, color: Colors.red, size: 24),
                                                    SizedBox(height: 4),
                                                    Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                      child: Text(
                                                        'Failed to load',
                                                        style: TextStyle(fontSize: 12, color: Colors.red),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Confidence: ${(frame['confidence'] * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                    Text(
                                      _formatTimestamp(frame['timestamp']),
                                      style: TextStyle(fontSize: 10, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      SizedBox(height: 16),

                      // Video information
                      if (videoData.isNotEmpty) ...[
                        Text(
                          'Video Information:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Total Frames: ${videoData['total_frames'] ?? 0}',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          'Accident Frames: ${videoData['accident_frames'] ?? 0}',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          'Duration: ${videoData['duration']?.toStringAsFixed(2) ?? 0} seconds',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          'Format: ${videoData['format'] ?? "Unknown"}',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ],

                      // Video Player Section
                      if (videoData['video_url'] != null && videoData['video_url'].toString().isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'Accident Video:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Column(
                            children: [
                              AccidentVideoPlayer(videoUrl: videoData['video_url']),
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Duration: ${videoData['duration']?.toStringAsFixed(2) ?? "0"} seconds',
                                        style: TextStyle(fontSize: 14, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.fullscreen, color: Colors.white),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          PageRouteBuilder(
                                            opaque: false,
                                            pageBuilder: (context, animation, secondaryAnimation) => FullScreenVideoPlayer(
                                              videoUrl: videoData['video_url'],
                                              accidentId: accidentDoc.id,
                                            ),
                                          ),
                                        );
                                      },
                                      tooltip: 'Toggle Fullscreen',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 16),

                      // Status indicators and buttons
                      Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (accident['reported'] != true)
                              ElevatedButton(
                                onPressed: () => _allocateAmbulance(accidentDoc.id, accident),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Color(0xFFFF7070),
                                ),
                                child: Text('Report'),
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  accident['reported'] == true ? Icons.check_circle : Icons.pending,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  accident['reported'] == true ? 'Reported' : 'Pending',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Timestamp) return _formatTimestamp(value);
    if (value is double) return value.toStringAsFixed(2);
    if (value is List) return value.join(', ');
    if (value is Map) return value.toString();
    return value.toString();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final DateTime dateTime = timestamp.toDate();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } else if (timestamp is String) {
      try {
        final DateTime dateTime = DateTime.parse(timestamp);
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
      } catch (e) {
        return 'Invalid Date';
      }
    }
    return 'Invalid Date';
  }

  Future<void> _clearAllAccidents() async {
    try {
      final QuerySnapshot accidents = await _firestore.collection('accidents').get();
      
      final WriteBatch batch = _firestore.batch();
      for (var doc in accidents.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All accidents cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing accidents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAccident(String accidentId) async {
    try {
      await _firestore.collection('accidents').doc(accidentId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accident cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing accident: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _allocateAmbulance(String accidentId, Map<String, dynamic> accidentData) async {
    try {
      // Create a new document in the ambulances collection with the accident data
      await _firestore.collection('ambulances').doc(accidentId).set({
        'accident_id': accidentId,
        'ambulance_id': accidentData['ambulance_id'] ?? '',
        'accident_data': {
          'location': accidentData['location'],
          'intensity': accidentData['intensity'] ?? 'Unknown',
          'persons_involved': accidentData['persons_involved'] ?? 0,
          'detection_accuracy': accidentData['average_detection_percentage'] ?? 0.0,
          'video_data': accidentData['video_data'] ?? {},
          'metadata': accidentData['metadata'] ?? {},
        },
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
        'reported_at': FieldValue.serverTimestamp(),
      });

      // Update the accident as reported
      await _firestore.collection('accidents').doc(accidentId).update({
        'reported': true,
        'status': 'Reported',
        'reported_at': FieldValue.serverTimestamp(),
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accident reported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error allocating ambulance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reporting accident: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Video player widget for the card view
class AccidentVideoPlayer extends StatefulWidget {
  final String videoUrl;

  AccidentVideoPlayer({required this.videoUrl});

  @override
  _AccidentVideoPlayerState createState() => _AccidentVideoPlayerState();
}

class _AccidentVideoPlayerState extends State<AccidentVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _error;
  Duration _currentPosition = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _positionUpdateTimer;
  bool _isDurationDetected = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print('Initializing video player with URL: ${widget.videoUrl}');
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'Access-Control-Allow-Origin': '*',
        },
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Add position listener
      _videoPlayerController!.addListener(_videoListener);
      
      // Wait for initialization
      await _videoPlayerController!.initialize();
      print('Video initialized successfully');

      // For WebM videos, we need to detect duration manually
      if (widget.videoUrl.toLowerCase().endsWith('.webm')) {
        _detectWebMDuration();
      } else {
        _totalDuration = _videoPlayerController!.value.duration;
      }
      print('Initial duration: $_totalDuration');

      // Create Chewie controller with custom controls
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        showControls: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: false,
        allowPlaybackSpeedChanging: false,
        showControlsOnInitialize: true,
        allowMuting: true,
        customControls: MaterialControls(),
        placeholder: Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Color(0xFFFF7070),
          handleColor: Color(0xFFFF7070),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 30),
                SizedBox(height: 8),
                Text(
                  'Error: $errorMessage',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Start position update timer
      _startPositionUpdateTimer();

    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() => _error = e.toString());
      }
      
      _cleanupControllers();
    }
  }

  void _detectWebMDuration() async {
    if (!widget.videoUrl.toLowerCase().endsWith('.webm')) return;

    try {
      // Start playing to detect duration
      await _videoPlayerController!.play();
      
      // Create a timer to check position until we detect the end
      Timer.periodic(Duration(milliseconds: 100), (timer) async {
        if (!mounted || _videoPlayerController == null) {
          timer.cancel();
          return;
        }

        final position = _videoPlayerController!.value.position;
        
        // If position is not advancing and we've started playing,
        // we've likely reached the end
        if (position > Duration.zero && 
            !_videoPlayerController!.value.isPlaying &&
            !_isDurationDetected) {
          _totalDuration = position;
          _isDurationDetected = true;
          print('Detected WebM duration: $_totalDuration');
          
          // Update the controller
          if (_chewieController != null) {
            setState(() {
              // Recreate the controller with the correct duration
              final oldController = _chewieController;
              _chewieController = ChewieController(
                videoPlayerController: _videoPlayerController!,
                autoPlay: false,
                looping: false,
                showControls: true,
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                allowFullScreen: false,
                allowPlaybackSpeedChanging: false,
                showControlsOnInitialize: true,
                allowMuting: true,
                customControls: MaterialControls(),
                materialProgressColors: ChewieProgressColors(
                  playedColor: Color(0xFFFF7070),
                  handleColor: Color(0xFFFF7070),
                  backgroundColor: Colors.white24,
                  bufferedColor: Colors.white38,
                ),
              );
              oldController?.dispose();
            });
          }
          
          // Reset to beginning
          await _videoPlayerController!.seekTo(Duration.zero);
          await _videoPlayerController!.pause();
          
          timer.cancel();
        }
      });
    } catch (e) {
      print('Error detecting WebM duration: $e');
    }
  }

  void _startPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (!mounted || _videoPlayerController == null) return;
      
      if (_videoPlayerController!.value.isPlaying) {
        setState(() {
          _currentPosition = _videoPlayerController!.value.position;
          
          // Update duration if it's longer than what we have
          if (_currentPosition > _totalDuration) {
            _totalDuration = _currentPosition;
          }
        });
      }
    });
  }

  void _videoListener() {
    if (!mounted) return;
    
    final controller = _videoPlayerController;
    if (controller == null) return;

    final newPosition = controller.value.position;
    
    setState(() {
      _currentPosition = newPosition;
      
      // Update duration if we detect a longer position
      if (newPosition > _totalDuration) {
        _totalDuration = newPosition;
      }
      
      // Calculate buffered position
      if (controller.value.buffered.isNotEmpty) {
        _bufferedPosition = controller.value.buffered.last.end;
        
        // Update duration if buffer shows a longer duration
        if (_bufferedPosition > _totalDuration) {
          _totalDuration = _bufferedPosition;
        }
      }
    });

    // Handle seeking for WebM
    if (widget.videoUrl.toLowerCase().endsWith('.webm')) {
      if (controller.value.isBuffering) {
        // Only seek if the difference is significant
        if ((_currentPosition - controller.value.position).abs().inMilliseconds > 500) {
          controller.seekTo(_currentPosition).then((_) {
            if (controller.value.isPlaying) {
              controller.play();
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    _videoPlayerController?.removeListener(_videoListener);
    _cleanupControllers();
    super.dispose();
  }

  void _cleanupControllers() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Error loading video: ${_error!}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _chewieController == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 8),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

// Full screen video player
class FullScreenVideoPlayer extends StatelessWidget {
  final String videoUrl;
  final String accidentId;

  FullScreenVideoPlayer({
    required this.videoUrl,
    required this.accidentId,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: VideoPlayerScreen(
                videoUrl: videoUrl,
                autoPlay: true,
                allowFullScreen: true,
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.fullscreen_exit, color: Colors.white, size: 30),
                onPressed: () {
                  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
                    .then((_) => Navigator.of(context).pop());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Video player screen for full screen view
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool allowFullScreen;
  
  VideoPlayerScreen({
    required this.videoUrl,
    this.autoPlay = false,
    this.allowFullScreen = false,
  });
  
  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  Duration _currentPosition = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _positionUpdateTimer;
  bool _isDurationDetected = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.videoUrl.startsWith('assets/')) {
        _videoPlayerController = VideoPlayerController.asset(widget.videoUrl);
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
      }

      // Add position listener
      _videoPlayerController.addListener(_videoListener);
      
      await _videoPlayerController.initialize();
      
      // Get total duration
      _totalDuration = _videoPlayerController.value.duration;
      print('Video duration: $_totalDuration');

      // Start position update timer for WebM videos
      if (widget.videoUrl.toLowerCase().endsWith('.webm')) {
        _positionUpdateTimer?.cancel();
        _positionUpdateTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
          if (_videoPlayerController.value.isPlaying) {
            setState(() {
              _currentPosition = _videoPlayerController.value.position;
            });
          }
        });
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: widget.autoPlay,
        looping: false,
        allowFullScreen: widget.allowFullScreen,
        showOptions: false,
        allowPlaybackSpeedChanging: false,
        showControlsOnInitialize: true,
        allowMuting: true,
        customControls: MaterialControls(),
        placeholder: Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Color(0xFFFF7070),
          handleColor: Color(0xFFFF7070),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
        systemOverlaysOnEnterFullScreen: [],
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;

    final newPosition = _videoPlayerController.value.position;
    final newDuration = _videoPlayerController.value.duration;

    if (newPosition != _currentPosition || newDuration != _totalDuration) {
      setState(() {
        _currentPosition = newPosition;
        _totalDuration = newDuration;
        
        // Calculate buffered position
        if (_videoPlayerController.value.buffered.isNotEmpty) {
          _bufferedPosition = _videoPlayerController.value.buffered.last.end;
        }
      });
    }

    // Handle seeking for WebM
    if (widget.videoUrl.toLowerCase().endsWith('.webm')) {
      if (_videoPlayerController.value.isBuffering) {
        // Only seek if the difference is significant
        if ((_currentPosition - _videoPlayerController.value.position).abs().inMilliseconds > 500) {
          _videoPlayerController.seekTo(_currentPosition).then((_) {
            if (_videoPlayerController.value.isPlaying) {
              _videoPlayerController.play();
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    _videoPlayerController.removeListener(_videoListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _chewieController != null &&
              _chewieController!.videoPlayerController.value.isInitialized
          ? Chewie(controller: _chewieController!)
          : CircularProgressIndicator(color: Colors.white),
    );
  }
} 