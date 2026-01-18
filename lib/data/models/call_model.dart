import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/call_entity.dart';

class CallModel extends CallEntity {
  const CallModel({
    required super.id,
    required super.callId,
    required super.callerId,
    required super.receiverId,
    required super.callType,
    required super.status,
    required super.startedAt,
    super.endedAt,
    super.duration,
    required super.isIncoming,
    super.isMissed,
    super.isRejected,
    super.rejectionReason,
    super.metadata,
  });

  factory CallModel.fromEntity(CallEntity entity) {
    return CallModel(
      id: entity.id,
      callId: entity.callId,
      callerId: entity.callerId,
      receiverId: entity.receiverId,
      callType: entity.callType,
      status: entity.status,
      startedAt: entity.startedAt,
      endedAt: entity.endedAt,
      duration: entity.duration,
      isIncoming: entity.isIncoming,
      isMissed: entity.isMissed,
      isRejected: entity.isRejected,
      rejectionReason: entity.rejectionReason,
      metadata: entity.metadata,
    );
  }

  factory CallModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
    final data = snapshot.data()!;
    return CallModel(
      id: snapshot.id,
      callId: data['callId'] as String,
      callerId: data['callerId'] as String,
      receiverId: data['receiverId'] as String,
      callType: data['callType'] as String,
      status: data['status'] as String,
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      duration: data['duration'] != null
          ? Duration(seconds: data['duration'] as int)
          : null,
      isIncoming: data['isIncoming'] as bool,
      isMissed: data['isMissed'] as bool?,
      isRejected: data['isRejected'] as bool?,
      rejectionReason: data['rejectionReason'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callType': callType,
      'status': status,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'duration': duration?.inSeconds,
      'isIncoming': isIncoming,
      'isMissed': isMissed,
      'isRejected': isRejected,
      'rejectionReason': rejectionReason,
      'metadata': metadata,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CallEntity toEntity() {
    return CallEntity(
      id: id,
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      callType: callType,
      status: status,
      startedAt: startedAt,
      endedAt: endedAt,
      duration: duration,
      isIncoming: isIncoming,
      isMissed: isMissed,
      isRejected: isRejected,
      rejectionReason: rejectionReason,
      metadata: metadata,
    );
  }
}