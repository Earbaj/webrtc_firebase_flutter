import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/signaling_entity.dart';
import '../../domain/repositories/call_repository_interface.dart';
import '../datasources/firebase_datasource.dart';
import '../models/call_model.dart';

class CallRepository implements CallRepositoryInterface {
  final FirebaseDataSource _dataSource;

  CallRepository(this._dataSource);

  @override
  Future<Either<String, CallEntity>> createCall({
    required String callerId,
    required String receiverId,
    required String callType,
  }) async {
    AppLogger.info('Creating call: $callerId -> $receiverId ($callType)');
    final result = await _dataSource.createCall(
      callerId: callerId,
      receiverId: receiverId,
      callType: callType,
    );
    return result.fold(
          (error) => left(error),
          (callModel) => right(callModel.toEntity()),
    );
  }

  @override
  Future<Either<String, CallEntity>> getCall(String callId) async {
    AppLogger.info('Getting call: $callId');
    final result = await _dataSource.getCall(callId);
    return result.fold(
          (error) => left(error),
          (callModel) => right(callModel.toEntity()),
    );
  }

  @override
  Future<Either<String, void>> updateCall(CallEntity call) async {
    AppLogger.info('Updating call: ${call.id}');
    final callModel = CallModel.fromEntity(call);
    return await _dataSource.updateCall(callModel);
  }

  @override
  Future<Either<String, void>> endCall(String callId, Duration? duration) async {
    AppLogger.info('Ending call: $callId');
    try {
      final callResult = await getCall(callId);
      return await callResult.fold(
            (error) => left(error),
            (call) async {
          final updatedCall = call.copyWith(
            status: AppConstants.callStatusEnded,
            endedAt: DateTime.now(),
            duration: duration,
          );

          // Update user status
          final currentUser = _dataSource.currentUser;
          if (currentUser != null) {
            await _dataSource.setUserBusy(currentUser.id, false);
          }

          return await updateCall(updatedCall);
        },
      );
    } catch (e) {
      AppLogger.error('End call failed', error: e);
      return left('Failed to end call');
    }
  }

  @override
  Future<Either<String, void>> rejectCall(String callId, String reason) async {
    AppLogger.info('Rejecting call: $callId - $reason');
    try {
      final callResult = await getCall(callId);
      return await callResult.fold(
            (error) => left(error),
            (call) async {
          final updatedCall = call.copyWith(
            status: AppConstants.callStatusRejected,
            isRejected: true,
            rejectionReason: reason,
            endedAt: DateTime.now(),
          );

          // Update user status
          final currentUser = _dataSource.currentUser;
          if (currentUser != null) {
            await _dataSource.setUserBusy(currentUser.id, false);
          }

          return await updateCall(updatedCall);
        },
      );
    } catch (e) {
      AppLogger.error('Reject call failed', error: e);
      return left('Failed to reject call');
    }
  }

  @override
  Future<Either<String, void>> markCallAsMissed(String callId) async {
    AppLogger.info('Marking call as missed: $callId');
    try {
      final callResult = await getCall(callId);
      return await callResult.fold(
            (error) => left(error),
            (call) async {
          final updatedCall = call.copyWith(
            status: AppConstants.callStatusMissed,
            isMissed: true,
            endedAt: DateTime.now(),
          );
          return await updateCall(updatedCall);
        },
      );
    } catch (e) {
      AppLogger.error('Mark call as missed failed', error: e);
      return left('Failed to mark call as missed');
    }
  }

  @override
  Future<Either<String, List<CallEntity>>> getCallLogs(String userId) async {
    AppLogger.info('Getting call logs for: $userId');
    try {
      final callerSnapsot = await _dataSource.firestore
          .collection(AppConstants.callsCollection)
          .where('callerId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .get();

      final recieverSnapsot = await _dataSource.firestore
          .collection(AppConstants.callsCollection)
          .where('receiverId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .get();

      final allDocs = [
        ...callerSnapsot.docs,
        ...recieverSnapsot.docs,
      ];

      final calls = allDocs
          .map((doc) => CallModel.fromFirestore(doc).toEntity())
          .toList();

      // Sort merged list by startedAt descending
      calls.sort((a, b) => b.startedAt.compareTo(a.startedAt));

      return right(calls);
    } catch (e) {
      AppLogger.error('Get call logs failed', error: e);
      return left('Failed to get call logs');
    }
  }

  @override
  Future<Either<String, List<CallEntity>>> getRecentCalls(
      String userId,
      int limit,
      ) async {
    AppLogger.info('Getting recent calls for: $userId');
    try {
      final callerSnapshot = await _dataSource.firestore
          .collection(AppConstants.callsCollection)
          .where('callerId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();

      final recieverSnapshot = await _dataSource.firestore
          .collection(AppConstants.callsCollection)
          .where('receiverId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();

      final allDocs = [
        ...callerSnapshot.docs,
        ...recieverSnapshot.docs,
      ];

      final calls = allDocs
          .map((doc) => CallModel.fromFirestore(doc).toEntity())
          .toList();

      // Sort merged list by startedAt descending
      calls.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      
      return right(calls);
    } catch (e) {
      AppLogger.error('Get recent calls failed', error: e);
      return left('Failed to get recent calls');
    }
  }

  @override
  Future<Either<String, void>> sendOffer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> offer,
  }) async {
    AppLogger.info('Sending offer for call: $callId');
    return await _dataSource.sendOffer(
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      offer: offer,
    );
  }

  @override
  Future<Either<String, void>> sendAnswer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> answer,
  }) async {
    AppLogger.info('Sending answer for call: $callId');
    return await _dataSource.sendAnswer(
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      answer: answer,
    );
  }

  @override
  Future<Either<String, void>> sendIceCandidate({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> candidate,
  }) async {
    AppLogger.info('Sending ICE candidate for call: $callId');
    return await _dataSource.sendIceCandidate(
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      candidate: candidate,
    );
  }

  @override
  Stream<SignalingEntity> listenForOffers(String userId) {
    return _dataSource.listenForOffers(userId);
  }

  @override
  Stream<SignalingEntity> listenForAnswers(String callId, String userId) {
    return _dataSource.firestore
        .collection(AppConstants.callsCollection)
        .doc(callId)
        .collection('signaling')
        .where('type', isEqualTo: 'answer')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .asyncExpand((snapshot) async* {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          yield SignalingEntity.fromMap({
            ...data,
            'id': change.doc.id,
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
          });
        }
      }
    });
  }

  @override
  Stream<SignalingEntity> listenForIceCandidates(String callId, String userId) {
    return _dataSource.firestore
        .collection(AppConstants.callsCollection)
        .doc(callId)
        .collection('signaling')
        .where('type', isEqualTo: 'candidate')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .asyncExpand((snapshot) async* {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          yield SignalingEntity.fromMap({
            ...data,
            'id': change.doc.id,
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
          });
        }
      }
    });
  }

  @override
  Stream<CallEntity> listenForCallUpdates(String callId) {
    return _dataSource.listenForCallUpdates(callId);
  }

  @override
  Future<Either<String, bool>> isUserBusy(String userId) async {
    return await _dataSource.isUserBusy(userId);
  }

  @override
  Future<Either<String, void>> setUserInCall(String userId, bool inCall) async {
    return await _dataSource.setUserBusy(userId, inCall);
  }
}