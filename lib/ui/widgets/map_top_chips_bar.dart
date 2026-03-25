import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'poi_hub_sheet.dart';

/// A compact horizontal row of [FilterChip]s displayed below the app bar.
///
/// Exposes the three map-overlay quick-toggles:
/// - **Places** – opens the [PoiHubSheet] for POI browsing.
/// - **Traffic Cams** – placeholder (Coming soon).
/// - **DOT 511s** – placeholder (Coming soon).
class MapTopChipsBar extends StatelessWidget {
  const MapTopChipsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceXS,
          ),
          child: Row(
            children: [
              _OverlayChip(
                key: const Key('chip_places'),
                label: 'Places',
                icon: Icons.place_rounded,
                isSelected: false,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: state,
                      child: const PoiHubSheet(),
                    ),
                  );
                },
              ),
              const SizedBox(width: AppTheme.spaceXS),
              _OverlayChip(
                key: const Key('chip_traffic_cams'),
                label: 'Traffic Cams',
                icon: Icons.videocam_outlined,
                isSelected: false,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Traffic Cams — Coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: AppTheme.spaceXS),
              _OverlayChip(
                key: const Key('chip_dot_511'),
                label: 'DOT 511s',
                icon: Icons.announcement_outlined,
                isSelected: false,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('DOT 511s — Coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final void Function(bool) onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXS,
        vertical: 0,
      ),
    );
  }
}
