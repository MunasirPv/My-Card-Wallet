import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionState { authenticated, locked, unauthenticated }

class SessionManager extends Notifier<SessionState> {
  static const _defaultTimeout = Duration(minutes: 2);

  Timer? _inactivityTimer;
  Duration _timeout = _defaultTimeout;

  @override
  SessionState build() => SessionState.unauthenticated;

  void setTimeout(Duration timeout) => _timeout = timeout;

  void onAuthenticated() {
    state = SessionState.authenticated;
    _resetTimer();
  }

  void onActivity() {
    if (state == SessionState.authenticated) _resetTimer();
  }

  void lock() {
    _inactivityTimer?.cancel();
    state = SessionState.locked;
  }

  void logout() {
    _inactivityTimer?.cancel();
    state = SessionState.unauthenticated;
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_timeout, lock);
  }

  void cancelTimer() {
    _inactivityTimer?.cancel();
  }
}

final sessionManagerProvider =
    NotifierProvider<SessionManager, SessionState>(SessionManager.new);
