import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// The splash, ported from design/prototype/splash.html. Everything is authored
/// in the prototype's 360x780 design space and the canvas is scaled once to fit
/// the phone — one transform, no responsive maths anywhere else.
///
/// Drop falls -> dimple -> the lump punches up -> five clay ripples, eleven
/// flung droplets, nine comic speed lines and a Ben-Day halo -> the ink leaves,
/// the water calms into the pool, the name arrives last.
class Splash extends StatefulWidget {
  const Splash({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<Splash> createState() => _SplashState();
}

const _totalMs = 2200.0; // the whole show, then hand over

/// The show is driven by a Ticker that accumulates *capped* frame deltas rather
/// than by wall clock. A debug build on Vulkan with validation layers can spend
/// 300ms on a single frame; a wall-clock animation then jumps straight to the
/// settled frame and the splash looks broken. Capping the step means a slow
/// phone plays the whole show a little slower instead of skipping it.
const _maxStepMs = 40.0;

/// Empty clay surface before the drop falls. Two hundred milliseconds is enough
/// for the engine to settle so the fall is always seen from the top.
const _leadMs = 220.0;

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _ms = 0;
  Duration _last = Duration.zero;
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final step = (elapsed - _last).inMicroseconds / 1000;
      _last = elapsed;
      setState(() => _ms += step.clamp(0, _maxStepMs));
      if (_ms >= _totalMs + _leadMs) _done();
    })
      ..start();
  }

  void _done() {
    if (_handedOver || !mounted) return;
    _handedOver = true;
    _ticker.stop();
    widget.onDone();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _done, // nobody should have to watch a splash twice
      child: ColoredBox(
        color: A.surface,
        child: SizedBox.expand(
          child: CustomPaint(painter: SplashArt(math.max(0, _ms - _leadMs))),
        ),
      ),
    );
  }
}

// ---- design space: the prototype's 360x780, impact at (180,470) ----
const _cx = 180.0, _cy = 470.0;
const _impact = 400.0;
const _settle = _impact + 520; // the water starts falling back in
const _space = Rect.fromLTWH(0, 0, 360, 780);

const _easeIn = Cubic(0.55, 0, 0.85, 0.35);
const _easeOut = Cubic(0.16, 0.9, 0.28, 1);
const _overshoot = Cubic(0.2, 1.7, 0.4, 1);

double _lerp(double a, double b, double t) => a + (b - a) * t;

Offset _polar(double r, double deg) {
  final a = deg * math.pi / 180;
  return Offset(_cx + r * math.cos(a), _cy + r * math.sin(a));
}

/// Clay ripple ridges. Tinted cyan and fading outward — an untinted ridge on a
/// light clay surface reads as an embossed plate, not as water.
class _Ring {
  const _Ring(this.d, this.w, this.tint, this.end);
  final double d, w;
  final Color tint;
  final double end;
}

const _ringSpec = [
  _Ring(176, 10, Color(0xFFA5E3F2), 1),
  _Ring(260, 8.5, Color(0xFFCDE9F4), 0.96),
  _Ring(356, 7, Color(0xFFDEEBF4), 0.88),
  _Ring(464, 5.5, Color(0xFFE5EEF5), 0.76),
  _Ring(584, 4.5, Color(0xFFE9EFF5), 0.6),
];

/// Speed lines: tapered triangles, not strokes — a comic speed line is thick at
/// the source and comes to a point. Nine, short, jittered so they never read as
/// clean spokes.
final _speedPaths = [
  for (var i = 0; i < 9; i++)
    () {
      final a = (i * 40 + ((i * 7) % 5) * 6).toDouble();
      final w = 3.4 + (i % 3) * 1.1;
      final tip = _polar((108 + ((i * 67) % 62)).toDouble(), a);
      final b = _polar(74, a + w * 0.5);
      final c = _polar(74, a - w * 0.5);
      return Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..close();
    }(),
];

/// The splash lump. Seen from directly above the water is a wobbling mass — it
/// is NOT allowed to radiate. Only one radial spike system may share the impact
/// centre and that job belongs to the ink; the thrown water is carried by the
/// flung droplets. Eight overlapping circles of one fill union into a lumpy
/// silhouette with no path maths and no seams.
final _body = [
  for (var i = 0; i < 8; i++)
    (
      _polar((9 + ((i * 5) % 4) * 4).toDouble(), (i * 45 + ((i * 5) % 4) * 9).toDouble()),
      (23 + ((i * 3) % 4) * 3).toDouble(),
    ),
];

