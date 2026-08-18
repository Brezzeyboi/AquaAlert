import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/store.dart';
import '../theme.dart';
import 'clay.dart';

/// The water tank: the ONE skeuomorphic object in the app. Everything else is
/// clay, so this is allowed real glass, real depth and real moving water.
///
/// The water is simulated, not drawn. [WaterSurface] is a row of columns, each
/// with a height and a velocity, pulled towards the level gravity says the
/// surface should sit at and coupled to its neighbours. That is what lets it pile
/// against a wall, overshoot, rock back and cross the glass — three stacked sine
/// waves can only ever ripple in place, which is why the old one read as a
/// pattern rather than as a liquid.
///
/// The glass never moves. A tilting tank reads as a broken layout; a tilting
/// surface reads as water.
class WaterTank extends StatefulWidget {
  const WaterTank({
    super.key,
    required this.fill,
    this.tilt,
    this.height = 208,
    this.caption,
    this.goal = true,
  });

  /// 0..1 of the way to the goal line.
  final double fill;

  /// -1..1, left/right. Null means read the phone's own sensors, which is what
  /// the tank does on the dashboard; pass a number to drive it by hand.
  final double? tilt;

  final double height;
  final String? caption;

  /// Draw the goal line the mockup marks near the top of the glass.
  final bool goal;

  @override
  State<WaterTank> createState() => _WaterTankState();
}

/// Where the goal sits inside the glass. Not the brim: a tank filled to the very
/// top has nowhere left to go, and the mockup leaves air above the line.
const _goalAt = 0.86;

/// The free surface of the water, as physics rather than as a drawing: one row of
/// columns, each holding how far it sits above the resting level and how fast it
/// is moving. Deliberately its own object with no Flutter in it, so the behaviour
/// can be shaken in a test and watched without a screen.
class WaterSurface {
  WaterSurface({this.cols = 44})
      : h = List<double>.filled(cols, 0),
        v = List<double>.filled(cols, 0);

  /// About two pixels per column across a phone-sized glass — fine enough to draw
  /// straight lines between them and cheap enough to step every frame.
  final int cols;

  /// Height above the resting level, in pixels, and its rate of change.
  final List<double> h, v;

  /// How stirred up the water is, 0..1. Decays on its own; the bubbles ride it.
  double energy = 0;

  /// How hard each column is pulled back to where gravity wants it. Sets the
  /// rocking period — about eight tenths of a second, which is water rather than
  /// jelly. Much higher and it chatters like a shaken bottle.
  static const stiffness = 60.0;

  /// How fast the rocking dies away. This one is a feel knob: too much and a tilt
  /// slides into place with no life at all, too little and it keeps twitching long
  /// after your hand stopped. Two visible swings is about right.
  static const drag = 1.7;

  /// How strongly a column pulls on its neighbours: the speed a ripple crosses the
  /// glass. This is the whole difference between a wave that travels and a column
  /// bobbing where it started — but it also decides how nervous the surface looks,
  /// so it stays modest.
  static const spread = 330.0;

  /// Pixels the surface rises at the wall when the phone is fully on its side. 34
  /// is a 68px swing from wall to wall in a glass about 150px tall: unmistakable
  /// when you tip the phone, and nowhere near the brim.
  static const lean = 34.0;

  /// The ceiling, whatever the phone does. An aggressive shake puts energy in
  /// faster than the drag takes it out, and without a limit the surface climbs the
  /// walls and the whole card looks rattled. This is what lets the gain above be
  /// generous: responsive to a tilt, still bounded when thrown about.
  static const maxRise = lean * 1.4;
  static const maxSpeed = 110.0;

  /// The plane a still surface would take at this tilt: level with gravity,
  /// pivoting about the middle, so the volume in the glass never changes.
  double _plane(int i, double tilt) => (i / (cols - 1) - 0.5) * tilt * lean;

  /// Steps the surface forward. Substepped at a fixed size, so it behaves the
  /// same on a 120Hz phone and on a frame that took 30ms.
  void step(double dt, double tilt) {
    var left = math.min(dt, 1 / 20);
    while (left > 0) {
      final s = math.min(1 / 240, left);
      left -= s;
      for (var i = 0; i < cols; i++) {
        v[i] += (_plane(i, tilt) - h[i]) * stiffness * s;
        // Neighbours, which is what makes it a wave and not a row of springs.
        final l = h[i == 0 ? 0 : i - 1];
        final r = h[i == cols - 1 ? cols - 1 : i + 1];
        v[i] += ((l + r) * 0.5 - h[i]) * spread * s;
        v[i] -= v[i] * drag * s;
      }
      for (var i = 0; i < cols; i++) {
        h[i] = (h[i] + v[i] * s).clamp(-maxRise, maxRise);
        v[i] = v[i].clamp(-maxSpeed, maxSpeed);
      }
    }
    energy = math.max(0, energy - dt * 0.5);
  }

