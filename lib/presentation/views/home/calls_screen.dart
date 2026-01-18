import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  final List<Map<String, dynamic>> _callLogs = [
    // Mock data - will be replaced with real data from Firestore
    {
      'id': '1',
      'name': 'John Doe',
      'type': AppConstants.callTypeVideo,
      'status': AppConstants.callStatusEnded,
      'duration': const Duration(minutes: 5, seconds: 23),
      'time': DateTime.now().subtract(const Duration(hours: 1)),
      'isIncoming': true,
      'isMissed': false,
    },
    {
      'id': '2',
      'name': 'Jane Smith',
      'type': AppConstants.callTypeAudio,
      'status': AppConstants.callStatusMissed,
      'duration': null,
      'time': DateTime.now().subtract(const Duration(hours: 3)),
      'isIncoming': true,
      'isMissed': true,
    },
    {
      'id': '3',
      'name': 'Alex Johnson',
      'type': AppConstants.callTypeVideo,
      'status': AppConstants.callStatusEnded,
      'duration': const Duration(minutes: 12, seconds: 45),
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'isIncoming': false,
      'isMissed': false,
    },
  ];

  Widget _buildCallTypeIcon(Map<String, dynamic> call) {
    final isVideo = call['type'] == AppConstants.callTypeVideo;
    final isMissed = call['isMissed'] == true;

    if (isVideo) {
      return Icon(
        call['isIncoming'] ? Icons.video_call : Icons.videocam,
        color: isMissed ? AppColors.callMissed : AppColors.callConnected,
        size: 24,
      );
    } else {
      return Icon(
        call['isIncoming'] ? Icons.call_received : Icons.call_made,
        color: isMissed ? AppColors.callMissed : AppColors.callConnected,
        size: 24,
      );
    }
  }

  Widget _buildStatusIcon(Map<String, dynamic> call) {
    if (call['isMissed'] == true) {
      return Icon(
        Icons.close,
        color: AppColors.callMissed,
        size: 16,
      );
    }

    return Icon(
      Icons.check,
      color: AppColors.callConnected,
      size: 16,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (time.isAfter(today)) {
      return DateFormat('h:mm a').format(time);
    } else if (time.isAfter(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     'Call History',
      //     style: TextStyles.h2,
      //   ),
      //   actions: [
      //     IconButton(
      //       onPressed: () {
      //         // TODO: Implement call history filter
      //       },
      //       icon: const Icon(Icons.filter_list),
      //     ),
      //   ],
      // ),
      body: _callLogs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.call_end_rounded,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No call history',
              style: TextStyles.h3.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calls you make or receive will appear here',
              style: TextStyles.bodyMedium.copyWith(
                color: AppColors.textDisabled,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _callLogs.length,
        itemBuilder: (context, index) {
          final call = _callLogs[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // TODO: Implement call details
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Call Type Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: call['isMissed'] == true
                              ? AppColors.callMissed.withOpacity(0.1)
                              : AppColors.callConnected.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _buildCallTypeIcon(call),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Call Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    call['name'],
                                    style: TextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: call['isMissed'] == true
                                          ? AppColors.callMissed
                                          : AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                _buildStatusIcon(call),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                Text(
                                  _formatTime(call['time']),
                                  style: TextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),

                                if (call['duration'] != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.textSecondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    call['duration'].toString().substring(2, 7),
                                    style: TextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Call Action Button
                      call['type'] == AppConstants.callTypeVideo
                          ? IconButton(
                        onPressed: () {
                          // TODO: Implement video call back
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.videocam,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      )
                          : IconButton(
                        onPressed: () {
                          // TODO: Implement audio call back
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.call,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}