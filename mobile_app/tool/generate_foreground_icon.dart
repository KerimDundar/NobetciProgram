// Generates a centered adaptive icon foreground from app_icon.png.
//
// The source image has the shield's visual center at ~48% horizontal / ~40%
// vertical. This script creates a square transparent-background canvas that
// is 25% larger than the source and places the source so that the shield
// lands exactly at the canvas center (50% / 50%).
//
// Run from the project root:
//   dart run tool/generate_foreground_icon.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  // Approximate position of shield's optical center in the source image.
  const shieldCx = 0.48; // 48% from left
  const shieldCy = 0.40; // 40% from top

  final sourceFile = File('assets/icons/app_icon.png');
  if (!sourceFile.existsSync()) {
    stderr.writeln('ERROR: assets/icons/app_icon.png not found.');
    stderr.writeln('Run this script from the Flutter project root.');
    exit(1);
  }

  final source = img.decodeImage(await sourceFile.readAsBytes());
  if (source == null) {
    stderr.writeln('ERROR: could not decode app_icon.png');
    exit(1);
  }

  final sw = source.width;
  final sh = source.height;
  stdout.writeln('Source: $sw×$sh');

  // Output canvas: square, 25% larger than the largest source dimension.
  // This guarantees enough room to shift the source without clipping content.
  final n = ((sw > sh ? sw : sh) * 1.25).ceil();
  stdout.writeln('Canvas: $n×$n');

  // Offset that places the shield center at 50% of the canvas.
  final xOff = (0.5 * n - shieldCx * sw).round();
  final yOff = (0.5 * n - shieldCy * sh).round();
  stdout.writeln(
    'Source offset: x=$xOff (${(xOff / n * 100).toStringAsFixed(1)}%), '
    'y=$yOff (${(yOff / n * 100).toStringAsFixed(1)}%)',
  );

  // Shield center verification
  final finalCx = (xOff + shieldCx * sw) / n * 100;
  final finalCy = (yOff + shieldCy * sh) / n * 100;
  stdout.writeln(
    'Shield center in canvas: '
    '${finalCx.toStringAsFixed(1)}% H / ${finalCy.toStringAsFixed(1)}% V',
  );

  // Create transparent canvas.
  final canvas = img.Image(width: n, height: n, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // Paste source onto canvas at computed offset (clips any overflow).
  img.compositeImage(canvas, source, dstX: xOff, dstY: yOff);

  final outputFile = File('assets/icons/app_icon_foreground.png');
  await outputFile.writeAsBytes(img.encodePng(canvas));
  stdout.writeln('Saved: ${outputFile.path}');
}
