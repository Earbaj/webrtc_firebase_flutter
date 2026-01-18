import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/signaling_entity.dart';

class WebRTCDataSource {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCDataChannel? _dataChannel;

  final StreamController<MediaStream> _remoteStreamController =
  StreamController<MediaStream>.broadcast();
  final StreamController<RTCIceCandidate> _iceCandidateController =
  StreamController<RTCIceCandidate>.broadcast();
  final StreamController<RTCPeerConnectionState> _connectionStateController =
  StreamController<RTCPeerConnectionState>.broadcast();
  final StreamController<RTCSignalingState> _signalingStateController =
  StreamController<RTCSignalingState>.broadcast();
  final StreamController<RTCIceConnectionState> _iceConnectionStateController =
  StreamController<RTCIceConnectionState>.broadcast();
  final StreamController<String> _dataChannelController =
  StreamController<String>.broadcast();

  // Getters for streams
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  Stream<RTCIceCandidate> get iceCandidates => _iceCandidateController.stream;
  Stream<RTCPeerConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<RTCSignalingState> get signalingState =>
      _signalingStateController.stream;
  Stream<RTCIceConnectionState> get iceConnectionState =>
      _iceConnectionStateController.stream;
  Stream<String> get dataChannelMessages => _dataChannelController.stream;

  Future<void> initializePeerConnection() async {
    try {
      AppLogger.webrtc('Initializing WebRTC peer connection');

      Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      final constraints = <String, dynamic>{
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      };

      _peerConnection = await createPeerConnection(configuration, constraints);

      // Setup event listeners
      _setupPeerConnectionListeners();

      AppLogger.webrtc('Peer connection initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize peer connection', error: e);
      rethrow;
    }
  }

  void _setupPeerConnectionListeners() {
    if (_peerConnection == null) return;

    // ICE Candidate listener
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      AppLogger.webrtc('New ICE candidate: ${candidate.toMap()}');
      _iceCandidateController.add(candidate);
    };

