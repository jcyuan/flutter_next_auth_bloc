# flutter_next_auth_bloc

A Flutter package that provides BLoC integration for `flutter_next_auth_core`, enabling automatic session management and state handling using the BLoC pattern.

## Features

- Automatic session management with `NextAuthBlocScope`
- Session recovery and refetching
- State synchronization via `NextAuthBloc`
- Built on top of `flutter_next_auth_core` and `flutter_bloc`

Example video:

https://github.com/user-attachments/assets/0cd7a786-c57c-4b13-9b08-03bf6f9bba4e

## Installation

Add `flutter_next_auth_bloc` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_next_auth_core: ^1.1.1
  flutter_next_auth_bloc: ^1.0.7
  flutter_bloc: ^9.1.0
```

## Quick Start

### 1. NextAuthClient Configuration

For complete NextAuthClient API reference (Properties, Methods, Event Handling) and examples, please refer to:

[NextAuthClient API reference](https://github.com/jcyuan/flutter_next_auth_core?tab=readme-ov-file#-nextauthclient-api-reference)

### 2. NextAuthBlocScope

`NextAuthBlocScope` is a widget that wraps your app and provides automatic session management. It handles session recovery, refetching, and state synchronization via a `NextAuthBloc`.

#### Parameters

- **client**: `NextAuthClient<T>` (required) - The NextAuthClient instance
- **refetchInterval**: `int?` (optional) - Interval in milliseconds to automatically refetch session from server
- **refetchOnWindowFocus**: `bool` (optional) - Whether to refetch session when app comes to foreground (default: `true`)
- **child**: `Widget` (required) - Your app widget

#### Minimal Example

```dart
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_next_auth_bloc/next_auth_bloc.dart';

void main() {
  final nextAuthClient = NextAuthClient<SessionData>(config);
  
  runApp(NextAuthBlocScope(
    client: nextAuthClient,
    refetchOnWindowFocus: true,
    child: const MyApp(),
  ));
}
```

### 3. Bloc / State

`flutter_next_auth_bloc` exposes a `NextAuthBloc` whose `state` contains the current session and status.

#### state.status

Provides the current session status.

- **Type**: `SessionStatus`
- **Values**: `initial`, `loading`, `authenticated`, `unauthenticated`

#### state.session

Provides the current session data.

- **Type**: `T?` (e.g. `SessionData?`)
- **Returns**: Session data if authenticated, `null` otherwise

#### Minimal Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_next_auth_bloc/next_auth_bloc.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NextAuthBloc<SessionData>, NextAuthState<SessionData>>(
      builder: (context, authState) {
        final sessionStatus = authState.status;
        final session = authState.session;
    
        return Text('Status: ${sessionStatus.name}, Session: ${session?.toString()}');
      },
    );
  }
}
```

### Complete Widget Example

Here's a minimal widget example showing how to use session and status in the build method:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_next_auth_bloc/next_auth_bloc.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: BlocBuilder<NextAuthBloc<SessionData>, NextAuthState<SessionData>>(
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

## Integration into Your Project

To integrate NextAuthClient with next_auth_bloc into your project:

1. Add `flutter_next_auth_core` and `flutter_next_auth_bloc` to your `pubspec.yaml`
2. Implement the `HttpClient` interface (or use a provided implementation)
3. Create `NextAuthConfig` with your server configuration
4. Configure cookie names to match your server-side NextAuth.js configuration
5. Initialize `NextAuthClient` with the config
6. Register OAuth providers if needed
7. Wrap your app with `NextAuthBlocScope` and pass the `NextAuthClient` instance
8. Use `BlocBuilder` to read `NextAuthState` (`status` / `session`) in your widgets

## Example

See the [example](example/) directory for a complete integration example including:
- OAuth provider implementation (Google OAuth)
- HTTP client implementation using Dio
- Full working Flutter app

## OAuth Provider Implementation

When implementing your own OAuth provider:

1. Implement the `OAuthProvider` interface
2. The `getAuthorizationData()` method should return `OAuthAuthorizationData` containing:
   - `idToken`: The ID token from the OAuth provider (required)
     - Used as the default silent authorization method
     - Only when the idToken expires or the client OAuth package's silent login fails, will it force login to refresh the idToken
   - `authorizationCode`: The authorization code (optional, for server-side token exchange)
3. See the example project for a complete Google OAuth provider implementation

## See also

**Flutter NextAuth Core**: [https://github.com/jcyuan/flutter_next_auth_core](https://github.com/jcyuan/flutter_next_auth_core)  
**Riverpod integration**: [https://github.com/jcyuan/flutter_next_auth_riverpod](https://github.com/jcyuan/flutter_next_auth_riverpod)