  /// A flick of the wrist throws the water at one wall: an antisymmetric shove,
  /// which is the first sloshing mode of any container.
  ///
  /// Water that is already moving is left alone. A shake is a series of shoves
  /// twenty a second, and adding every one of them is pumping, not sloshing —
  /// which is what turned an aggressive shake into a wild surface.
  void kick(double strength, double dir) {
    if (energy > 0.75) return;
    for (var i = 0; i < cols; i++) {
      v[i] += dir * (i / (cols - 1) - 0.5) * strength.clamp(0.0, 1.2) * 90;
    }
    energy = math.min(1, energy + 0.45);
  }

  /// Where the surface sits at 0..1 across the glass, interpolated between the
  /// two columns either side.
  double at(double u) {
    final x = (u.clamp(0.0, 1.0)) * (cols - 1);
    final i = x.floor().clamp(0, cols - 1);
    final j = math.min(i + 1, cols - 1);
    return h[i] + (h[j] - h[i]) * (x - i);
  }

  /// The mean level. Nothing should move it: water is not created by tilting the
  /// glass, and a test says so.
  double get mean => h.reduce((a, b) => a + b) / cols;
}

class _WaterTankState extends State<WaterTank> with SingleTickerProviderStateMixin {
  final _sea = WaterSurface();

  /// Created here, started in initState. It must not start itself in this
  /// initialiser: `late final` is lazy, so a ticker nobody reads is never built at
  /// all — which left the glass sitting at zero fill, empty and dead still.
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _clock = 0; // seconds the tank has been on screen, for the bubbles

  StreamSubscription<AccelerometerEvent>? _accel;
  StreamSubscription<GyroscopeEvent>? _gyro;

  /// Where gravity says "down" is, low-passed. Raw accelerometer values jitter by
  /// a few percent every sample and the surface would buzz on the noise.
  double _gravity = 0;
  double _fill = 0; // eases towards widget.fill, so the tank fills on arrival

