import 'package:flutter/material.dart';
import '../../models/route_result.dart';
import '../theme/app_theme.dart';

/// Displays route warnings returned by the routing provider (e.g. clearance,
/// weight, or hazmat restriction notices from HERE Routing API v8).
///
/// Hidden automatically when [RouteResult.warnings] is empty.
class RouteWarningsCard extends StatelessWidget {
  const RouteWarningsCard({super.key, required this.result});

  final RouteResult result;

  @override
  Widget build(BuildContext context) {
    if (result.warnings.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded,
                  size: 16, color: cs.onErrorContainer),
              const SizedBox(width: AppTheme.spaceXS),
              Text(
                'Route Warnings',
                style: tt.labelMedium?.copyWith(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXS),
          for (final warning in result.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style:
                          tt.bodySmall?.copyWith(color: cs.onErrorContainer)),
                  Expanded(
                    child: Text(
                      warning,
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
