import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_next_auth_core/next_auth.dart';

/// Optional value wrapper for copyWith methods.
/// 
/// Used to distinguish between null values and absent values when updating state.
class Opt<T> {
  /// The wrapped value, which may be null.
  final T? value;
  
  /// Creates an [Opt] with the given [value].
  const Opt(this.value);
  
  /// Represents an absent value (not provided).
  static const Opt absent = Opt(null);
}

/// State class for NextAuth session and status.
/// 
/// Contains the current session data and authentication status.
class NextAuthState<T extends Map<String, dynamic>> {
  /// Current session data, or null if not authenticated.
  final T? session;
  
  /// Current authentication status.
  final SessionStatus status;

  /// Creates a [NextAuthState] with the given [session] and [status].
  const NextAuthState({
    this.session,
    required this.status,
  });

  /// Creates a copy of this state with the given fields replaced.
  /// 
  /// Use [Opt.absent] to keep the current value, or [Opt(value)] to update it.
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

/// Bloc that manages NextAuthClient state, refetch timer, and app lifecycle.
/// 
/// Automatically handles session refetching based on interval and app lifecycle,
/// and emits state changes when session or status updates.
class NextAuthBloc<T extends Map<String, dynamic>>
    extends Cubit<NextAuthState<T>> with WidgetsBindingObserver {
  final NextAuthClient<T> _client;
  final int? _storedRefetchInterval;
  final bool _storedRefetchOnWindowFocus;
  Timer? _refetchTimer;
  bool _isAppInForeground = true;
  bool _isObserverAdded = false;
  StreamSubscription<NextAuthEvent>? _eventsSubscription;

  /// Creates a [NextAuthBloc] with the given configuration.
  /// 
  /// [client] - The NextAuth client instance to manage.
  /// [refetchInterval] - Interval in milliseconds to refetch session. If null, no automatic refetching.
  /// [refetchOnWindowFocus] - Whether to refetch when app comes to foreground. Defaults to true.
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

  /// Gets the underlying NextAuthClient instance.
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
  /// The NextAuth client instance to provide to the bloc.
  final NextAuthClient<Map<String, dynamic>> client;
  
  /// Interval in milliseconds to refetch session. If null, no automatic refetching.
  final int? refetchInterval;
  
  /// Whether to refetch session when app comes to foreground. Defaults to true.
  final bool refetchOnWindowFocus;
  
  /// The widget tree below this scope.
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
