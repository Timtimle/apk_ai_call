import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class _CallPageState extends State<CallPage> {
  final _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    initRenderers();
    startCamera();
  }

Future<void> initRenderers() async {
    await _localRenderer.initialize();
  }

Future<void> startCamera() async {
    final cameraSetting = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    final stream = await navigator.mediaDevices.getUserMedia(cameraSetting);
    _localRenderer.srcObject = stream;
    print("Stream set: ${_localRenderer.srcObject != null}");
  }
  
  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
    return Scaffold (
      appBar: AppBar( 
        title: Text('Bao Call'),
      ),
      body: Center (
        child: RTCVideoView(_localRenderer, mirror: true),
      ),
    );
  }
}

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  _CallPageState createState() => _CallPageState();
}

