
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webrtc_flutter/presentation/router/route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  //final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: RouteNames.login,
    debugLogDiagnostics: true,
    //refreshListenable: GoRouterRefreshStream(authState),
    routes: [
      // Auth routes
      // GoRoute(
      //   path: RouteNames.login,
      //   builder: (context, state) => const LoginScreen(),
      // ),
      // Add other routes here as we create screens
    ],
    redirect: (context, state) {
      // final isAuthenticated = authState.value != null;
      // final isAuthRoute = state.matchedLocation == RouteNames.login ||
      //     state.matchedLocation == RouteNames.register ||
      //     state.matchedLocation == RouteNames.forgotPassword;
      //
      // // If user is not authenticated and trying to access protected route
      // if (!isAuthenticated && !isAuthRoute) {
      //   return RouteNames.login;
      // }
      //
      // // If user is authenticated and trying to access auth routes
      // if (isAuthenticated && isAuthRoute) {
      //   return RouteNames.home;
      // }

      return null;
    },
  );
});