import 'dart:ui' as ui;

import 'package:aquaalert/screens/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The prototype's own self-checks, carried over. These are the constraints the
/// splash art was designed around — break one and the impact stops reading as
/// water: the lump either swallows the ripple it made or buries the roots of the
/// speed lines, and the three spike systems fuse into a sun.
void main() {
  test('the splash lump stays inside the art it made', () {
    expect(SplashArt.body.length, 8);
    expect(SplashArt.reach, lessThan(176 / 2)); // the first ripple
    expect(SplashArt.reach, lessThan(74)); // the base of the speed lines
    // and it has to be a lump, not a ring: something must cover the centre
    expect(
      SplashArt.body.any((b) => (b.$1 - const Offset(180, 470)).distance < b.$2),
      isTrue,
      reason: 'lump has a hole at the centre',
    );
  });

  test('the counts the choreography was authored for', () {
    expect(SplashArt.ringCount, 5);
    expect(SplashArt.speedCount, 9);
    expect(SplashArt.flingCount, 11);
  });

  // testWidgets, not test: the wordmark asks google_fonts for Outfit, which
  // needs a binding even though nothing is pumped here.
  testWidgets('every frame of the show paints', (tester) async {
    // Each element scales, fades and clips on its own clock; the degenerate
    // frames are at the ends and at each hand-off, so walk the whole timeline.
    for (var ms = 0.0; ms <= 2200; ms += 25) {
      final recorder = ui.PictureRecorder();
      SplashArt(ms).paint(Canvas(recorder), const Size(1080, 2400));
      recorder.endRecording();
    }
  });
}
