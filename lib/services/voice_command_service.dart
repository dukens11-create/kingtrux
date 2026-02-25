/// States for the voice-command flow.
enum VoiceCommandState {
  /// Not running — tap the mic to start.
  idle,

  /// Listening for "Kingtrux add …" or "Kingtrux multiple stop".
  awaitingCommand,

  /// Waiting for the user to say how many stops they want to add.
  awaitingStopCount,

  /// Waiting for the user to speak an address.
  awaitingStopAddress,

  /// All stops collected — waiting for "build route" or "cancel".
  awaitingConfirm,
}

/// Callback type for TTS feedback.
typedef SpeakCallback = void Function(String text);

/// Callback type when an address utterance is ready for geocoding.
typedef AddressRecognizedCallback = void Function(String address);

/// Callback type when the user confirms they want to build the route.
typedef BuildRouteCallback = void Function();

/// Pure state-machine for voice-command input in the trip planner.
///
/// This class contains no platform code and no Flutter imports so that all
/// parsing and state-transition logic can be tested without a device or
/// mock framework.
///
/// Usage:
/// ```dart
/// final service = VoiceCommandService();
/// service
///   ..onSpeak = (text) => tts.speak(text)
///   ..onAddressRecognized = (addr) async { /* geocode, then call confirmAddressAdded */ }
///   ..onBuildRoute = () => appState.buildTripRoute();
///
/// service.startListening(); // transitions to awaitingCommand
/// service.process(recognizedWords);
/// ```
class VoiceCommandService {
  VoiceCommandState _state = VoiceCommandState.idle;

  /// Current state of the voice-command flow.
  VoiceCommandState get state => _state;

  // Number of stops expected in multiple-stop mode; 0 = single-stop mode.
  int _targetStopCount = 0;
  int _collectedStopCount = 0;

  // ---------------------------------------------------------------------------
  // Callbacks — wired by the owning widget/state
  // ---------------------------------------------------------------------------

  /// Speak [text] via TTS.
  SpeakCallback? onSpeak;

  /// Called with the raw address string when the user has spoken an address.
  /// The caller is responsible for geocoding; once done it must call either
  /// [confirmAddressAdded] or [rejectAddress].
  AddressRecognizedCallback? onAddressRecognized;

  /// Called when the user confirms they want to build the trip route.
  BuildRouteCallback? onBuildRoute;

  /// Called whenever [state] changes so the UI can rebuild.
  void Function(VoiceCommandState)? onStateChanged;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Transition to [VoiceCommandState.awaitingCommand] and greet the user.
  void startListening() {
    _targetStopCount = 0;
    _collectedStopCount = 0;
    _setState(VoiceCommandState.awaitingCommand);
    onSpeak?.call(
      'Listening. '
      'Say Kingtrux add followed by an address, '
      'or Kingtrux multiple stop.',
    );
  }

  /// Feed the next recognised utterance into the state machine.
  void process(String text) {
    final lower = text.toLowerCase().trim();
    switch (_state) {
      case VoiceCommandState.awaitingCommand:
        _handleCommand(lower, text.trim());
      case VoiceCommandState.awaitingStopCount:
        _handleStopCount(lower);
      case VoiceCommandState.awaitingStopAddress:
        _handleStopAddress(text.trim());
      case VoiceCommandState.awaitingConfirm:
        _handleConfirm(lower);
      case VoiceCommandState.idle:
        break;
    }
  }

  /// Called by the owner after a stop was successfully geocoded and added.
  ///
  /// Advances to [awaitingStopAddress] for the next stop (multiple-stop mode)
  /// or to [awaitingConfirm] when all stops are collected.
  void confirmAddressAdded(String label) {
    _collectedStopCount++;
    if (_targetStopCount > 0 && _collectedStopCount < _targetStopCount) {
      // More stops needed — stay in awaitingStopAddress.
      onSpeak?.call(
        'Stop $_collectedStopCount added. '
        'Speak address for stop ${_collectedStopCount + 1}.',
      );
    } else {
      _setState(VoiceCommandState.awaitingConfirm);
      final countMsg =
          _targetStopCount > 0 ? 'All $_targetStopCount stops' : 'Stop';
      onSpeak?.call('$countMsg added. Say build route to calculate your route.');
    }
  }

