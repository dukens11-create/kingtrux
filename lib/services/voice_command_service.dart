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
///   ..language = 'en-US'
///   ..onSpeak = (text) => tts.speak(text)
///   ..onAddressRecognized = (addr) async { /* geocode, then call confirmAddressAdded */ }
///   ..onBuildRoute = () => appState.buildTripRoute()
///   ..onLanguageChanged = (lang) => appState.setVoiceLanguage(lang);
///
/// service.startListening(); // transitions to awaitingCommand
/// service.process(recognizedWords);
/// ```
class VoiceCommandService {
  VoiceCommandState _state = VoiceCommandState.idle;

  /// Current state of the voice-command flow.
  VoiceCommandState get state => _state;

  /// BCP-47 language tag used for localized prompts and command parsing.
  /// Defaults to 'en-US'. Can be changed at any time; takes effect on the
  /// next prompt or command evaluation.
  String language = 'en-US';

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

  /// Called when the user changes the guidance language via voice command
  /// (e.g. "Kingtrux use Hindi"). The new BCP-47 tag is passed as argument.
  void Function(String language)? onLanguageChanged;

  // ---------------------------------------------------------------------------
  // Localized string tables
  // ---------------------------------------------------------------------------

  /// Static strings keyed by BCP-47 language tag then string key.
  /// Falls back to 'en-US' for any missing entry.
  static const Map<String, Map<String, String>> _localizedStrings = {
    'en-US': {
      'listening':
          'Listening. Say Kingtrux add followed by an address, or Kingtrux multiple stop.',
      'howManyStops': 'How many stops?',
      'numberRange': 'Please say a number between 1 and 20.',
      'pleaseSpeak': 'Please speak an address.',
      'commandNotRecognised':
          'Command not recognised. Say Kingtrux add followed by an address, or Kingtrux multiple stop.',
      'cancelled': 'Voice commands cancelled.',
      'sayAdd': 'Say Kingtrux add followed by an address.',
      'confirmHelp':
          'Say build route to calculate, add to add more stops, or cancel to exit.',
      'addressNotFound': 'Could not find that address. Please try again.',
      'languageChanged': 'Language changed to English.',
      'singleStopAdded': 'Stop added. Say build route to calculate your route.',
    },
    'hi-IN': {
      'listening':
          'सुन रहा हूँ। किंगट्रक्स जोड़ें कहकर पता बोलें, या किंगट्रक्स मल्टीपल स्टॉप।',
      'howManyStops': 'कितने स्टॉप?',
      'numberRange': 'कृपया 1 से 20 के बीच की संख्या बोलें।',
      'pleaseSpeak': 'कृपया पता बोलें।',
      'commandNotRecognised':
          'कमांड नहीं पहचाना। किंगट्रक्स जोड़ें कहकर पता बोलें, या किंगट्रक्स मल्टीपल स्टॉप।',
      'cancelled': 'वॉयस कमांड रद्द।',
      'sayAdd': 'किंगट्रक्स जोड़ें कहकर पता बोलें।',
      'confirmHelp': 'मार्ग बनाएं, जोड़ें, या रद्द करें बोलें।',
      'addressNotFound': 'यह पता नहीं मिला। कृपया फिर से प्रयास करें।',
      'languageChanged': 'भाषा हिंदी में बदली।',
      'singleStopAdded': 'स्टॉप जोड़ा गया। मार्ग बनाएं बोलें।',
    },
    'ht-HT': {
      'listening':
          'Mwen koute. Di Kingtrux ajoute adres, oswa Kingtrux plizyè stop.',
      'howManyStops': 'Konbyen stop?',
      'numberRange': 'Tanpri di yon nimewo ant 1 ak 20.',
      'pleaseSpeak': 'Tanpri di yon adres.',
      'commandNotRecognised':
          'Kòmand pa rekonèt. Di Kingtrux ajoute adres, oswa Kingtrux plizyè stop.',
      'cancelled': 'Kòmand vwa anile.',
      'sayAdd': 'Di Kingtrux ajoute adres.',
      'confirmHelp': 'Di bati wout, ajoute, oswa anile.',
      'addressNotFound': 'Pa ka jwenn adres sa. Tanpri eseye ankò.',
      'languageChanged': 'Lang chanje an Kreyòl Ayisyen.',
      'singleStopAdded': 'Stop ajoute. Di bati wout pou kalkile wout ou.',
    },
    'zh-CN': {
      'listening': '正在聆听。说"金卡车添加"加地址，或"金卡车多站点"。',
      'howManyStops': '需要几个站点？',
      'numberRange': '请说 1 到 20 之间的数字。',
      'pleaseSpeak': '请说一个地址。',
      'commandNotRecognised': '未识别命令。说"金卡车添加"加地址，或"金卡车多站点"。',
      'cancelled': '语音命令已取消。',
      'sayAdd': '请说"金卡车添加"加地址。',
      'confirmHelp': '说"规划路线"、"添加"或"取消"。',
      'addressNotFound': '找不到该地址，请重试。',
      'languageChanged': '语言已更改为中文。',
      'singleStopAdded': '站点已添加。说"规划路线"以计算路线。',
    },
  };

