import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/themes/colors.dart';

class VideoRendererr extends StatefulWidget {
  final MediaStream? stream;
  final bool isMirrored;
  final bool isLocal;
  final BoxFit fit;
  final Widget? placeholder;

  const VideoRendererr({
    super.key,
    this.stream,
    this.isMirrored = false,
    this.isLocal = false,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<VideoRendererr> createState() => _VideoRendererrState();
}

class _VideoRendererrState extends State<VideoRendererr> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
  }

  Future<void> _initializeRenderer() async {
    await _renderer.initialize();
    setState(() {
      _isInitialized = true;
    });

    if (widget.stream != null) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void didUpdateWidget(VideoRendererr oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.stream != oldWidget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return widget.placeholder ?? _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(widget.isMirrored && widget.isLocal ? -1.0 : 1.0, 1.0),
        child: RTCVideoView(
          _renderer,
          objectFit: widget.fit == BoxFit.cover
              ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          mirror: widget.isMirrored && widget.isLocal,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          widget.isLocal ? Icons.person : Icons.person_outline,
          size: 50,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// PiP (Picture-in-Picture) Video Renderer
class PiPVideoRenderer extends StatelessWidget {
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final VoidCallback? onTap;
  final bool isExpanded;

  const PiPVideoRenderer({
    super.key,
    this.localStream,
    this.remoteStream,
    this.onTap,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isExpanded ? double.infinity : 120,
        height: isExpanded ? double.infinity : 160,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(isExpanded ? 0 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Remote/primary video
            if (remoteStream != null)
              VideoRendererr(
                stream: remoteStream,
                fit: BoxFit.cover,
              ),

            // Local/PiP video
            if (localStream != null && !isExpanded)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: VideoRendererr(
                    stream: localStream,
                    isLocal: true,
                    isMirrored: true,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Connection status indicator
            if (remoteStream == null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connecting...',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}