/// The eight circles, unioned once. One path means the lump can fade as a single
/// shape without an offscreen layer, and without the seams that fading eight
/// overlapping circles would show.
final _lumpPath = _body.fold(Path(), (Path acc, b) {
  final circle = Path()..addOval(Rect.fromCircle(center: b.$1, radius: b.$2));
  return Path.combine(PathOperation.union, acc, circle);
});

/// Flung droplets. Clustered angles, uneven launch radii and three sizes —
/// evenly spaced same-size droplets read as a molecule diagram, not as water.
const List<double> _flingAngles = [-104, -68, -41, -8, 22, 57, 96, 134, 168, 206, 244];

/// Ben-Day halftone: the prototype tiles a 9px dot pattern over a circle and
/// fades it with a radial mask, so the dots keep one size and the *mask* does
/// the fading. Same here: one cached path, and the gradient shader below is
/// that mask.
final _dots = () {
  final p = Path();
  // The SVG pattern sits on a 9px lattice anchored at the viewBox origin, not
  // at the impact — offset by 2, exactly as the pattern's circle is.
  for (var y = 2.0; y < 780; y += 9) {
    if ((y - _cy).abs() > 200) continue;
    for (var x = 2.0; x < 360; x += 9) {
      final d = Offset(x - _cx, y - _cy);
      if (d.distance > 200) continue; // the annulus is a masked r=200 circle
      p.addOval(Rect.fromCircle(center: Offset(x, y), radius: 1.55));
    }
  }
  return p;
}();

/// The comic starburst: one jagged ink ring around the impact. Alternating
/// radii with a little jitter, or the points march round like a gear.
final _burst = () {
  const n = 15;
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final a = i * 180 / n - 90;
    final r = (i.isEven ? 128 + ((i * 37) % 26) : 88 - ((i * 17) % 14)).toDouble();
    final o = _polar(r, a);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}();

/// SDG 6's own mark, drawn in a unit box: a tumbler with a wavy waterline, a
/// droplet in the glass and an arrow falling out of the bottom. Four fills — the
/// glass and the arrow in white, the air above the water and the droplet punched
/// back out in the goal colour.
final _sdgGlass = Path()
  ..moveTo(0.04, 0.02)
  ..lineTo(0.96, 0.02)
  ..lineTo(0.83, 0.72)
  ..lineTo(0.17, 0.72)
  ..close();

final _sdgArrow = Path()
  ..moveTo(0.34, 0.70)
  ..lineTo(0.66, 0.70)
  ..lineTo(0.66, 0.80)
  ..lineTo(0.82, 0.80)
  ..lineTo(0.50, 1.0)
  ..lineTo(0.18, 0.80)
  ..lineTo(0.34, 0.80)
  ..close();

/// The air above the waterline: the glass is not full, and that wave is most of
/// what makes the mark recognisable.
final _sdgAir = Path()
  ..moveTo(0.045, 0.02)
  ..lineTo(0.955, 0.02)
  ..lineTo(0.935, 0.17)
  ..quadraticBezierTo(0.71, 0.24, 0.50, 0.175)
  ..quadraticBezierTo(0.28, 0.11, 0.065, 0.185)
  ..close();

final _sdgDrop = Path()
  ..moveTo(0.50, 0.24)
  ..cubicTo(0.68, 0.40, 0.70, 0.47, 0.70, 0.525)
  ..arcToPoint(const Offset(0.30, 0.525), radius: const Radius.circular(0.2))
  ..cubicTo(0.30, 0.47, 0.32, 0.40, 0.50, 0.24)
  ..close();

/// Paints the whole splash at [ms] milliseconds into the show. Every element
/// reads its own delay, so nothing can paint before its turn.
class SplashArt extends CustomPainter {
  SplashArt(this.ms);
  final double ms;

  /// Exposed for the geometry check in test/splash_test.dart.
  static List<(Offset, double)> get body => _body;
  static int get ringCount => _ringSpec.length;
  static int get speedCount => _speedPaths.length;
  static int get flingCount => _flingAngles.length;

  /// How far the lump reaches from the impact centre. It must not swallow the
  /// ripple it made, nor the roots of the speed lines.
  static double get reach =>
      _body.map((b) => (b.$1 - const Offset(_cx, _cy)).distance + b.$2).reduce(math.max);

