import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/here_geocoding_service.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that lets the driver pick a destination either by typing an
/// address or by long-pressing on the map (which sets the destination and
/// dismisses the sheet automatically).
///
/// On a confirmed address, the sheet calls [AppState.setDestination] and
/// [AppState.buildTruckRoute], then pops itself.
class WhereToSheet extends StatefulWidget {
  const WhereToSheet({super.key});

  @override
  State<WhereToSheet> createState() => _WhereToSheetState();
}

class _WhereToSheetState extends State<WhereToSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _geocodingService = HereGeocodingService();

  bool _isSearching = false;
  String? _errorMessage;
  GeocodedLocation? _result;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field when the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _result = null;
    });
    final location = await _geocodingService.geocode(query);
    if (!mounted) return;
    if (location == null) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'No results found. Try a more specific address.';
      });
    } else {
      setState(() {
        _isSearching = false;
        _result = location;
      });
    }
  }

  Future<void> _onConfirm(GeocodedLocation location) async {
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    state.setDestination(location.lat, location.lng);
    // Pop before building route so the map is visible during calculation.
    if (mounted) Navigator.of(context).pop();
    try {
      await state.buildTruckRoute();
    } catch (_) {
      // Errors are handled inside buildTruckRoute / AppState.
    }
  }

  void _onMapLongPressTip() {
    if (mounted) Navigator.of(context).pop('long_press');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spaceMD,
              AppTheme.spaceSM,
              AppTheme.spaceMD,
              MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceMD,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text('Where to?', style: tt.titleLarge),
                const SizedBox(height: AppTheme.spaceMD),

                // ── Search field ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('where_to_field'),
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _onSearch(),
                        decoration: InputDecoration(
                          hintText: 'Enter address or place name',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMD,
                            vertical: AppTheme.spaceSM,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    FilledButton(
                      key: const Key('where_to_search_btn'),
                      onPressed: _isSearching ? null : _onSearch,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(AppTheme.spaceMD),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        ),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),

                // ── Error message ─────────────────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppTheme.spaceSM),
                  Row(
                    children: [
                      Icon(Icons.warning_rounded, size: 16, color: cs.error),
                      const SizedBox(width: AppTheme.spaceXS),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: tt.bodySmall?.copyWith(color: cs.error),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Geocoded result ───────────────────────────────────────
                if (_result != null) ...[
                  const SizedBox(height: AppTheme.spaceMD),
                  _ResultCard(
                    location: _result!,
                    onConfirm: () => _onConfirm(_result!),
                  ),
                ],

                const SizedBox(height: AppTheme.spaceLG),
                const Divider(),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Map long-press tip ────────────────────────────────────
                _MapLongPressTip(onDismiss: _onMapLongPressTip),

                const SizedBox(height: AppTheme.spaceSM),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Geocoded result card
// ---------------------------------------------------------------------------

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.location, required this.onConfirm});

  final GeocodedLocation location;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: ListTile(
        leading: Icon(Icons.place_rounded, color: cs.onPrimaryContainer),
        title: Text(
          location.label,
          style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${location.lat.toStringAsFixed(5)}, ${location.lng.toStringAsFixed(5)}',
          style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
        ),
        trailing: FilledButton(
          key: const Key('where_to_confirm_btn'),
          onPressed: onConfirm,
          child: const Text('Go'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map long-press tip
// ---------------------------------------------------------------------------

class _MapLongPressTip extends StatelessWidget {
  const _MapLongPressTip({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.touch_app_rounded, size: 20, color: cs.primary),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Or long-press on the map', style: tt.labelLarge),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                'Long-press anywhere on the map to drop a pin and set that point as your destination.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onDismiss,
          child: const Text('Use Map'),
        ),
      ],
    );
  }
}

/// Shows the [WhereToSheet] as a modal bottom sheet.
///
/// Returns `'long_press'` when the user tapped "Use Map" to indicate they want
/// to long-press on the map instead.
Future<String?> showWhereToSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const WhereToSheet(),
  );
}
