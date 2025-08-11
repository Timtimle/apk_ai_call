import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _CallPageState extends State<CallPage> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController roomIdController = TextEditingController();
  
  String? roomId;
  bool? isRoomCreator;

  RTCPeerConnection? _peerConnection; // connect to WebRTC
  MediaStream? _localStream; // My Vid, Aud

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': 'stun:stun.l.google.com:19302'
      }
    ]
  };

  @override
  void initState() {
    super.initState();
    initRenderers();
    initLocalStream();
  }

Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
}

Future<void> initLocalStream() async {
    final cameraSetting = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };
    _localStream = await navigator.mediaDevices.getUserMedia(cameraSetting);
    _localRenderer.srcObject = _localStream;
}

Future<void> initPeerConnection() async {
    if(_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    print('Before createPeerConnection');
    _peerConnection = await createPeerConnection(configuration);
    print('After createPeerConnection');

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('PeerConnection State: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE Connection State: $state');
    };
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('onTrack fired! Track kind: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        setState((){
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };
    
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
    if (candidate.candidate == null) return;
    if (roomId == null) return;
    final roomRef = firestore.collection('calls').doc(roomId);

    if(isRoomCreator == true) {
      roomRef.collection('offerCandidates').add ({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    } else {
      roomRef.collection('answerCandidates').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    }
  };
}
  
  @override
  void dispose() {
    roomIdController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    _localStream?.dispose();
    super.dispose();
  }

Future<void> createRoom() async {
  isRoomCreator = true;
  // create new Document in collections calls
  
  await initPeerConnection();

  final Doc = firestore.collection('calls').doc();
  roomId = Doc.id;

  setState((){});

  // create offer and set local description
  RTCSessionDescription offer = await _peerConnection!.createOffer();
  await _peerConnection!.setLocalDescription(offer);

  final offerData = {
    'type': offer.type,
    'sdp': offer.sdp,
  };
  await Doc.set({'offer': offerData});

  Doc.snapshots().listen((snapshot) async {
    if (snapshot.exists && snapshot.data()!.containsKey('answer')) {
      final answer = snapshot.data()!['answer'];
      if (answer != null) {
        RTCSessionDescription answerDescription = RTCSessionDescription(
          answer['sdp'],
          answer['type'],
        );
        if (_peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer){
          await _peerConnection!.setRemoteDescription(answerDescription);
        } else {
          print("Skipping setRemoteDescription because signalingState is ${_peerConnection!.signalingState}");
        }
      }
    }
  });

  Doc.collection('answerCandidates').snapshots().listen((snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data();
        if (data != null) {
          RTCIceCandidate candidate = RTCIceCandidate (
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          _peerConnection!.addCandidate(candidate).then((_) {
            print('Added ICE candidate: ${candidate.candidate}');
          }).catchError((e) {
            print('Failed to add candidate: $e');
          });
        }
      }
    }
  });
}

Future<void> joinRoom(String roomId) async {
  this.roomId = roomId;
  isRoomCreator = false;

  await initPeerConnection();

  setState((){});

  final documentRef = firestore.collection('calls').doc(roomId);
  
  // get doc from callRoom
  final curRoom = await documentRef.get();
  if (!curRoom.exists) {
    print('Room is not exists');
    return;
  }

  // get offer from firestore
  final data = curRoom.data();
  if (data == null) return;
  final offer = data['offer'];

  // set offter to remote description
  await _peerConnection!.setRemoteDescription(
    RTCSessionDescription(offer['sdp'], offer['type']),
  );

  // create answer ans set local description
  print('Signaling state before createAnswer: ${_peerConnection!.signalingState}');
  RTCSessionDescription answer = await _peerConnection!.createAnswer();
  await _peerConnection!.setLocalDescription(answer);

  // Sumbit ans to firestore
  final answerData = {
    'type': answer.type,
    'sdp': answer.sdp,
  };
  await documentRef.update({'answer': answerData});

  // listen to ICE candidates's offer
  documentRef.collection('offerCandidates').snapshots().listen((snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data();
        if (data != null) {
          RTCIceCandidate candidate = RTCIceCandidate (
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          _peerConnection!.addCandidate(candidate).then((_) {
            print('Added ICE candidate: ${candidate.candidate}');
          }).catchError((e) {
             print('Failed to add candidate: $e');
            });
        }
      }
    }
  });
}

  @override
  Widget build(BuildContext context) {
      return Scaffold (
        appBar: AppBar( 
          title: Text('Bao Call'),
        ),
        body: Padding (
          padding: const EdgeInsets.all(16.0),
          child: Column (
            children: [
              Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
              const SizedBox(height: 10),
              Expanded(child: RTCVideoView(_remoteRenderer)),
              const SizedBox(height: 20),

              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding (
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column (
                    children:[
                      TextField (
                        controller: roomIdController,
                        decoration: const InputDecoration (
                          labelText: 'ID: ',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.meeting_room),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row (
                        children: [
                          Expanded (
                            child: ElevatedButton.icon (
                              icon: const Icon(Icons.add),
                              label: Text('Create Roommzxczczczxczxc'),
                              onPressed: () async {
                                await createRoom();
                                if (roomId != null) {
                                  ScaffoldMessenger.of(context).showSnackBar (
                                    SnackBar(content: Text('Room: $roomId')),
                                  );
                                  print('roomid: $roomId');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded (
                            child: ElevatedButton.icon (
                              icon: Icon(Icons.login),
                              label: Text('Join Room'),
                              onPressed: () async {
                                String id = roomIdController.text.trim();
                                if (id.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar (
                                    SnackBar(content: Text('Enter room ID')),
                                  );
                                  return;
                                }
                                await joinRoom(id);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (roomId != null) ...[
                        SizedBox(height: 10),
                        SelectableText (
                          'Current ID: $roomId',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  _CallPageState createState() => _CallPageState();
}

