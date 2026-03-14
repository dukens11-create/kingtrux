import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Cache of previously generated [BitmapDescriptor] instances keyed by a
/// descriptive string so they are only created once per app run.
final Map<String, BitmapDescriptor> _cache = {};

/// Generates a circular map marker filled with [color] and showing [letter]
/// (centered, white) at the given logical pixel [size].
///
/// The result is cached: subsequent calls with identical parameters return the
/// same [BitmapDescriptor] without re-rendering.
///
/// Falls back to `null` on any error so callers can substitute a default icon.
Future<BitmapDescriptor?> buildCircleLetterMarker({
  required Color color,
  required String letter,
  double size = 48.0,
  double fontSize = 24.0,
}) async {
  final key = '${color.value}_${letter}_${size}_$fontSize';
  if (_cache.containsKey(key)) return _cache[key];

  try {
    // Honour the device pixel ratio so the marker is crisp on high-DPI screens.
    // PictureRecorder works in logical pixels; we scale the canvas instead.
    const pixelRatio = 2.0; // 2× is sufficient for all common densities.
    final physicalSize = size * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    final radius = physicalSize / 2;
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize * pixelRatio,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (physicalSize - textPainter.width) / 2,
        (physicalSize - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(physicalSize.toInt(), physicalSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) return null;

    final descriptor = BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );

    _cache[key] = descriptor;
    return descriptor;
  } catch (_) {
    return null;
  }
}

/// Clears the marker icon cache. Useful in tests.
void clearMarkerIconCache() => _cache.clear();
