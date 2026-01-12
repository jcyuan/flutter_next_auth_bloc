import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_next_auth/next_auth.dart';

class Opt<T> {
  final T? value;
  const Opt(this.value);
  static const Opt absent = Opt(null);
}

class NextAuthState<T extends Map<String, dynamic>> {
  final T? session;
  final SessionStatus status;

  const NextAuthState({
    this.session,
    required this.status,
  });

  NextAuthState<T> copyWith({
    Opt<T>? session,
    Opt<SessionStatus>? status,
  }) {
    return NextAuthState<T>(
      session: session == null ? this.session : session.value,
      status: status == null ? this.status : status.value!
    );
  }
}

/// Bloc that manages NextAuthClient state, refetch timer, and app lifecycle
class NextAuthBloc<T extends Map<String, dynamic>>
    extends Cubit<NextAuthState<T>> with WidgetsBindingObserver {
  final NextAuthClient<T> _client;
  final int? _storedRefetchInterval;
  final bool _storedRefetchOnWindowFocus;
  Timer? _refetchTimer;
  bool _isAppInForeground = true;
  bool _isObserverAdded = false;
  StreamSubscription<NextAuthEvent>? _eventsSubscription;

  NextAuthBloc({
    required NextAuthClient<T> client,
    int? refetchInterval,
    bool refetchOnWindowFocus = true,
  })  : _client = client,
        _storedRefetchInterval = refetchInterval,
        _storedRefetchOnWindowFocus = refetchOnWindowFocus,
        super(NextAuthState<T>(status: SessionStatus.initial)) {
    _eventsSubscription = _client.eventBus.on<NextAuthEvent>().listen((event) {
      if (event is SessionChangedEvent) {
        _handleSessionChanged(event.session as T?);
      } else if (event is StatusChangedEvent) {
        _handleStatusChanged(event.status);
      }
    });

    if (!_isObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverAdded = true;
    }

    if (_storedRefetchInterval != null && _storedRefetchInterval > 0) {
      _startRefetchTimer(_storedRefetchInterval);
    }

    // initial state
    emit(NextAuthState<T>(
      session: _client.session,
      status: _client.status,
    ));
  }

  void _handleStatusChanged(SessionStatus status) {
    if (isClosed) return;
    emit(state.copyWith(status: Opt(status)));
  }

  void _handleSessionChanged(T? session) {
    if (isClosed) return;
    emit(state.copyWith(session: Opt(session)));
  }

  void _startRefetchTimer(int intervalMs) {
    if (intervalMs <= 0) return;
    if (!_isAppInForeground) return;

    _refetchTimer?.cancel();
    _refetchTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _refetchSession(),
    );
  }

  void _stopRefetchTimer() {
    _refetchTimer?.cancel();
    _refetchTimer = null;
  }

  Future<void> _refetchSession() async {
    if (!_isAppInForeground) return;
    try {
      await _client.refetchSession();
    } catch (_) {
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        _stopRefetchTimer();
        break;
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (_storedRefetchInterval != null && _storedRefetchInterval > 0) {
          _startRefetchTimer(_storedRefetchInterval);
          if (_storedRefetchOnWindowFocus) {
            _refetchSession();
          }
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// get NextAuthClient instance
  NextAuthClient<T>? get client => _client;

  @override
  Future<void> close() {
    _stopRefetchTimer();
    _eventsSubscription?.cancel();
    if (_isObserverAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverAdded = false;
    }
    return super.close();
  }
}

/// Scope widget for NextAuth Bloc
/// Wrap your app with this widget to provide NextAuthClient and configuration
/// 
/// This widget will wait for the client to be initialized before rendering its child,
/// ensuring that session and status are available when any page first watches them.
/// 
/// Example:
/// ```dart
/// final client = NextAuthClient(config);
/// 
/// NextAuthBlocScope(
///   client: client,
///   refetchInterval: 30000,
///   refetchOnWindowFocus: true,
///   child: MyApp(),
/// )
/// ```
class NextAuthBlocScope extends StatelessWidget {
  final NextAuthClient<Map<String, dynamic>> client;
  /// in milliseconds
  final int? refetchInterval;
  final bool refetchOnWindowFocus;
  final Widget child;

  const NextAuthBlocScope({
    super.key,
    required this.client,
    this.refetchInterval,
    this.refetchOnWindowFocus = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = NextAuthBloc<Map<String, dynamic>>(
      client: client,
      refetchInterval: refetchInterval,
      refetchOnWindowFocus: refetchOnWindowFocus,
    );

    // Directly call without waiting, because the child widget needs to determine which UI 
    // to display based on SessionStatus and SessionStatus will be updated when 
    // recoverLoginStatusFromCache is finished initializing.
    client.recoverLoginStatusFromCache();

    return BlocProvider<NextAuthBloc<Map<String, dynamic>>>(
      create: (_) => bloc,
      child: child,
    );
  }
}
