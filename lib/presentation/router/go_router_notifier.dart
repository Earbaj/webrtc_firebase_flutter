import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class GoRouterNotifier extends ChangeNotifier {
  late final StreamSubscription _subscription;

  GoRouterNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouterNotifierProvider = Provider<GoRouterNotifier>((ref) {
  final authStream = ref.watch(authProvider.stream);
  final notifier = GoRouterNotifier(authStream);

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});

