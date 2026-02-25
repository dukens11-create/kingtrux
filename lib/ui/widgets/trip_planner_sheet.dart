import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../../models/trip_stop.dart';
import '../../services/voice_command_service.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// A bottom sheet that lets the user manage a multi-stop trip.
///
/// Features:
/// - Add a stop from the current destination or current location
/// - Remove stops
/// - Drag-to-reorder stops
/// - Optimize stop order (nearest-neighbour + 2-opt)
/// - Build the trip route
/// - Clear the trip
class TripPlannerSheet extends StatelessWidget {
  const TripPlannerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<AppState>(
          builder: (context, state, _) {
            return _TripPlannerContent(
              scrollController: scrollController,
              state: state,
            );
          },
        );
      },
    );
  }
}

class _TripPlannerContent extends StatefulWidget {
  const _TripPlannerContent({
    required this.scrollController,
    required this.state,
  });

  final ScrollController scrollController;
  final AppState state;

  @override
  State<_TripPlannerContent> createState() => _TripPlannerContentState();
}

class _TripPlannerContentState extends State<_TripPlannerContent> {
  late final VoiceCommandService _voiceService;
  final SpeechToText _speech = SpeechToText();

  bool _isSttAvailable = false;
  bool _isListening = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceCommandService()
      ..language = widget.state.voiceLanguage
      ..onSpeak = widget.state.speakText
      ..onAddressRecognized = _handleAddressRecognized
      ..onBuildRoute = _handleBuildRoute
      ..onLanguageChanged = (lang) {
        widget.state.setVoiceLanguage(lang);
      }
      ..onStateChanged = (_) {
        if (mounted) setState(() {});
      };
    _initStt();
  }

  Future<void> _initStt() async {
    final available = await _speech.initialize(
      onError: (error) {
        debugPrint('STT error: ${error.errorMsg}');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() => _isSttAvailable = available);
  }

  Future<void> _handleAddressRecognized(String address) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    final result = await widget.state.geocodeAndAddTripStop(address);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (result != null) {
      _voiceService.confirmAddressAdded(result.label);
    } else {
      _voiceService.rejectAddress();
    }
    if (_voiceService.state != VoiceCommandState.idle) {
      _startListening();
    }
  }

  Future<void> _handleBuildRoute() async {
    if (!mounted) return;
    await widget.state.buildTripRoute();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startListening() async {
    if (!_isSttAvailable || _isListening || _isProcessing) return;
    // Keep service language in sync with app setting.
    _voiceService.language = widget.state.voiceLanguage;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          if (mounted) setState(() => _isListening = false);
          _voiceService.process(result.recognizedWords);
          // Auto-restart for states that do not trigger async geocoding.
          final nextState = _voiceService.state;
          if (!_isProcessing &&
              nextState != VoiceCommandState.idle &&
              nextState != VoiceCommandState.awaitingStopAddress &&
              nextState != VoiceCommandState.awaitingCommand) {
            Future<void>.delayed(
              const Duration(milliseconds: 800),
              _startListening,
            );
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      localeId: widget.state.voiceLanguage,
      cancelOnError: true,
    );
    if (mounted) setState(() => _isListening = true);
  }

  void _onMicPressed() {
    if (_voiceService.state == VoiceCommandState.idle) {
      _voiceService.startListening();
      _startListening();
    } else {
      _stopVoiceCommand();
    }
  }

  Future<void> _stopVoiceCommand() async {
    await _speech.stop();
    _voiceService.reset();
    if (mounted) {
      setState(() {
        _isListening = false;
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _voiceService.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trip = widget.state.activeTrip;
    final stops = trip?.stops ?? [];
    final isVoiceActive = _voiceService.state != VoiceCommandState.idle;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusXL),
      ),
      child: Column(
        children: [
          // Drag handle
          _DragHandle(cs: cs),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: AppTheme.spaceXS,
            ),
            child: Row(
              children: [
                Icon(Icons.route_rounded, color: cs.primary),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Text(
                    trip?.name ?? 'Trip Planner',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Mic button — only shown when STT is available on this device
                if (_isSttAvailable)
                  IconButton(
                    icon: _isProcessing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : Icon(
                            _isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: (_isListening || isVoiceActive)
                                ? cs.error
                                : cs.onSurfaceVariant,
                          ),
                    tooltip: isVoiceActive
                        ? 'Stop voice command'
                        : 'Start voice command',
                    onPressed: _isProcessing ? null : _onMicPressed,
                  ),
                if (stops.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                    ),
                    onPressed: () => widget.state.clearTrip(),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Voice command status bar
          if (isVoiceActive)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceXS,
              ),
              child: Row(
                children: [
                  if (_isListening)
                    Icon(Icons.graphic_eq_rounded,
                        size: 16, color: cs.error)
                  else if (_isProcessing)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(Icons.mic_off_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: AppTheme.spaceXS),
                  Expanded(
                    child: Text(
                      _voiceStatusLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),

          // Stop list
          Expanded(
            child: stops.isEmpty
                ? _EmptyState(cs: cs)
                : ReorderableListView.builder(
                    scrollController: widget.scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceXS,
                    ),
                    itemCount: stops.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      widget.state.reorderTripStop(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      final isFirst = index == 0;
                      final isLast = index == stops.length - 1;
                      return _StopTile(
                        key: ValueKey(stop.id),
                        stop: stop,
                        index: index,
                        isFirst: isFirst,
                        isLast: isLast,
                        onRemove: () =>
                            widget.state.removeTripStop(stop.id),
                      );
                    },
                  ),
          ),

          // Error message
          if (widget.state.tripRouteError != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceXS,
              ),
              child: Text(
                widget.state.tripRouteError!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.error),
              ),
            ),

          // Action buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              child: _ActionRow(state: widget.state),
            ),
          ),
        ],
      ),
    );
  }

  String _voiceStatusLabel() {
    if (_isProcessing) return 'Resolving address\u2026';
    if (_isListening) {
      return switch (_voiceService.state) {
        VoiceCommandState.awaitingCommand =>
          'Say "Kingtrux add <address>" or "Kingtrux multiple stop"',
        VoiceCommandState.awaitingStopCount => 'Say the number of stops',
        VoiceCommandState.awaitingStopAddress => 'Speak the address',
        VoiceCommandState.awaitingConfirm =>
          'Say "build route" or "cancel"',
        VoiceCommandState.idle => '',
      };
    }
    return switch (_voiceService.state) {
      VoiceCommandState.awaitingCommand => 'Tap mic to continue',
      VoiceCommandState.awaitingStopCount => 'Tap mic to say stop count',
      VoiceCommandState.awaitingStopAddress => 'Tap mic to speak address',
      VoiceCommandState.awaitingConfirm =>
        'Tap mic — say "build route" or "cancel"',
      VoiceCommandState.idle => '',
    };
  }
}