  /// Language-specific prefixes for the "add address" command.
  /// Each entry lists all accepted lowercase/native-script prefixes.
  static const Map<String, List<String>> _addCommandPrefixes = {
    'en-US': ['kingtrux add'],
    'en-CA': ['kingtrux add'],
    'es-US': ['kingtrux add', 'kingtrux agrega', 'kingtrux agregar'],
    'fr-CA': ['kingtrux add', 'kingtrux ajoute', 'kingtrux ajouter'],
    'hi-IN': ['kingtrux add', 'किंगट्रक्स जोड़ें', 'किंगट्रक्स जोड़'],
    'ht-HT': ['kingtrux add', 'kingtrux ajoute', 'kingtrux ajouter'],
    'zh-CN': ['kingtrux add', '金卡车添加'],
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Transition to [VoiceCommandState.awaitingCommand] and greet the user.
  void startListening() {
    _targetStopCount = 0;
    _collectedStopCount = 0;
    _setState(VoiceCommandState.awaitingCommand);
    onSpeak?.call(_str('listening'));
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
        _strStopAdded(_collectedStopCount, _collectedStopCount + 1),
      );
    } else {
      _setState(VoiceCommandState.awaitingConfirm);
      if (_targetStopCount > 0) {
        onSpeak?.call(_strAllStopsAdded(_targetStopCount));
      } else {
        onSpeak?.call(_str('singleStopAdded'));
      }
    }
  }

  /// Called by the owner when geocoding failed for the last spoken address.
  void rejectAddress() {
    onSpeak?.call(_str('addressNotFound'));
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
    // Language-change takes priority over all other commands.
    final newLang = parseLanguageCommand(lower);
    if (newLang != null) {
      language = newLang;
      onLanguageChanged?.call(newLang);
      onSpeak?.call(_str('languageChanged'));
      return;
    }

    final address = parseAddCommand(lower, language: language);
    if (address != null) {
      // Preserve original capitalisation when passing to the geocoder.
      final originalAddress = _extractOriginalAddress(lower, original);
      onAddressRecognized?.call(
        originalAddress.isNotEmpty ? originalAddress : address,
      );
    } else if (isMultipleStopCommand(lower, language: language)) {
      _setState(VoiceCommandState.awaitingStopCount);
      onSpeak?.call(_str('howManyStops'));
    } else {
      onSpeak?.call(_str('commandNotRecognised'));
    }
  }

  void _handleStopCount(String lower) {
    final count = parseStopCount(lower, language: language);
    if (count != null && count > 0 && count <= 20) {
      _targetStopCount = count;
      _collectedStopCount = 0;
      _setState(VoiceCommandState.awaitingStopAddress);
      onSpeak?.call(_strSpeakAddressForStop(1));
    } else {
      onSpeak?.call(_str('numberRange'));
    }
  }

  void _handleStopAddress(String address) {
    if (address.trim().isEmpty) {
      onSpeak?.call(_str('pleaseSpeak'));
      return;
    }
    onAddressRecognized?.call(address.trim());
  }

  void _handleConfirm(String lower) {
    if (_isBuildCommand(lower)) {
      onBuildRoute?.call();
      reset();
    } else if (_isCancelCommand(lower)) {
      reset();
      onSpeak?.call(_str('cancelled'));
    } else if (_isAddMoreCommand(lower)) {
      _setState(VoiceCommandState.awaitingCommand);
      onSpeak?.call(_str('sayAdd'));
    } else {
      onSpeak?.call(_str('confirmHelp'));
    }
  }

  bool _isBuildCommand(String lower) {
    if (lower.contains('build') ||
        lower.contains('route') ||
        lower.contains('yes')) return true;
    switch (language) {
      case 'hi-IN':
        return lower.contains('मार्ग') ||
            lower.contains('बनाएं') ||
            lower.contains('हाँ');
      case 'ht-HT':
        return lower.contains('bati') ||
            lower.contains('wout') ||
            lower.contains('wi');
      case 'zh-CN':
        return lower.contains('规划') ||
            lower.contains('路线') ||
            lower.contains('是');
      default:
        return false;
    }
  }

  bool _isCancelCommand(String lower) {
    if (lower.contains('cancel') || lower.contains('no')) return true;
    switch (language) {
      case 'hi-IN':
        return lower.contains('रद्द') || lower.contains('नहीं');
      case 'ht-HT':
        return lower.contains('anile') || lower.contains('non');
      case 'zh-CN':
        return lower.contains('取消') || lower.contains('不');
      default:
        return false;
    }
  }

  bool _isAddMoreCommand(String lower) {
    if (lower.contains('add') || lower.contains('stop')) return true;
    switch (language) {
      case 'hi-IN':
        return lower.contains('जोड़') || lower.contains('स्टॉप');
      case 'ht-HT':
        return lower.contains('ajoute') || lower.contains('arè');
      case 'zh-CN':
        return lower.contains('添加') || lower.contains('站点');
      default:
        return false;
    }
  }

  /// Returns the portion of [original] that follows the first matching
  /// add-command prefix found in [lower].
  String _extractOriginalAddress(String lower, String original) {
    final prefixes =
        _addCommandPrefixes[language] ?? _addCommandPrefixes['en-US']!;
    for (final prefix in prefixes) {
      final idx = lower.indexOf(prefix);
      if (idx != -1) {
        return original.substring(idx + prefix.length).trim();
      }
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // Localized dynamic string helpers
  // ---------------------------------------------------------------------------

  /// Returns the localized string for [key], falling back to English.
  String _str(String key) {
    return (_localizedStrings[language] ?? _localizedStrings['en-US']!)[key] ??
        _localizedStrings['en-US']![key]!;
  }

  /// "Stop [collected] added. Speak address for stop [next]."
  String _strStopAdded(int collected, int next) {
    switch (language) {
      case 'hi-IN':
        return 'स्टॉप $collected जोड़ा गया। स्टॉप $next का पता बोलें।';
      case 'ht-HT':
        return 'Stop $collected ajoute. Di adres pou stop $next.';
      case 'zh-CN':
        return '第 $collected 站已添加。请说第 $next 站的地址。';
      default:
        return 'Stop $collected added. Speak address for stop $next.';
    }
  }

  /// "All [total] stops added. Say build route …"
  String _strAllStopsAdded(int total) {
    switch (language) {
      case 'hi-IN':
        return 'सभी $total स्टॉप जोड़े गए। मार्ग बनाएं बोलें।';
      case 'ht-HT':
        return 'Tout $total stop ajoute. Di bati wout pou kalkile wout ou.';
      case 'zh-CN':
        return '全部 $total 站已添加。说"规划路线"以计算路线。';
      default:
        return 'All $total stops added. Say build route to calculate your route.';
    }
  }

  /// "Speak address for stop [n]."
  String _strSpeakAddressForStop(int n) {
    switch (language) {
      case 'hi-IN':
        return 'स्टॉप $n का पता बोलें।';
      case 'ht-HT':
        return 'Di adres pou stop $n.';
      case 'zh-CN':
        return '请说第 $n 站的地址。';
      default:
        return 'Speak address for stop $n.';
    }
  }

  // ---------------------------------------------------------------------------
  // Static parsing helpers — pure functions, no side-effects
  // ---------------------------------------------------------------------------

  /// Extracts the address from a "kingtrux add <address>" utterance.
  ///
  /// [text] is expected to be lower-cased (ASCII) or native-script normalized.
  /// [language] selects the set of accepted command prefixes.
  /// Returns the address or `null` if no known prefix is found.
  static String? parseAddCommand(String text, {String language = 'en-US'}) {
    final prefixes =
        _addCommandPrefixes[language] ?? _addCommandPrefixes['en-US']!;
    // Also always try the English fallback prefix so mixed-language inputs work.
    final allPrefixes = {
      ...prefixes,
      if (language != 'en-US') ..._addCommandPrefixes['en-US']!,
    };
    for (final prefix in allPrefixes) {
      final idx = text.indexOf(prefix);
      if (idx != -1) {
        final address = text.substring(idx + prefix.length).trim();
        if (address.isNotEmpty) return address;
      }
    }
    return null;
  }

  /// Returns `true` when [text] (lower-cased / normalized) contains the
  /// multiple-stop trigger phrase for the given [language].
  static bool isMultipleStopCommand(String text, {String language = 'en-US'}) {
    switch (language) {
      case 'hi-IN':
        return (text.contains('kingtrux') ||
                text.contains('किंगट्रक्स')) &&
            (text.contains('multiple') ||
                text.contains('मल्टीपल') ||
                text.contains('एकाधिक')) &&
            (text.contains('stop') || text.contains('स्टॉप'));
      case 'ht-HT':
        return text.contains('kingtrux') &&
            (text.contains('plizyè') || text.contains('multiple')) &&
            (text.contains('stop') || text.contains('arè'));
      case 'zh-CN':
        return (text.contains('金卡车') || text.contains('kingtrux')) &&
            (text.contains('多') || text.contains('multiple')) &&
            (text.contains('站点') ||
                text.contains('停靠') ||
                text.contains('stop'));
      default:
        return text.contains('kingtrux') &&
            text.contains('multiple') &&
            text.contains('stop');
    }
  }

  /// Parses a stop count from spoken text.
  ///
  /// Accepts digit strings (`"3"`), English word forms (`"three"`), and
  /// localized number words for the given [language].
  /// Returns `null` when the text cannot be parsed as a positive integer.
  static int? parseStopCount(String text, {String language = 'en-US'}) {
    final lower = text.toLowerCase().trim();
    final asInt = int.tryParse(lower);
    if (asInt != null) return asInt;
    // English word forms (universal fallback).
    const enWordMap = <String, int>{
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
    if (enWordMap.containsKey(lower)) return enWordMap[lower];
    // Language-specific number words.
    switch (language) {
      case 'hi-IN':
        const hiWordMap = <String, int>{
          'एक': 1,
          'दो': 2,
          'तीन': 3,
          'चार': 4,
          'पाँच': 5,
          'छह': 6,
          'सात': 7,
          'आठ': 8,
          'नौ': 9,
          'दस': 10,
        };
        return hiWordMap[text.trim()];
      case 'ht-HT':
        const htWordMap = <String, int>{
          'en': 1,
          'de': 2,
          'twa': 3,
          'kat': 4,
          'senk': 5,
          'sis': 6,
          'sèt': 7,
          'uit': 8,
          'nèf': 9,
          'dis': 10,
        };
        return htWordMap[lower];
      case 'zh-CN':
        const zhWordMap = <String, int>{
          '一': 1,
          '二': 2,
          '两': 2,
          '三': 3,
          '四': 4,
          '五': 5,
          '六': 6,
          '七': 7,
          '八': 8,
          '九': 9,
          '十': 10,
        };
        return zhWordMap[text.trim()];
      default:
        return null;
    }
  }

  /// Detects a language-change voice command such as "Kingtrux use Hindi".
  ///
  /// [text] must be lower-cased. Returns the new BCP-47 language tag, or
  /// `null` if the text is not a language-change command.
  static String? parseLanguageCommand(String text) {
    if (!text.contains('kingtrux')) return null;
    if (text.contains('hindi') || text.contains('हिंदी')) return 'hi-IN';
    if (text.contains('haitian') ||
        text.contains('creole') ||
        text.contains('kreyol') ||
        text.contains('kreyòl')) return 'ht-HT';
    if (text.contains('chinese') ||
        text.contains('mandarin') ||
        text.contains('中文') ||
        text.contains('普通话')) return 'zh-CN';
    if (text.contains('english')) return 'en-US';
    if (text.contains('spanish') || text.contains('español')) return 'es-US';
    if (text.contains('french') || text.contains('français')) return 'fr-CA';
    return null;
  }
}
