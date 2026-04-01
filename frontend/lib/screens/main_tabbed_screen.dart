import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_mode_controller.dart';
import '../providers/recording_flow_controller.dart';
import '../widgets/theme_palette_sheet.dart';
import 'guide_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

class MainTabbedScreen extends ConsumerStatefulWidget {
  const MainTabbedScreen({super.key, required this.user});

  final User user;

  @override
  ConsumerState<MainTabbedScreen> createState() => _MainTabbedScreenState();
}

class _MainTabbedScreenState extends ConsumerState<MainTabbedScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(recordingFlowControllerProvider);
    final isTestMode = ref.watch(appModeProvider).isTestMode;
    final pages = [
      HomeScreen(user: widget.user),
      const GuideScreen(),
      HistoryScreen(userId: widget.user.uid),
    ];
    final title = switch (_currentIndex) {
      0 => switch (flowState.phase) {
          RecordingPhase.recording => "I'm Listening...",
          RecordingPhase.analyzing => 'AI is Thinking...',
          _ => "How's Baby?",
        },
      1 => 'Library',
      _ => 'Recent History',
    };

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(title, key: ValueKey(title)),
        ),
        actions: [
          IconButton(
            tooltip: isTestMode ? 'Disable test mode' : 'Enable test mode',
            onPressed: () => ref.read(appModeProvider.notifier).toggleTestMode(),
            icon: Icon(
              isTestMode ? Icons.science_rounded : Icons.science_outlined,
            ),
          ),
          const ThemePaletteButton(),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled_rounded),
            label: 'History',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
