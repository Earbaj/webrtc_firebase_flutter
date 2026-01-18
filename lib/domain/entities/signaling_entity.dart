class SignalingEntity {
  final String? type; // 'offer', 'answer', 'candidate'
  final String? sdp;
  final Map<String, dynamic>? candidate;
  final String fromUserId;
  final String toUserId;
  final String callId;
  final DateTime timestamp;

  const SignalingEntity({
    this.type,
    this.sdp,
    this.candidate,
    required this.fromUserId,
    required this.toUserId,
    required this.callId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'sdp': sdp,
      'candidate': candidate,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'callId': callId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SignalingEntity.fromMap(Map<String, dynamic> map) {
    return SignalingEntity(
      type: map['type'] as String?,
      sdp: map['sdp'] as String?,
      candidate: map['candidate'] as Map<String, dynamic>?,
      fromUserId: map['fromUserId'] as String,
      toUserId: map['toUserId'] as String,
      callId: map['callId'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  bool get isOffer => type == 'offer';
  bool get isAnswer => type == 'answer';
  bool get isCandidate => type == 'candidate';
}