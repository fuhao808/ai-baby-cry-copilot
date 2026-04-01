import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_controller.dart';
import '../theme/app_theme.dart';
import 'frosted_panel.dart';

class ThemePaletteButton extends ConsumerWidget {
  const ThemePaletteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Theme palette',
      onPressed: () => showThemePaletteSheet(context),
      icon: const Icon(Icons.palette_outlined),
    );
  }
}

Future<void> showThemePaletteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: true,
    builder: (context) => const _ThemePaletteSheet(),
  );
}

class _ThemePaletteSheet extends ConsumerWidget {
  const _ThemePaletteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPalette = ref.watch(themeSettingsProvider).palette;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.76;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: FrostedPanel(
            radius: 40,
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accent Color', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'This changes only the primary highlight color. The cream background and rounded layout stay consistent.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  for (final palette in AppPalette.values) ...[
                    _PaletteTile(
                      palette: palette,
                      selected: palette == currentPalette,
                      onTap: () async {
                        await ref
                            .read(themeSettingsProvider.notifier)
                            .setPalette(palette);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = paletteSpecFor(palette);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Row(
              children: [
                _Swatch(color: spec.lightBackground),
                _Swatch(color: spec.seed),
                _Swatch(color: spec.accent),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    palette.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    palette.subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
