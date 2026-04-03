import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_mode_controller.dart';
import '../providers/recording_flow_controller.dart';
import '../widgets/pacifier_mark.dart';
import '../widgets/frosted_panel.dart';
import '../widgets/theme_palette_sheet.dart';
import 'guide_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'loading_screen.dart';
import 'result_screen.dart';

class MainTabbedScreen extends ConsumerStatefulWidget {
  const MainTabbedScreen({super.key, required this.user});

  final User user;

  @override
  ConsumerState<MainTabbedScreen> createState() => _MainTabbedScreenState();
}

class _MainTabbedScreenState extends ConsumerState<MainTabbedScreen> {
  int _currentIndex = 0;

  Future<void> _openDeveloperAccess() async {
    final isTestMode = ref.read(appModeProvider).isTestMode;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: FrostedPanel(
              radius: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer Access',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTestMode
                        ? 'Test mode is enabled. Switch back to the regular user experience here.'
                        : 'Enable test mode to expose bundled developer shortcuts on the home screen.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      await ref.read(appModeProvider.notifier).toggleTestMode();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      isTestMode ? 'Switch To User Mode' : 'Enable Test Mode',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(recordingFlowControllerProvider);
    final pages = [
      switch (flowState.phase) {
        RecordingPhase.analyzing => const LoadingScreen(),
        RecordingPhase.result => ResultScreen(user: widget.user),
        RecordingPhase.idle ||
        RecordingPhase.recording ||
        RecordingPhase.paused => HomeScreen(user: widget.user),
      },
      const GuideScreen(),
      HistoryScreen(userId: widget.user.uid),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _BrandBadge(
                          onLongPress: _openDeveloperAccess,
                        ),
                      ),
                      const SizedBox(width: 12),
                      PopupMenuButton<_HeaderAction>(
                        tooltip: 'More',
                        onSelected: (value) async {
                          switch (value) {
                            case _HeaderAction.palette:
                              await showThemePaletteSheet(context);
                              break;
                            case _HeaderAction.signOut:
                              await ref.read(authServiceProvider).signOut();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _HeaderAction.palette,
                            child: Text('Accent color'),
                          ),
                          const PopupMenuItem(
                            value: _HeaderAction.signOut,
                            child: Text('Sign out'),
                          ),
                        ],
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.82),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _TopTabs(
                      currentIndex: _currentIndex,
                      onSelect: (index) => setState(() => _currentIndex = index),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: pages[_currentIndex],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HeaderAction { palette, signOut }

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.onLongPress});

  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              );

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.28),
                    ),
                  ],
                ),
                child: const Center(
                  child: PacifierMark(size: 22, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Baby No Cry',
                    maxLines: 1,
                    style: titleStyle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.mic_rounded, 0),
      (Icons.menu_book_rounded, 1),
      (Icons.history_rounded, 2),
    ];

    return FrostedPanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items) ...[
            _TopTabButton(
              icon: item.$1,
              selected: currentIndex == item.$2,
              onTap: () => onSelect(item.$2),
            ),
            if (item.$2 != items.last.$2) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _TopTabButton extends StatelessWidget {
  const _TopTabButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            size: 18,
          ),
        ),
      ),
    );
  }
}