  @override
  void initState() {
    super.initState();
    _ticker.start();
    if (widget.tilt != null) return;
    // onError, not try/catch: the failure is asynchronous on a device with no
    // sensor and in every widget test, and a still tank is fine.
    _accel = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 40),
    ).listen((e) {
      // What the phone feels is gravity *plus* however hard it is being thrown
      // about, and only the first of those is a tilt. /3.2 puts the full lean at
      // about a twenty degree tip — a tilt you meant, not a shove — and the filter
      // follows it in a quarter of a second so the water starts moving while your
      // wrist is still turning. Going wild is stopped by the ceiling in
      // [WaterSurface], not by making the whole thing sluggish.
      final target = (e.x / 3.2).clamp(-1.0, 1.0);
      if ((target - _gravity).abs() < 0.02) return; // hand shake, not a tilt
      _gravity += (target - _gravity) * 0.16;
    }, onError: (_) {}); // no cancelOnError: one hiccup must not kill the tank

    // The gyroscope is what a shake actually is: rotation rate, not
    // acceleration. A flick of the wrist clears 0.7 rad/s; a hand carrying a phone
    // across a room does not — and [WaterSurface.kick] refuses to stack shoves on
    // water that is already moving.
    _gyro = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 40),
    ).listen((e) {
      final spin = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (spin < 0.7 || !Store.motion) return;
      _sea.kick(math.min(1.2, spin - 0.7), e.y.isNegative ? -1 : 1);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _accel?.cancel();
    _gyro?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0) return;
    dt = math.min(dt, 1 / 30); // a slow frame stretches, it never explodes
    _clock += dt;
    _fill += (widget.fill.clamp(0.0, 1.0) - _fill) * math.min(1, dt * 3.2);
    _sea.step(dt, Store.motion ? (widget.tilt ?? _gravity) : 0.0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => ClayWell(
        radius: 26,
        depth: 1.6, // the tank is the deepest well in the app
        padding: const EdgeInsets.all(7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _Water(
                    sea: _sea,
                    clock: _clock,
                    fill: _fill,
                    goal: widget.goal,
                  ),
                ),
                // Glass: one top-left sheen and a bright rim. Liquid glass is
                // rationed in this app and this is one of the places.
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.5],
                      ),
                    ),
                  ),
                ),
                if (widget.caption != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(widget.caption!, style: A.figure(15, c: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

/// The water itself, drawn from whatever the surface is doing this frame.
class _Water extends CustomPainter {
  const _Water({
    required this.sea,
    required this.clock,
    required this.fill,
    required this.goal,
  });

  final WaterSurface sea;
  final double clock, fill;
  final bool goal;

  /// Where the surface sits at 0..1 across the glass: the simulation, plus a
  /// breath of ripple so a tank nobody is touching is not a frozen block, plus
  /// the climb up the glass that water always has at a wall.
  double _y(double u, double rest, double w) {
    final ripple = math.sin(u * 6.6 + clock * 0.9) * 0.8 +
        math.sin(u * 12.4 - clock * 1.3) * 0.5;
    final x = u * w;
    final climb = 2.6 * math.exp(-x / 7) + 2.6 * math.exp(-(w - x) / 7);
    return rest + sea.at(u) + ripple * (1 + sea.energy * 2) - climb;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The water rises towards the goal line, not towards the brim.
    final rest = size.height * (1 - fill.clamp(0.0, 1.0) * _goalAt);
    final body = Path()..moveTo(0, size.height);
    final top = Path();
    for (var x = 0.0; x <= size.width + 2; x += 2) {
      final u = x / size.width;
      // Clamped to the glass: a surface point above the brim would read as the
      // water vanishing, and one below the floor as the glass emptying.
      final y = _y(u, rest, size.width).clamp(3.0, size.height - 2);
      body.lineTo(x, y);
      x == 0 ? top.moveTo(x, y) : top.lineTo(x, y);
    }
    body
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        // Alpha has to be baked into the gradient: Paint.color is ignored once a
        // shader is set. Light at the surface, deeper towards the floor.
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8FDCF0), A.accent, A.accentDeep],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromLTWH(0, rest - 10, size.width, size.height - rest + 10)),
    );
    _bubbles(canvas, size, rest);
    _meniscus(canvas, top);
    _glass(canvas, size);
    if (goal) _goal(canvas, size);
  }

  /// The bright line where water grips glass. Without it the water is a shape;
  /// with it, it is a liquid. The blurred copy underneath is light leaking through
  /// the surface from above.
  void _meniscus(Canvas canvas, Path top) {
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.78),
    );
  }

  /// Bubbles on their own clocks, drifting up and dissolving as they reach the
  /// surface. Index arithmetic instead of Random, so every frame agrees on where
  /// they are.
  ///
  /// A bubble's height is measured against the *resting* level, never against the
  /// live surface: hanging it off the moving surface made every bubble jump with
  /// the slosh, and the "has it popped yet" test flipped on and off as the water
  /// rocked, which is the flicker. Now it simply fades out over the last few pixels
  /// under whatever the surface is doing above it.
  void _bubbles(Canvas canvas, Size size, double rest) {
    for (var i = 0; i < 9; i++) {
      final u = ((i * 37) % 91) / 91 * 0.84 + 0.08;
      final r = 1.2 + ((i * 53) % 25) / 10;
      final speed = 0.03 + ((i * 29) % 40) / 1500;
      final prog = (clock * speed + i / 9) % 1;
      final y = size.height - prog * (size.height - rest - r);
      final top = _y(u, rest, size.width);
      if (y < top) continue;
      // Carried sideways by whatever the water is doing, rather than rising
      // faster with it: a bubble in a sloshing glass drifts, it does not sprint.
      final x = u * size.width + math.sin(prog * 7 + i) * 3.5 + sea.at(u) * 0.3;
      // Dimmer as it rises, and gone in the last 10px before it surfaces.
      final fade = ((1 - prog) * 0.5 + 0.15) * ((y - top) / 10).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: fade * 0.5));
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.white.withValues(alpha: fade),
      );
      // A speck of highlight, which is what makes a circle read as a bubble.
      if (r > 2.2) {
        canvas.drawCircle(Offset(x - r * 0.3, y - r * 0.35), r * 0.28,
            Paint()..color = Colors.white.withValues(alpha: fade));
      }
    }
  }

  /// What the glass itself does to the light: one narrow specular band left of
  /// centre because the front face is curved, and a pool of light where the floor
  /// meets the water so the bottom is not a flat cut.
  void _glass(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.16, 0, 6, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height + 6),
        width: size.width * 1.1,
        height: 26,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  /// The line the tank is aiming at, labelled inside the glass so the tank can be
  /// dropped into any layout without the caller placing the label.
  void _goal(Canvas canvas, Size size) {
    final y = size.height * (1 - _goalAt);
    canvas.drawLine(
      Offset(size.width * 0.1, y),
      Offset(size.width * 0.9, y),
      Paint()
        ..color = A.ink.withValues(alpha: 0.38)
        ..strokeWidth = 1.4,
    );
    final label = TextPainter(
      text: TextSpan(text: 'goal', style: A.tiny.copyWith(fontSize: 9.5, color: A.ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(size.width * 0.9 - label.width, y - label.height - 2));
  }

  // The surface is mutated in place by the ticker, so there is nothing to compare:
  // if this painter is being rebuilt at all, the water has moved.
  @override
  bool shouldRepaint(_Water old) => true;
}
