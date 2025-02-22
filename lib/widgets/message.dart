import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    // Connect to the FastAPI WebSocket endpoint
    channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws'),  // Make sure this points to your local FastAPI server
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Accident Detection Notifications"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('Waiting for notification...'),
          StreamBuilder(
            stream: channel.stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.active) {
                return Text(snapshot.data ?? 'No message');
              } else {
                return CircularProgressIndicator();
              }
            },
          ),
        ],
      ),
    );
  }
}
