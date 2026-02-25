import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/services/voice_command_service.dart';

void main() {
  // ── Static parsing helpers ─────────────────────────────────────────────────

  group('VoiceCommandService.parseAddCommand', () {
    test('extracts address after "kingtrux add"', () {
      expect(
        VoiceCommandService.parseAddCommand('kingtrux add 1600 pennsylvania avenue'),
        '1600 pennsylvania avenue',
      );
    });

    test('is case-insensitive (receives lower-cased input)', () {
      expect(
        VoiceCommandService.parseAddCommand(
            'kingtrux add new york city'.toLowerCase()),
        'new york city',
      );
    });

    test('returns null when prefix is absent', () {
      expect(
        VoiceCommandService.parseAddCommand('set destination chicago'),
        isNull,
      );
    });

    test('returns null when address part is empty', () {
      expect(VoiceCommandService.parseAddCommand('kingtrux add'), isNull);
    });

    test('handles extra whitespace', () {
      expect(
        VoiceCommandService.parseAddCommand('kingtrux add   dallas tx  '),
        'dallas tx',
      );
    });
  });

  group('VoiceCommandService.isMultipleStopCommand', () {
    test('matches canonical phrase', () {
      expect(
        VoiceCommandService.isMultipleStopCommand('kingtrux multiple stop'),
        isTrue,
      );
    });

    test('matches with extra words', () {
      expect(
        VoiceCommandService.isMultipleStopCommand(
            'ok kingtrux add multiple stop now'),
        isTrue,
      );
    });

    test('returns false without "kingtrux"', () {
      expect(
        VoiceCommandService.isMultipleStopCommand('multiple stop'),
        isFalse,
      );
    });

    test('returns false without "multiple"', () {
      expect(
        VoiceCommandService.isMultipleStopCommand('kingtrux add stop'),
        isFalse,
      );
    });
  });

  group('VoiceCommandService.parseStopCount', () {
    test('parses digit strings', () {
      expect(VoiceCommandService.parseStopCount('3'), 3);
      expect(VoiceCommandService.parseStopCount('10'), 10);
    });

    test('parses English word forms', () {
      expect(VoiceCommandService.parseStopCount('one'), 1);
      expect(VoiceCommandService.parseStopCount('two'), 2);
      expect(VoiceCommandService.parseStopCount('three'), 3);
      expect(VoiceCommandService.parseStopCount('four'), 4);
      expect(VoiceCommandService.parseStopCount('five'), 5);
      expect(VoiceCommandService.parseStopCount('six'), 6);
      expect(VoiceCommandService.parseStopCount('seven'), 7);
      expect(VoiceCommandService.parseStopCount('eight'), 8);
      expect(VoiceCommandService.parseStopCount('nine'), 9);
      expect(VoiceCommandService.parseStopCount('ten'), 10);
    });

    test('returns null for unrecognised input', () {
      expect(VoiceCommandService.parseStopCount('many'), isNull);
      expect(VoiceCommandService.parseStopCount(''), isNull);
    });
  });

  // ── State-machine transitions ──────────────────────────────────────────────

  group('VoiceCommandService state machine', () {
    late VoiceCommandService svc;
    final spoken = <String>[];
    final addresses = <String>[];
    int buildRouteCalls = 0;
    final states = <VoiceCommandState>[];

    setUp(() {
      svc = VoiceCommandService();
      spoken.clear();
      addresses.clear();
      buildRouteCalls = 0;
      states.clear();

      svc
        ..onSpeak = spoken.add
        ..onAddressRecognized = addresses.add
        ..onBuildRoute = () => buildRouteCalls++
        ..onStateChanged = states.add;
    });

    test('startListening transitions to awaitingCommand', () {
      svc.startListening();
      expect(svc.state, VoiceCommandState.awaitingCommand);
      expect(states, [VoiceCommandState.awaitingCommand]);
    });

    test('reset returns to idle', () {
      svc.startListening();
      svc.reset();
      expect(svc.state, VoiceCommandState.idle);
    });

    test('"kingtrux add <address>" calls onAddressRecognized', () {
      svc.startListening();
      svc.process('Kingtrux add 123 Main Street');
      expect(addresses, ['123 Main Street']);
      // State stays in awaitingCommand until confirmAddressAdded is called.
      expect(svc.state, VoiceCommandState.awaitingCommand);
    });

    test('"kingtrux multiple stop" transitions to awaitingStopCount', () {
      svc.startListening();
      svc.process('kingtrux multiple stop');
      expect(svc.state, VoiceCommandState.awaitingStopCount);
    });

    test('stop count transitions to awaitingStopAddress', () {
      svc.startListening();
      svc.process('kingtrux multiple stop');
      svc.process('3');
      expect(svc.state, VoiceCommandState.awaitingStopAddress);
    });

    test('stop count via word form transitions to awaitingStopAddress', () {
      svc.startListening();
      svc.process('kingtrux multiple stop');
      svc.process('two');
      expect(svc.state, VoiceCommandState.awaitingStopAddress);
    });

    test('address in awaitingStopAddress calls onAddressRecognized', () {
      svc.startListening();
      svc.process('kingtrux multiple stop');
      svc.process('2');
      svc.process('100 Broadway New York');
      expect(addresses, ['100 Broadway New York']);
    });

    test('confirmAddressAdded advances state after single stop', () {
      svc.startListening();
      svc.process('Kingtrux add 1 Infinite Loop');
      svc.confirmAddressAdded('1 Infinite Loop, Cupertino, CA');
      expect(svc.state, VoiceCommandState.awaitingConfirm);
    });

    test(
        'confirmAddressAdded stays in awaitingStopAddress when more stops needed',
        () {
      svc.startListening();
      svc.process('kingtrux multiple stop');
      svc.process('3');
      // First stop
      svc.process('Stop A');
      svc.confirmAddressAdded('Stop A');
      expect(svc.state, VoiceCommandState.awaitingStopAddress);
      // Second stop
      svc.process('Stop B');
      svc.confirmAddressAdded('Stop B');
      expect(svc.state, VoiceCommandState.awaitingStopAddress);
      // Third (last) stop → now confirm
      svc.process('Stop C');
      svc.confirmAddressAdded('Stop C');
      expect(svc.state, VoiceCommandState.awaitingConfirm);
    });

    test('"build route" in awaitingConfirm calls onBuildRoute and resets', () {
      svc.startListening();
      svc.process('Kingtrux add Somewhere');
      svc.confirmAddressAdded('Somewhere');
      svc.process('build route');
      expect(buildRouteCalls, 1);
      expect(svc.state, VoiceCommandState.idle);
    });

    test('"cancel" in awaitingConfirm resets to idle', () {
      svc.startListening();
      svc.process('Kingtrux add Somewhere');
      svc.confirmAddressAdded('Somewhere');
      svc.process('cancel');
      expect(svc.state, VoiceCommandState.idle);
      expect(buildRouteCalls, 0);
    });

    test('rejectAddress speaks error and keeps current state', () {
      svc.startListening();
      svc.process('Kingtrux add nowhere land');
      final stateBefore = svc.state;
      svc.rejectAddress();
      expect(svc.state, stateBefore);
      expect(spoken.any((s) => s.contains('Could not find')), isTrue);
    });

    test('unrecognised command in awaitingCommand speaks help', () {
      svc.startListening();
      spoken.clear();
      svc.process('go fast');
      expect(spoken.any((s) => s.contains('not recognised')), isTrue);
    });

    test('invalid stop count speaks prompt', () {
      svc.startListening();
      svc.process('kingtrux multiple stop');
      spoken.clear();
      svc.process('forty two');
      expect(spoken.any((s) => s.contains('1 and 20')), isTrue);
      expect(svc.state, VoiceCommandState.awaitingStopCount);
    });
  });
}
