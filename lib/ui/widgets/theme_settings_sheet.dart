import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../services/theme_settings_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that lets drivers personalise the app's color scheme.
///
/// Features:
/// - Six preset theme tiles with live color previews.
/// - A custom palette section (shown when the Custom preset is selected)
///   offering 18 Material accent colors.
/// - A "Reset to Default" button that restores the Classic theme.
/// - All selections are applied instantly and persisted between sessions.
class ThemeSettingsSheet extends StatelessWidget {
  const ThemeSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Consumer<AppState>(
      builder: (context, state, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMD,
              AppTheme.spaceSM,
              AppTheme.spaceMD,
              AppTheme.spaceMD,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      Icon(Icons.palette_rounded, color: cs.primary, size: 28),
                      const SizedBox(width: AppTheme.spaceSM),
                      Text('Color Theme', style: tt.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    'Choose a preset or create your own color scheme.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                  const Divider(),
                  const SizedBox(height: AppTheme.spaceSM),

                  // ── Preset theme grid ────────────────────────────────────
                  Text('Presets', style: tt.titleSmall),
                  const SizedBox(height: AppTheme.spaceSM),
                  _PresetGrid(
                    selected: state.themeOption,
                    onSelect: (option) {
                      HapticFeedback.selectionClick();
                      state.setThemeOption(option);
                    },
                  ),

                  // ── Custom palette (only when Custom is selected) ────────
                  if (state.themeOption == ThemeOption.custom) ...[
                    const SizedBox(height: AppTheme.spaceMD),
                    const Divider(),
                    const SizedBox(height: AppTheme.spaceSM),
                    Text('Custom Accent Color', style: tt.titleSmall),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      'Tap a color to apply it as your accent.',
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _CustomPalette(
                      selectedColor: state.customAccentColor,
                      onSelect: (color) {
                        HapticFeedback.selectionClick();
                        state.setCustomAccentColor(color);
                      },
                    ),
                  ],

                  const SizedBox(height: AppTheme.spaceMD),
                  const Divider(),
                  const SizedBox(height: AppTheme.spaceSM),

                  // ── Live preview ─────────────────────────────────────────
                  Text('Preview', style: tt.titleSmall),
                  const SizedBox(height: AppTheme.spaceSM),
                  _ThemePreviewCard(seedColor: state.effectiveSeedColor),

                  const SizedBox(height: AppTheme.spaceMD),
                  const Divider(),
                  const SizedBox(height: AppTheme.spaceSM),

                  // ── Reset button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset to Default'),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        state.resetTheme();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Theme reset to Classic'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Preset grid
// ---------------------------------------------------------------------------

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({
    required this.selected,
    required this.onSelect,
  });

  final ThemeOption selected;
  final ValueChanged<ThemeOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: ThemeOption.values
          .map((option) => _PresetTile(
                option: option,
                isSelected: selected == option,
                onTap: () => onSelect(option),
              ))
          .toList(),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seed = ThemeSettingsService.presetSeedColors[option]!;
    final label = ThemeSettingsService.optionLabels[option]!;
    final previewCs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 88,
        padding: const EdgeInsets.all(AppTheme.spaceXS),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini color swatch
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ColorDot(color: previewCs.primary),
                const SizedBox(width: 3),
                _ColorDot(color: previewCs.secondary),
                const SizedBox(width: 3),
                _ColorDot(color: previewCs.tertiary),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXS),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                  ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected) ...[
              const SizedBox(height: 2),
              Icon(Icons.check_circle_rounded,
                  size: 14, color: cs.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom color palette
// ---------------------------------------------------------------------------

class _CustomPalette extends StatelessWidget {
  const _CustomPalette({
    required this.selectedColor,
    required this.onSelect,
  });

  final Color selectedColor;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: ThemeSettingsService.customPalette
          .map(
            (color) => _PaletteChip(
              color: color,
              isSelected: selectedColor.value == color.value,
              onTap: () => onSelect(color),
            ),
          )
          .toList(),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(128),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live theme preview card
// ---------------------------------------------------------------------------

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final lightCs =
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
    final darkCs =
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);

    return Row(
      children: [
        Expanded(child: _MiniPreview(cs: lightCs, label: 'Light')),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(child: _MiniPreview(cs: darkCs, label: 'Dark')),
      ],
    );
  }
}

class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.cs, required this.label});

  final ColorScheme cs;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppTheme.spaceSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulated app-bar strip
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 40,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Simulated primary button
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          // Simulated secondary surface
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXS),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
