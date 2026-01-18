
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webrtc_flutter/presentation/router/route_names.dart';
import 'package:webrtc_flutter/presentation/views/auth/register_screen.dart';

import '../providers/auth_provider.dart';
import '../views/auth/login_screen.dart';
import '../views/call/audio_call_screen.dart';
import '../views/call/incoming_call_screen.dart';
import '../views/call/video_call_screen.dart';
import '../views/home/calls_screen.dart';
import '../views/home/contacts_screen.dart';
import '../views/home/home_screen.dart';
import '../views/home/profile_screen.dart';
import '../views/settings/settings_screen.dart';
import 'go_router_notifier.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final routerNotifier = ref.watch(goRouterNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.login,
    debugLogDiagnostics: true,
    refreshListenable: routerNotifier,
    routes: [
      //Auth routes
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app routes
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.contacts,
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: RouteNames.calls,
        builder: (context, state) => const CallsScreen(),
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Call routes
      GoRoute(
        path: RouteNames.incomingCall,
        builder: (context, state) {
          final callData = state.extra as Map<String, dynamic>;
          return IncomingCallScreen(callData: callData);
        },
      ),
      GoRoute(
        path: RouteNames.videoCall,
        builder: (context, state) {
          return VideoCallScreen(extra: state.extra as Map<String, dynamic>?);
        },
      ),
      GoRoute(
        path: RouteNames.audioCall,
        builder: (context, state) {
          return AudioCallScreen(extra: state.extra as Map<String, dynamic>?);
        },
      ),
      // Add other routes here as we create screens
    ],
    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final isAuthRoute = state.matchedLocation == RouteNames.login ||
          state.matchedLocation == RouteNames.register ||
          state.matchedLocation == RouteNames.forgotPassword;

      // If user is not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute) {
        return RouteNames.login;
      }

      // If user is authenticated and trying to access auth routes
      if (isAuthenticated && isAuthRoute) {
        return RouteNames.home;
      }

      return null;
    },
  );
});