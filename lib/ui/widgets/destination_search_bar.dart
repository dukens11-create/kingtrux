import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A tappable "Set destination for truck routes" search bar.
///
/// Used on the main [MapScreen] (always visible) and inside [PoiHubSheet] so
/// the driver can open the [WhereToSheet] destination picker from either
/// location without duplicating styling logic.
class DestinationSearchBar extends StatelessWidget {
  const DestinationSearchBar({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  /// Approximate rendered height (2 × [AppTheme.spaceMD] padding + 22 px icon).
  /// Referenced by the map-screen [Stack] to position widgets below this bar.
  static const double height = 54.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Set destination for truck routes',
      button: true,
      child: InkWell(
        key: const Key('destination_search_bar'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceMD,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: cs.primary, size: 22),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  'Set destination for truck routes',
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
