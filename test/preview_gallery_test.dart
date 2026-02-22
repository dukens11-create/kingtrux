import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/ui/preview_gallery_page.dart';

void main() {
  group('PreviewGalleryPage Tests', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildPreviewGalleryApp());

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('UI Preview Gallery'), findsOneWidget);
    });

    testWidgets('shows section headers', (WidgetTester tester) async {
      await tester.pumpWidget(buildPreviewGalleryApp());

      // skipOffstage: false because ListView may scroll some items offscreen
      expect(find.text('Map Screen Shell'), findsOneWidget);
      expect(
        find.text('Buttons & FAB Cluster', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('theme toggle switches between light and dark',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPreviewGalleryApp());

      // Initially light – dark_mode icon visible
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsNothing);

      // Tap the toggle
      await tester.tap(find.byIcon(Icons.dark_mode));
      await tester.pump();

      // Now dark – light_mode icon visible
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsNothing);

      // Toggle back
      await tester.tap(find.byIcon(Icons.light_mode));
      await tester.pump();

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('map shell placeholder is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPreviewGalleryApp());

      expect(find.text('Map Placeholder\n(Google Maps not shown in preview)'),
          findsOneWidget);
    });

    testWidgets('route card empty-state text is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPreviewGalleryApp());

      // Text appears in both RouteSummaryCard and _EmptyPreview; at least one
      // instance must be present (some may be offstage in the scroll view).
      expect(
        find.text(
          'Long-press on map to set destination and calculate route',
          skipOffstage: false,
        ),
        findsWidgets,
      );
    });
  });
}
