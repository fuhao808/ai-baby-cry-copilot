import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/recording_flow_controller.dart';
import 'providers/theme_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/result_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const ProviderScope(child: BabyCryCopilotApp()));
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp();
    return;
  } on FirebaseException {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

class BabyCryCopilotApp extends ConsumerWidget {
  const BabyCryCopilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeSettingsProvider).palette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Baby Cry Copilot',
      themeMode: ThemeMode.system,
      theme: buildAppTheme(palette: palette, brightness: Brightness.light),
      darkTheme: buildAppTheme(palette: palette, brightness: Brightness.dark),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      data: (user) {
        if (user == null) {
          return const AuthScreen();
        }

        return FlowRouter(user: user);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Authentication failed: $error'),
          ),
        ),
      ),
    );
  }
}

class FlowRouter extends ConsumerWidget {
  const FlowRouter({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingFlowControllerProvider);

    switch (state.phase) {
      case RecordingPhase.analyzing:
        return const LoadingScreen();
      case RecordingPhase.result:
        return ResultScreen(user: user);
      case RecordingPhase.idle:
      case RecordingPhase.recording:
        return HomeScreen(user: user);
    }
  }
}
