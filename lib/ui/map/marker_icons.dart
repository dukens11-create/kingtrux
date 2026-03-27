import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Generates a rounded-rectangle map marker with a [bgColor] fill, a white
/// outer border, a secondary white inner border (double-border effect), and
/// a centered [letter] in white bold text.
///
/// This produces a sign-style marker (e.g. the DOT weigh-station "W" sign).
/// The result is cached like [buildCircleLetterMarker].
///
/// Falls back to `null` on any error so callers can substitute a default icon.
Future<BitmapDescriptor?> buildRoundedRectLetterMarker({
  required Color bgColor,
  required String letter,
  double width = 60.0,
  double height = 48.0,
  double fontSize = 26.0,
}) async {
  final key = 'rr_${bgColor.value}_${letter}_${width}_${height}_$fontSize';
  if (_cache.containsKey(key)) return _cache[key];

  try {
    const pixelRatio = 2.0;
    final pw = width * pixelRatio;
    final ph = height * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final outerBorder = (height * 0.06 * pixelRatio).clamp(3.0, 6.0);
    final innerBorder = (height * 0.04 * pixelRatio).clamp(2.0, 4.0);
    final cornerRadius = height * 0.18 * pixelRatio;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, pw, ph),
      Radius.circular(cornerRadius),
    );

    // Background fill.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = bgColor
        ..isAntiAlias = true,
    );

    // Outer white border.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerBorder
        ..isAntiAlias = true,
    );

    // Inner white border (double-border effect).
    final innerInset = outerBorder + innerBorder + outerBorder * 0.6;
    final innerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(innerInset, innerInset, pw - innerInset * 2, ph - innerInset * 2),
      Radius.circular((cornerRadius - innerInset).clamp(2.0, cornerRadius)),
    );
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerBorder
        ..isAntiAlias = true,
    );

    // Centered letter.
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize * pixelRatio,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (pw - textPainter.width) / 2,
        (ph - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(pw.toInt(), ph.toInt());
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

/// Generates a circular map marker that displays the PNG asset at [assetPath]
/// centered inside a white circular background.
///
/// [size] is the diameter in logical pixels of the resulting marker (default
/// 48 dp).  The result is cached like [buildCircleLetterMarker] and falls back
/// to `null` on any error so callers can substitute a default icon.
Future<BitmapDescriptor?> buildBrandLogoMarker(
  String assetPath, {
  double size = 48.0,
}) async {
  final key = 'brand_logo_${assetPath}_$size';
  if (_cache.containsKey(key)) return _cache[key];

  try {
    const pixelRatio = 2.0;
    final physicalSize = size * pixelRatio;
    final radius = physicalSize / 2;

    // Load the asset bytes.
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: (physicalSize - 8).toInt(),
      targetHeight: (physicalSize - 8).toInt(),
    );
    final frame = await codec.getNextFrame();
    final logoImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White circular background.
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()
        ..color = Colors.white
        ..isAntiAlias = true,
    );

    // Clip subsequent drawing to the circle.
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: Offset(radius, radius), radius: radius - 1),
        ),
    );

    // Draw the logo, centered, with a small inset so it fits inside the circle.
    const inset = 4.0;
    canvas.drawImageRect(
      logoImage,
      Rect.fromLTWH(
        0,
        0,
        logoImage.width.toDouble(),
        logoImage.height.toDouble(),
      ),
      Rect.fromLTWH(inset, inset, physicalSize - inset * 2, physicalSize - inset * 2),
      Paint()..isAntiAlias = true,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(physicalSize.toInt(), physicalSize.toInt());
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