    // ICE Connection State listener
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      AppLogger.webrtc('ICE connection state changed: $state');
      _iceConnectionStateController.add(state);
    };

    // ICE Gathering State listener
    _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      AppLogger.webrtc('ICE gathering state: $state');
    };

    // Signaling State listener
    _peerConnection!.onSignalingState = (RTCSignalingState state) {
      AppLogger.webrtc('Signaling state: $state');
      _signalingStateController.add(state);
    };

    // Connection State listener
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      AppLogger.webrtc('Connection state: $state');
      _connectionStateController.add(state);
    };

    // Track listener for remote streams
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      AppLogger.webrtc('Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamController.add(_remoteStream!);
      }
    };

    // Data channel listener
    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      AppLogger.webrtc('Data channel received: ${channel.label}');
      _setupDataChannel(channel);
    };
  }

  Future<MediaStream> getLocalMediaStream({
    bool audio = true,
    bool video = true,
  }) async {
    try {
      AppLogger.webrtc('Getting local media stream (audio: $audio, video: $video)');

      final mediaConstraints = <String, dynamic>{
        'audio': audio,
        'video': video
            ? {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (_peerConnection != null) {
        // Add tracks to peer connection
        if (audio) {
          final audioTracks = _localStream!.getAudioTracks();
          for (final track in audioTracks) {
            await _peerConnection!.addTrack(track, _localStream!);
          }
        }

        if (video) {
          final videoTracks = _localStream!.getVideoTracks();
          for (final track in videoTracks) {
            await _peerConnection!.addTrack(track, _localStream!);
          }
        }
      }

      AppLogger.webrtc('Local media stream obtained successfully');
      return _localStream!;
    } catch (e) {
      AppLogger.error('Failed to get local media stream', error: e);
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    try {
      AppLogger.webrtc('Creating offer');

      if (_peerConnection == null) {
        await initializePeerConnection();
      }

      final constraints = <String, dynamic>{
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      };

      final offer = await _peerConnection!.createOffer(constraints);
      await _peerConnection!.setLocalDescription(offer);

      AppLogger.webrtc('Offer created: ${offer.type}');
      return offer;
    } catch (e) {
      AppLogger.error('Failed to create offer', error: e);
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    try {
      AppLogger.webrtc('Creating answer');

      if (_peerConnection == null) {
        await initializePeerConnection();
      }

      final constraints = <String, dynamic>{
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      };

      final answer = await _peerConnection!.createAnswer(constraints);
      await _peerConnection!.setLocalDescription(answer);

      AppLogger.webrtc('Answer created: ${answer.type}');
      return answer;
    } catch (e) {
      AppLogger.error('Failed to create answer', error: e);
      rethrow;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    try {
      AppLogger.webrtc('Setting remote description: ${description.type}');

      if (_peerConnection == null) {
        await initializePeerConnection();
      }

      await _peerConnection!.setRemoteDescription(description);
      AppLogger.webrtc('Remote description set successfully');
    } catch (e) {
      AppLogger.error('Failed to set remote description', error: e);
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      AppLogger.webrtc('Adding ICE candidate: ${candidate.toMap()}');

      if (_peerConnection == null) {
        await initializePeerConnection();
      }

      await _peerConnection!.addCandidate(candidate);
      AppLogger.webrtc('ICE candidate added successfully');
    } catch (e) {
      AppLogger.error('Failed to add ICE candidate', error: e);
      rethrow;
    }
  }

  Future<void> addIceCandidateFromSignaling(SignalingEntity signaling) async {
    if (signaling.candidate == null) return;

    try {
      final candidate = RTCIceCandidate(
        signaling.candidate!['candidate'],
        signaling.candidate!['sdpMid'],
        signaling.candidate!['sdpMLineIndex'],
      );

      await addIceCandidate(candidate);
    } catch (e) {
      AppLogger.error('Failed to add ICE candidate from signaling', error: e);
      rethrow;
    }
  }

  Future<void> createDataChannel(String label) async {
    try {
      AppLogger.webrtc('Creating data channel: $label');

      if (_peerConnection == null) {
        await initializePeerConnection();
      }

      final channel = await _peerConnection!.createDataChannel(
        label,
        RTCDataChannelInit(),
      );

      _setupDataChannel(channel);
      AppLogger.webrtc('Data channel created: $label');
    } catch (e) {
      AppLogger.error('Failed to create data channel', error: e);
      rethrow;
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;

    channel.onDataChannelState = (state) {
      AppLogger.webrtc('Data channel state: $state');
    };

    channel.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        AppLogger.webrtc('Binary message received: ${message.text.length} bytes');
      } else {
        final text = message.text;//String.fromCharCodes(message.data);
        AppLogger.webrtc('Text message received: $text');
        _dataChannelController.add(text);
      }
    };
  }

  Future<void> sendDataChannelMessage(String message) async {
    try {
      if (_dataChannel == null) {
        AppLogger.warning('Data channel not initialized');
        return;
      }

      if (_dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
        AppLogger.warning('Data channel not open');
        return;
      }

      await _dataChannel!.send(RTCDataChannelMessage(message));
      AppLogger.webrtc('Message sent via data channel: $message');
    } catch (e) {
      AppLogger.error('Failed to send data channel message', error: e);
      rethrow;
    }
  }

  Future<void> switchCamera() async {
    try {
      if (_localStream == null) return;

      final videoTrack = _localStream!.getVideoTracks().first;
      if (!videoTrack.getConstraints().containsKey('facingMode')) {
        return;
      }

      final currentFacingMode = videoTrack.getConstraints()['facingMode'];
      final newFacingMode =
      currentFacingMode == 'user' ? 'environment' : 'user';

      await videoTrack.switchCamera();
      AppLogger.webrtc('Camera switched to: $newFacingMode');
    } catch (e) {
      AppLogger.error('Failed to switch camera', error: e);
      rethrow;
    }
  }

  Future<void> toggleAudioMute() async {
    try {
      if (_localStream == null) return;

      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;

      final isMuted = !audioTrack.enabled;
      AppLogger.webrtc('Audio ${isMuted ? 'muted' : 'unmuted'}');
    } catch (e) {
      AppLogger.error('Failed to toggle audio mute', error: e);
      rethrow;
    }
  }

  Future<void> toggleVideoMute() async {
    try {
      if (_localStream == null) return;

      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;

      final isMuted = !videoTrack.enabled;
      AppLogger.webrtc('Video ${isMuted ? 'muted' : 'unmuted'}');
    } catch (e) {
      AppLogger.error('Failed to toggle video mute', error: e);
      rethrow;
    }
  }

  bool isAudioMuted() {
    if (_localStream == null) return false;
    final audioTrack = _localStream!.getAudioTracks().first;
    return !audioTrack.enabled;
  }

  bool isVideoMuted() {
    if (_localStream == null) return false;
    final videoTrack = _localStream!.getVideoTracks().first;
    return !videoTrack.enabled;
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStreamValue => _remoteStream;
  RTCPeerConnection? get peerConnection => _peerConnection;

  Future<void> close() async {
    AppLogger.webrtc('Closing WebRTC connection');

    try {
      // Close data channel
      if (_dataChannel != null) {
        await _dataChannel!.close();
        _dataChannel = null;
      }

      // Close peer connection
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      // Dispose local stream
      if (_localStream != null) {
        await _localStream!.dispose();
        _localStream = null;
      }

      // Close controllers
      await _remoteStreamController.close();
      await _iceCandidateController.close();
      await _connectionStateController.close();
      await _signalingStateController.close();
      await _iceConnectionStateController.close();
      await _dataChannelController.close();

      AppLogger.webrtc('WebRTC connection closed successfully');
    } catch (e) {
      AppLogger.error('Error closing WebRTC connection', error: e);
      rethrow;
    }
  }
}