  /// Called by the owner when geocoding failed for the last spoken address.
  void rejectAddress() {
    onSpeak?.call('Could not find that address. Please try again.');
    // Stay in the current state so the user can speak again.
  }

  /// Reset to [VoiceCommandState.idle].
  void reset() {
    _targetStopCount = 0;
    _collectedStopCount = 0;
    _setState(VoiceCommandState.idle);
  }

  // ---------------------------------------------------------------------------
  // Private state-machine handlers
  // ---------------------------------------------------------------------------

  void _setState(VoiceCommandState s) {
    _state = s;
    onStateChanged?.call(s);
  }

  void _handleCommand(String lower, String original) {
    final address = parseAddCommand(lower);
    if (address != null) {
      // Preserve original capitalisation when passing to the geocoder.
      final prefixEnd =
          lower.indexOf('kingtrux add') + 'kingtrux add'.length;
      final originalAddress = original.substring(prefixEnd).trim();
      onAddressRecognized?.call(
        originalAddress.isNotEmpty ? originalAddress : address,
      );
    } else if (isMultipleStopCommand(lower)) {
      _setState(VoiceCommandState.awaitingStopCount);
      onSpeak?.call('How many stops?');
    } else {
      onSpeak?.call(
        'Command not recognised. '
        'Say Kingtrux add followed by an address, '
        'or Kingtrux multiple stop.',
      );
    }
  }

  void _handleStopCount(String lower) {
    final count = parseStopCount(lower);
    if (count != null && count > 0 && count <= 20) {
      _targetStopCount = count;
      _collectedStopCount = 0;
      _setState(VoiceCommandState.awaitingStopAddress);
      onSpeak?.call('Speak address for stop 1.');
    } else {
      onSpeak?.call('Please say a number between 1 and 20.');
    }
  }

  void _handleStopAddress(String address) {
    if (address.trim().isEmpty) {
      onSpeak?.call('Please speak an address.');
      return;
    }
    onAddressRecognized?.call(address.trim());
  }

  void _handleConfirm(String lower) {
    if (lower.contains('build') ||
        lower.contains('route') ||
        lower.contains('yes')) {
      onBuildRoute?.call();
      reset();
    } else if (lower.contains('cancel') || lower.contains('no')) {
      reset();
      onSpeak?.call('Voice commands cancelled.');
    } else if (lower.contains('add') || lower.contains('stop')) {
      _setState(VoiceCommandState.awaitingCommand);
      onSpeak?.call('Say Kingtrux add followed by an address.');
    } else {
      onSpeak?.call(
        'Say build route to calculate, add to add more stops, or cancel to exit.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Static parsing helpers — pure functions, no side-effects
  // ---------------------------------------------------------------------------

  /// Extracts the address from a "kingtrux add <address>" utterance.
  ///
  /// [text] is expected to be lower-cased.
  /// Returns the address (lower-cased) or `null` if the prefix is not found.
  static String? parseAddCommand(String text) {
    const prefix = 'kingtrux add';
    final idx = text.indexOf(prefix);
    if (idx == -1) return null;
    final address = text.substring(idx + prefix.length).trim();
    return address.isEmpty ? null : address;
  }

  /// Returns `true` when [text] (lower-cased) contains the multiple-stop trigger.
  static bool isMultipleStopCommand(String text) {
    return text.contains('kingtrux') &&
        text.contains('multiple') &&
        text.contains('stop');
  }

  /// Parses a stop count from spoken text.
  ///
  /// Accepts digit strings (`"3"`) and English word forms (`"three"`).
  /// Returns `null` when the text cannot be parsed as a positive integer.
  static int? parseStopCount(String text) {
    final lower = text.toLowerCase().trim();
    final asInt = int.tryParse(lower);
    if (asInt != null) return asInt;
    const wordMap = <String, int>{
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
    };
    return wordMap[lower];
  }
}