  /// 0 before [delay], 1 once [dur] has run.
  double _p(double delay, double dur, [Curve c = Curves.linear]) =>
      c.transform(((ms - delay) / dur).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 360, size.height / 780);
    canvas.translate((size.width - 360 * s) / 2, (size.height - 780 * s) / 2);
    canvas.scale(s);
    canvas.clipRect(_space);
    _surfaceLight(canvas);
    _ripples(canvas);
    _halo(canvas);
    _starburst(canvas);
    _speedLines(canvas);
    _dimple(canvas);
    _corona(canvas);
    _pool(canvas);
    _flings(canvas);
    _fall(canvas);
    _wordmark(canvas);
    _goal(canvas);
  }

  /// Very faint top-left lighting across the whole surface.
  void _surfaceLight(Canvas canvas) => canvas.drawRect(
        _space,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.76, -0.88), // 12% across, 6% down
            colors: [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0)],
            stops: const [0, 0.55],
          ).createShader(_space),
      );

  /// Five raised clay ridges, staggered outward. One stroke each, shaded around
  /// its own circumference by a sweep gradient: white where the light hits it
  /// (up-left) and navy-tinted where it does not. The first cut of this used
  /// three strokes per ring with blur mask filters — ten blurred strokes a frame
  /// is what made the whole show skip on a real phone.
  void _ripples(Canvas canvas) {
    for (var i = 0; i < _ringSpec.length; i++) {
      final spec = _ringSpec[i];
      final e = _p(_impact + 10 + i * 95, 760, _easeOut);
      if (e <= 0) continue;
      final scale = e < 0.3 ? _lerp(0.18, 0.55, e / 0.3) : _lerp(0.55, 1, (e - 0.3) / 0.7);
      final op = e < 0.3 ? e / 0.3 : _lerp(1, spec.end, (e - 0.3) / 0.7);
      final r = spec.d / 2 * scale;
      final w = spec.w * scale;
      final ridge = Rect.fromCircle(center: const Offset(_cx, _cy), radius: r);
      final lit = Colors.white.withValues(alpha: op);
      final mid = Color.lerp(spec.tint, Colors.white, 0.45)!.withValues(alpha: op);
      final dark = Color.lerp(spec.tint, A.ink, 0.28)!.withValues(alpha: op * 0.9);
      canvas.drawCircle(
        const Offset(_cx, _cy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..shader = SweepGradient(
            // 0 rad points right; the light comes from up-left, so the bright
            // arc has to sit at 225 degrees.
            transform: const GradientRotation(-math.pi * 0.75),
            colors: [lit, mid, dark, dark, mid, lit],
            stops: const [0, 0.18, 0.42, 0.58, 0.82, 1],
          ).createShader(ridge),
      );
      // A hairline of pure light on the up-left shoulder, which is what makes
      // the ridge read as raised rather than painted on.
      canvas.drawArc(
        ridge.deflate(w * 0.34),
        math.pi * 0.9,
        math.pi * 0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.28
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: op * 0.75),
      );
    }
  }

  /// The comic ink layer is impact feedback only — in with the bang, gone before
  /// the water calms, or it turns into grubby texture lying on the clay.
  void _halo(Canvas canvas) {
    final op = _p(_impact + 60, 240) * 0.34 * (1 - _p(_impact + 330, 360));
    if (op <= 0) return;
    // The prototype's mask: transparent inside 0.16, solid at 0.32, gone by
    // 0.58 of a 330 radius. Alpha has to live in the colours — a shader makes
    // Paint.color inert.
    canvas.drawPath(
      _dots,
      Paint()
        ..shader = RadialGradient(
          colors: [
            A.ink.withValues(alpha: 0),
            A.ink.withValues(alpha: op),
            A.ink.withValues(alpha: 0),
          ],
          stops: const [0.16, 0.32, 0.58],
        ).createShader(Rect.fromCircle(center: const Offset(_cx, _cy), radius: 330)),
    );
  }

  /// The starburst the stills carry and the prototype only names in a comment:
  /// the ink's own radial system, drawn as an outline so it reads as drawn-on
  /// rather than as another solid form.
  void _starburst(Canvas canvas) {
    final draw = _p(_impact + 40, 260, _easeOut);
    final op = 0.9 * draw * (1 - _p(_impact + 330, 340));
    if (op <= 0) return;
    canvas.save();
    canvas.translate(_cx, _cy);
    canvas.scale(_lerp(0.34, 1, draw));
    canvas.translate(-_cx, -_cy);
    canvas.drawPath(
      _burst,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.miter
        ..color = A.ink.withValues(alpha: op),
    );
    canvas.restore();
  }

  void _speedLines(Canvas canvas) {
    for (var i = 0; i < _speedPaths.length; i++) {
      final draw = _p(_impact + 60 + (i % 5) * 18, 240, _easeOut);
      final op = 0.88 * draw * (1 - _p(_impact + 340 + i * 14, 300));
      if (op <= 0) continue;
      canvas.save();
      canvas.translate(_cx, _cy);
      canvas.scale(_lerp(0.2, 1, draw));
      canvas.translate(-_cx, -_cy);
      canvas.drawPath(_speedPaths[i], Paint()..color = A.ink.withValues(alpha: op));
      canvas.restore();
    }
  }

  /// The depression the drop punches, which never fully heals.
  void _dimple(Canvas canvas) {
    final a = _lerp(0.3 * _p(_impact - 10, 90), 0.16, _p(_settle, 520)) * 0.18;
    if (a <= 0) return;
    canvas.drawCircle(const Offset(_cx, _cy), 52, Paint()..color = A.accentDeep.withValues(alpha: a));
  }

  /// The lump punching up out of the dimple, then retracting into the pool.
  void _corona(Canvas canvas) {
    final rise = _p(_impact, 360, _overshoot);
    if (rise <= 0) return;
    final out = _p(_settle, 420, const Cubic(0.4, 0, 0.5, 1));
    final peak = rise < 0.5
        ? _lerp(0.28, 1.16, rise / 0.5)
        : _lerp(1.16, 1, ((rise - 0.5) / 0.5).clamp(0.0, 1.0));
    final op = (rise < 0.5 ? rise / 0.5 : 1.0) * (1 - out);
    if (op <= 0) return;
    canvas.save();
    canvas.translate(_cx, _cy);
    canvas.scale(_lerp(peak, 0.5, out));
    canvas.translate(-_cx, -_cy);
    // The eight circles are unioned into one path at startup, so the lump can
    // fade as a single shape. Fading the circles individually showed every seam;
    // a saveLayer hid them but cost a full-screen offscreen buffer every frame.
    canvas.drawPath(_lumpPath.shift(const Offset(2.5, 3.5)),
        Paint()..color = A.accentDeep.withValues(alpha: op)); // shadow side
    canvas.drawPath(_lumpPath, Paint()..color = A.accent.withValues(alpha: op));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(_cx - 13, _cy - 14), width: 30, height: 20),
      Paint()..color = const Color(0xFF8FDDF0).withValues(alpha: 0.55 * op),
    );
    canvas.restore();
  }

  /// The calm pool the corona hands off to — the one cyan form that stays.
  void _pool(Canvas canvas) {
    final op = _p(_settle + 120, 400);
    if (op <= 0) return;
    canvas.drawCircle(
        const Offset(_cx + 1.5, _cy + 2), 34, Paint()..color = A.accentDeep.withValues(alpha: op));
    canvas.drawCircle(const Offset(_cx, _cy), 32, Paint()..color = A.accent.withValues(alpha: op));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(_cx - 10, _cy - 11), width: 24, height: 16),
      Paint()..color = const Color(0xFF8FDDF0).withValues(alpha: 0.55 * op),
    );
  }

  /// Out and gone, staggered so they never move as a ring.
  void _flings(Canvas canvas) {
    for (var i = 0; i < _flingAngles.length; i++) {
      final a = _flingAngles[i];
      final p = _p(_impact + ((i * 23) % 70), (400 + ((i * 41) % 190)).toDouble(), _easeIn);
      if (p <= 0 || p >= 1) continue;
      final r0 = (52 + ((i * 17) % 13)).toDouble();
      final start = _polar(r0, a);
      final end = _polar(r0 + 16 + (i % 3) * 7, a);
      final flung = Offset.fromDirection(a * math.pi / 180, (104 + ((i * 29) % 58)) * p);
      final op = 1 - p;
      final scale = _lerp(1, 0.45, p);
      canvas.drawLine(
        start + flung,
        end + flung,
        Paint()
          ..strokeWidth = 2.4 * scale
          ..strokeCap = StrokeCap.round
          ..color = A.accent.withValues(alpha: 0.38 * op),
      );
      canvas.drawCircle(
        end + flung,
        (4.2 + ((i * 5) % 3) * 2.1) * scale,
        Paint()..color = A.accent.withValues(alpha: op),
      );
    }
  }

  /// The fall: accelerating, streak trailing, both dead on contact.
  void _fall(Canvas canvas) {
    final p = _p(0, _impact, _easeIn);
    final y = _lerp(-24, _cy, p);
    final streak = (p < 0.2 ? p / 0.2 : 1) * (1 - _p(_impact, 90));
    if (streak > 0) {
      canvas.drawLine(
        Offset(_cx, y - 96),
        Offset(_cx, y),
        Paint()
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [A.accent.withValues(alpha: 0), A.accent.withValues(alpha: 0.85 * streak)],
          ).createShader(Rect.fromLTWH(_cx - 2, y - 96, 4, 96)),
      );
    }
    final drop = 1 - _p(_impact - 20, 60);
    if (drop <= 0) return;
    canvas.save();
    canvas.translate(_cx, y);
    canvas.drawPath(
      Path()
        ..moveTo(0, -9)
        ..cubicTo(4.4, -3.4, 7, 0.2, 7, 3.3)
        ..arcToPoint(const Offset(-7, 3.3), radius: const Radius.circular(7))
        ..cubicTo(-7, 0.2, -4.4, -3.4, 0, -9)
        ..close(),
      Paint()..color = A.accent.withValues(alpha: drop),
    );
    canvas.restore();
  }

  /// The name arrives after the water, never before it.
  void _wordmark(Canvas canvas) {
    final p = _p(780, 420, _easeOut);
    if (p <= 0) return;
    final top = 74 + _lerp(-9, 0, p);
    final title = _text('AquaAlert', 44, FontWeight.w700, A.ink.withValues(alpha: p), -1.2);
    title.paint(canvas, Offset((360 - title.width) / 2, top));
    final tag = _text('Spot the Leak. Save the Water.', 14.5, FontWeight.w500,
        A.ink.withValues(alpha: 0.6 * p), 0.2);
    tag.paint(canvas, Offset((360 - tag.width) / 2, top + 44 + 11));
  }

  /// The goal this is built for, in the colour the goal is known by: one small
  /// soft pill down near the bottom padding. A full-size tile up here competes with
  /// the wordmark, and this is a credit line, not the logo of the app.
  void _goal(Canvas canvas) {
    final p = _p(1320, 480, _easeOut);
    if (p <= 0) return;
    final white = Colors.white.withValues(alpha: p);
    final label = _text('BASED ON', 8, FontWeight.w700, A.inkSoft.withValues(alpha: 0.85 * p), 1.6);
    label.paint(canvas, Offset((360 - label.width) / 2, 676));

    final six = _text('SDG 6', 12, FontWeight.w800, white, 0.2);
    final caps = _text('CLEAN WATER AND SANITATION', 8, FontWeight.w700, white, 0.4);
    const h = 28.0, pad = 11.0, icon = 19.0, gap = 7.0;
    final w = pad + icon * 0.72 + gap + six.width + gap + 1 + gap + caps.width + pad;
    final box = Rect.fromLTWH((360 - w) / 2, 694, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(9)),
      Paint()..color = A.accent.withValues(alpha: p),
    );
    var x = box.left + pad;
    _goalIcon(canvas, Offset(x + icon * 0.36, box.center.dy), icon, p);
    x += icon * 0.72 + gap;
    six.paint(canvas, Offset(x, box.center.dy - six.height / 2));
    x += six.width + gap;
    canvas.drawRect(
      Rect.fromLTWH(x, box.top + 8, 1, h - 16),
      Paint()..color = Colors.white.withValues(alpha: 0.45 * p),
    );
    x += 1 + gap;
    caps.paint(canvas, Offset(x, box.center.dy - caps.height / 2));
  }

  /// SDG 6's mark at [h] tall, white on the goal colour.
  void _goalIcon(Canvas canvas, Offset c, double h, double p) {
    final w = h * 0.72; // the mark is taller than it is wide
    canvas.save();
    canvas.translate(c.dx - w / 2, c.dy - h / 2);
    canvas.scale(w, h);
    final white = Paint()..color = Colors.white.withValues(alpha: p);
    final cut = Paint()..color = A.accent.withValues(alpha: p);
    canvas.drawPath(_sdgGlass, white);
    canvas.drawPath(_sdgArrow, white);
    canvas.drawPath(_sdgAir, cut);
    canvas.drawPath(_sdgDrop, cut);
    canvas.restore();
  }

  /// Laid out once and kept: the wordmark is the same three strings every frame,
  /// and TextPainter.layout with a google_fonts lookup is not free.
  static final Map<String, TextPainter> _cache = {};

  TextPainter _text(String s, double size, FontWeight w, Color c, double ls) =>
      _cache.putIfAbsent(
        '$s|$size|${c.toARGB32()}',
        () => TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontVariations: [FontVariation('wght', w.value.toDouble())],
              fontWeight: w,
              fontSize: size,
              color: c,
              letterSpacing: ls,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );

  @override
  bool shouldRepaint(SplashArt old) => old.ms != ms;
}
