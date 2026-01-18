
import '../../core/constants/app_constants.dart';

class CallEntity {
  final String id;
  final String callId; // Unique ID for signaling
  final String callerId;
  final String receiverId;
  final String callType; // 'audio' or 'video'
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration? duration;
  final bool isIncoming;
  final bool? isMissed;
  final bool? isRejected;
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;

  const CallEntity({
    required this.id,
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.duration,
    required this.isIncoming,
    this.isMissed,
    this.isRejected,
    this.rejectionReason,
    this.metadata,
  });

  CallEntity copyWith({
    String? id,
    String? callId,
    String? callerId,
    String? receiverId,
    String? callType,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    bool? isIncoming,
    bool? isMissed,
    bool? isRejected,
    String? rejectionReason,
    Map<String, dynamic>? metadata,
  }) {
    return CallEntity(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      isIncoming: isIncoming ?? this.isIncoming,
      isMissed: isMissed ?? this.isMissed,
      isRejected: isRejected ?? this.isRejected,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callType': callType,
      'status': status,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'duration': duration?.inSeconds,
      'isIncoming': isIncoming,
      'isMissed': isMissed,
      'isRejected': isRejected,
      'rejectionReason': rejectionReason,
      'metadata': metadata,
    };
  }

  factory CallEntity.fromMap(Map<String, dynamic> map) {
    return CallEntity(
      id: map['id'] as String,
      callId: map['callId'] as String,
      callerId: map['callerId'] as String,
      receiverId: map['receiverId'] as String,
      callType: map['callType'] as String,
      status: map['status'] as String,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: map['endedAt'] != null
          ? DateTime.parse(map['endedAt'] as String)
          : null,
      duration: map['duration'] != null
          ? Duration(seconds: map['duration'] as int)
          : null,
      isIncoming: map['isIncoming'] as bool,
      isMissed: map['isMissed'] as bool?,
      isRejected: map['isRejected'] as bool?,
      rejectionReason: map['rejectionReason'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convenience getters
  bool get isActive => status == AppConstants.callStatusConnected;
  bool get isEnded => status == AppConstants.callStatusEnded;
  bool get isMissedCall => isMissed == true;
  bool get isRejectedCall => isRejected == true;
  bool get isVideoCall => callType == AppConstants.callTypeVideo;
  bool get isAudioCall => callType == AppConstants.callTypeAudio;

  String get displayDuration {
    if (duration == null) return '';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}