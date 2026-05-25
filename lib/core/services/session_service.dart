import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Auto-logout after inactivity.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  Timer? _timer;
  VoidCallback? _onTimeout;

  void bind({required VoidCallback onTimeout}) {
    _onTimeout = onTimeout;
    reset();
  }

  void reset() {
    _timer?.cancel();
    _timer = Timer(
      const Duration(minutes: AppConstants.sessionTimeoutMinutes),
      () => _onTimeout?.call(),
    );
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _onTimeout = null;
  }
}

/// Resets session timer on any pointer down inside subtree.
class SessionActivityDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onActivity;

  const SessionActivityDetector({
    super.key,
    required this.child,
    this.onActivity,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        SessionService.instance.reset();
        onActivity?.call();
      },
      child: child,
    );
  }
}
