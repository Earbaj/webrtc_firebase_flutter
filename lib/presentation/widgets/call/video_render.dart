import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoRenderer extends StatelessWidget {
  final MediaStream? stream;
  final BoxFit fit;
  final bool isMirrored;

  const VideoRenderer({
    Key? key,
    this.stream,
    this.fit = BoxFit.contain,
    this.isMirrored = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (stream == null) {
      return Container(color: Colors.black);
    }

    // Map BoxFit to RTCVideoViewObjectFit
    RTCVideoViewObjectFit objectFit;
    switch (fit) {
      case BoxFit.cover:
        objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
        break;
      case BoxFit.contain:
      default:
        objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
    }

    final renderer = RTCVideoRenderer();
    renderer.srcObject = stream;

    return RTCVideoView(
      renderer,
      objectFit: objectFit,
      mirror: isMirrored,
      filterQuality: FilterQuality.high,
    );
  }
}
