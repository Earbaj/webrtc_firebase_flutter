import 'package:fpdart/fpdart.dart';

import '../entities/call_entity.dart';
import '../entities/signaling_entity.dart';

abstract class CallRepositoryInterface {
  // Call management
  Future<Either<String, CallEntity>> createCall({
    required String callerId,
    required String receiverId,
    required String callType,
  });

  Future<Either<String, CallEntity>> getCall(String callId);
  Future<Either<String, void>> updateCall(CallEntity call);
  Future<Either<String, void>> endCall(String callId, Duration? duration);
  Future<Either<String, void>> rejectCall(String callId, String reason);
  Future<Either<String, void>> markCallAsMissed(String callId);

  // Call logs
  Future<Either<String, List<CallEntity>>> getCallLogs(String userId);
  Future<Either<String, List<CallEntity>>> getRecentCalls(String userId, int limit);

  // Signaling
  Future<Either<String, void>> sendOffer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> offer,
  });

  Future<Either<String, void>> sendAnswer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> answer,
  });

  Future<Either<String, void>> sendIceCandidate({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> candidate,
  });

  // Streams
  Stream<SignalingEntity> listenForOffers(String userId);
  Stream<SignalingEntity> listenForAnswers(String callId, String userId);
  Stream<SignalingEntity> listenForIceCandidates(String callId, String userId);
  Stream<CallEntity> listenForCallUpdates(String callId);

  // Presence
  Future<Either<String, bool>> isUserBusy(String userId);
  Future<Either<String, void>> setUserInCall(String userId, bool inCall);
}