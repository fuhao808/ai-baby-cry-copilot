import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_controller.dart';
import '../theme/app_theme.dart';

class ThemePaletteButton extends ConsumerWidget {
  const ThemePaletteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Theme palette',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => const _ThemePaletteSheet(),
      ),
      icon: const Icon(Icons.palette_outlined),
    );
  }
}

class _ThemePaletteSheet extends ConsumerWidget {
  const _ThemePaletteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPalette = ref.watch(themeSettingsProvider).palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme palette', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'The app follows system light or dark mode. Pick the palette family you prefer.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
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
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
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