// ---------------------------------------------------------------------------
// Action row
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final stops = state.activeTrip?.stops ?? [];
    final hasEnoughStops = stops.length >= 2;
    final hasIntermediates = stops.length >= 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add-stop buttons row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Add Current Location'),
                onPressed: state.myLat != null
                    ? () => _addCurrentLocation(context, state)
                    : null,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('Add Destination'),
                onPressed: state.destLat != null
                    ? () => _addDestination(context, state)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSM),
        // Optimize + Build Route row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Optimize Order'),
                onPressed: hasIntermediates
                    ? () => context.read<AppState>().optimizeTripStopOrder()
                    : null,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: FilledButton.icon(
                icon: state.isLoadingTripRoute
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Build Route'),
                onPressed: hasEnoughStops && !state.isLoadingTripRoute
                    ? () async {
                        await context.read<AppState>().buildTripRoute();
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addCurrentLocation(BuildContext context, AppState state) {
    final stop = TripStop(
      id: const Uuid().v4(),
      label: 'Current Location',
      lat: state.myLat!,
      lng: state.myLng!,
      createdAt: DateTime.now(),
    );
    context.read<AppState>().addTripStop(stop);
  }

  void _addDestination(BuildContext context, AppState state) {
    final stop = TripStop(
      id: const Uuid().v4(),
      label: 'Destination',
      lat: state.destLat!,
      lng: state.destLng!,
      createdAt: DateTime.now(),
    );
    context.read<AppState>().addTripStop(stop);
  }
}

// ---------------------------------------------------------------------------
// Stop list tile
// ---------------------------------------------------------------------------

class _StopTile extends StatelessWidget {
  const _StopTile({
    super.key,
    required this.stop,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onRemove,
  });

  final TripStop stop;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color iconColor;
    IconData iconData;
    if (isFirst) {
      iconColor = cs.primary;
      iconData = Icons.trip_origin_rounded;
    } else if (isLast) {
      iconColor = cs.error;
      iconData = Icons.flag_rounded;
    } else {
      iconColor = cs.secondary;
      iconData = Icons.circle_outlined;
    }

    return ListTile(
      key: key,
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, color: iconColor, size: 22),
        ],
      ),
      title: Text(
        stop.label ?? 'Stop ${index + 1}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove_circle_outline_rounded,
                color: cs.error, size: 20),
            tooltip: 'Remove stop',
            onPressed: onRemove,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded,
                color: cs.onSurfaceVariant, size: 22),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_location_alt_rounded,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'No stops yet.\nAdd your origin, stops, and destination.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
