import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/compass_indicator.dart';

void main() {
  group('CompassIndicator.headingToCardinal', () {
    test('0° maps to N', () {
      expect(CompassIndicator.headingToCardinal(0), 'N');
    });

    test('360° maps to N', () {
      expect(CompassIndicator.headingToCardinal(360), 'N');
    });

    test('45° maps to NE', () {
      expect(CompassIndicator.headingToCardinal(45), 'NE');
    });

    test('90° maps to E', () {
      expect(CompassIndicator.headingToCardinal(90), 'E');
    });

    test('135° maps to SE', () {
      expect(CompassIndicator.headingToCardinal(135), 'SE');
    });

    test('180° maps to S', () {
      expect(CompassIndicator.headingToCardinal(180), 'S');
    });

    test('225° maps to SW', () {
      expect(CompassIndicator.headingToCardinal(225), 'SW');
    });

    test('270° maps to W', () {
      expect(CompassIndicator.headingToCardinal(270), 'W');
    });

    test('315° maps to NW', () {
      expect(CompassIndicator.headingToCardinal(315), 'NW');
    });

    test('22° maps to N (within N sector)', () {
      expect(CompassIndicator.headingToCardinal(22), 'N');
    });

    test('23° maps to NE (just into NE sector)', () {
      expect(CompassIndicator.headingToCardinal(23), 'NE');
    });

    test('337° maps to NW (within NW sector)', () {
      expect(CompassIndicator.headingToCardinal(337), 'NW');
    });

    test('338° maps to N (just into N sector)', () {
      expect(CompassIndicator.headingToCardinal(338), 'N');
    });
  });

  group('AppState currentHeading', () {
    test('currentHeading defaults to null', () {
      final state = AppState();
      expect(state.currentHeading, isNull);
      state.dispose();
    });
  });
}
