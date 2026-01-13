import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_next_auth_bloc/next_auth_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:next_auth_client_example/providers/google_oauth_provider.dart';
import 'package:next_auth_client_example/session_data.dart';
import 'package:next_auth_client_example/simple_dio_httpclient.dart';

final getIt = GetIt.instance;

// NextAuthClient with next_auth_bloc integration example
void main() {
  // create configuration with cookie name comments
  final config = NextAuthConfig(
    domain: 'https://example.com',
    authBasePath: '/api/auth',
    httpClient: SimpleDioHttpClient(),
    // cookie name configuration notes:
    // - serverSessionCookieName: server-side session cookie name (optional)
    //   default value changes dynamically based on protocol:
    //   - HTTPS: '__Secure-next-auth.session-token'
    //   - HTTP: 'next-auth.session-token'
    //   must be the same as the one in the server
    //   recommended to specify a fixed value matching your backend configuration
    serverSessionCookieName: 'next-auth.session-token',
    // - serverCSRFTokenCookieName: server CSRF cookie name (optional)
    //   default value changes dynamically based on protocol:
    //   - HTTPS: '__Host-next-auth.csrf-token'
    //   - HTTP: 'next-auth.csrf-token'
    //   must be the same as the one in the server
    //   recommended to specify a fixed value matching your backend configuration
    serverCSRFTokenCookieName: 'next-auth.csrf-token',
    // - sessionSerializer: session serializer
    //   used to serialize and deserialize session data to and from JSON to pass to the server
    //   you can implement your own session serializer by implementing the SessionSerializer interface
    //   example: DefaultSessionSerializer<MySessionModel>()
    sessionSerializer: SessionDataSerializer(),
  );

  final nextAuthClient = NextAuthClient<SessionData>(config);

  // register Google OAuth provider
  nextAuthClient.registerOAuthProvider("google", GoogleOAuthProvider());
  // register your own OAuth provider implementations
  // nextAuthClient.registerOAuthProvider("apple", AppleOAuthProvider());

  // register NextAuthClient to getIt
  getIt.registerSingleton<NextAuthClient<SessionData>>(nextAuthClient);

  // ============================================================================
  // next_auth_bloc Integration
  // ============================================================================
  // Use NextAuthBlocScope to wrap your app for automatic session management
  runApp(
    NextAuthBlocScope<SessionData>(
      client: getIt<NextAuthClient<SessionData>>(),
      // refetchInterval: 30000, // optional: refetch session every 30 seconds
      refetchOnWindowFocus:
          true, // optional: refetch when app comes to foreground
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'NextAuth Bloc Example', home: const _HomePage());
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  StreamSubscription<NextAuthEvent>? _eventsSubscription;

  @override
  void initState() {
    super.initState();

    // ============================================================================
    // Listening to NextAuth Events (SignedInEvent / SignedOutEvent)
    // ============================================================================
    final client = getIt<NextAuthClient<SessionData>>();
    _eventsSubscription = client.eventBus.on<NextAuthEvent>().listen((event) {
      if (!mounted) return;

      if (event is SignedInEvent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Signed in, jwt token: ${event.accessToken.toJson()}, you may save this for your backend API calls',
            ),
          ),
        );
      } else if (event is SignedOutEvent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signed out, you may now clear the jwt token you saved before',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================================
    // Using next_auth_bloc state
    // ============================================================================
    // next_auth_bloc provides a NextAuthBloc whose state contains:
    // - state.status: SessionStatus (initial, loading, authenticated, unauthenticated)
    // - state.session: SessionData? (null if not authenticated)
    return Scaffold(
      appBar: AppBar(title: const Text('NextAuth Bloc Example')),
      body: Center(
        child:
            BlocBuilder<NextAuthBloc<SessionData>, NextAuthState<SessionData>>(
              builder: (context, authState) {
                final sessionStatus = authState.status;
                final session = authState.session;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Session Status: ${sessionStatus.name}'),
                    const SizedBox(height: 16),
                    if (session != null)
                      Text('Session: ${session.toString()}')
                    else
                      const Text('No session'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // Example: Sign in with credentials using getIt
                        final nextAuthClient =
                            getIt<NextAuthClient<SessionData>>();
                        final response = await nextAuthClient.signIn(
                          'credentials',
                          credentialsOptions: CredentialsSignInOptions(
                            email: 'example@example.com',
                            password: 'password',
                            // Optional: turnstile token for security
                            // but it's recommended to use it for security.
                            // turnstileToken: 'yourTurnstileToken',
                          ),
                        );
                        if (!context.mounted) return;
                        if (response.ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sign in successful')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sign in failed: ${response.error}',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Sign In with Password'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        // Example: Sign in with Google OAuth
                        final nextAuthClient =
                            getIt<NextAuthClient<SessionData>>();
                        final response = await nextAuthClient.signIn(
                          'google',
                          oauthOptions: OAuthSignInOptions(
                            provider: 'google',
                            // Optional: turnstile token for security
                            // but it's recommended to use it for security.
                            // turnstileToken: 'yourTurnstileToken',
                          ),
                        );
                        if (!context.mounted) return;
                        if (response.ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Google sign in successful'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Google sign in failed: ${response.error}',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Sign In with Google'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        // Example: Sign out using getIt
                        final nextAuthClient =
                            getIt<NextAuthClient<SessionData>>();
                        await nextAuthClient.signOut();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signed out')),
                        );
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}
