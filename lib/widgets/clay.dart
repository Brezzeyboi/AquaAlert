
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../theme.dart';

/// The base surface of the whole app. Nothing is ever flat.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = A.rCard,
    this.color,
    this.onTap,
    this.outlined = false,
    this.outline = A.ink,
    this.outlineWidth = 2.5,
    this.dashes = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  /// Bold outline. Navy is the comic accent layer — interaction and feedback
  /// only, never on a resting secondary card. Cyan and amber mark a live event
  /// or your own row, which the mockups outline at rest.
  final bool outlined;
  final Color outline;
  final double outlineWidth;

  /// Throw the ink dashes on press. On for the round glyph buttons — a back or a
  /// share is a button and should pop like one — off for cards, where eight ink
  /// lines around a whole report row would be noise.
  final bool dashes;

  @override
  Widget build(BuildContext context) {
    Widget body(bool down) => AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: padding,
          decoration: BoxDecoration(
            gradient: A.cardGrad(color),
            borderRadius: BorderRadius.circular(radius),
            border: outlined ? Border.all(color: outline, width: outlineWidth) : A.rim,
            // Pressed clay sinks: the shadow swaps sides instead of just fading.
            boxShadow: down ? A.clayPressed() : A.clay(),
          ),
          child: child,
        );
    if (onTap == null) return body(false);
    return _Press(onTap: onTap!, radius: radius, dashes: dashes, builder: body);
  }
}

/// Shared press physics: everything clay squashes 2% and sinks its shadow.
/// Buttons also throw a ring of ink dashes, which is how the mockups draw a
/// press — the comic layer is feedback, so it only exists while held.
///
/// The press is held on screen for a minimum beat. A quick tap puts the finger
/// down and up inside a frame or two, so the squash and the dashes used to be
/// painted for almost no time at all — which is why the effect only showed up if
/// you held the button a moment longer.
class _Press extends StatefulWidget {
  const _Press({
    required this.builder,
    required this.onTap,
    required this.radius,
    this.dashes = false,
    this.paint,
    this.scale = 0.965,
  });
  final Widget Function(bool down) builder;
  final VoidCallback onTap;
  final double radius;
  final bool dashes;

  /// An extra painter behind the child, handed the pressed state — the plus
  /// button's white starburst.
  final CustomPainter Function(bool down)? paint;

  /// How far it squashes. The round plus goes further than a flat card.
  final double scale;

  @override
  State<_Press> createState() => _PressState();
}

/// Long enough to read at 60fps, short enough that it never feels sticky.
const _minHold = Duration(milliseconds: 140);

class _PressState extends State<_Press> {
  bool _down = false;
  Timer? _lift;
  final _held = Stopwatch();

  @override
  void dispose() {
    _lift?.cancel();
    super.dispose();
  }

  void _press() {
    _lift?.cancel();
    _held
      ..reset()
      ..start();
    setState(() => _down = true);
    // Clay you can feel. Off when the setting is off, and silently ignored
    // on a device with no vibrator.
    if (Store.haptics) HapticFeedback.lightImpact();
  }

  void _release() {
    final left = _minHold - _held.elapsed;
    if (left <= Duration.zero) {
      setState(() => _down = false);
      return;
    }
    _lift = Timer(left, () {
      if (mounted) setState(() => _down = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.builder(_down);
    if (widget.dashes) child = CustomPaint(painter: _Dashes(_down), child: child);
    if (widget.paint != null) {
      child = CustomPaint(painter: widget.paint!(_down), child: child);
    }
    return GestureDetector(
      onTapDown: (_) => _press(),
      onTapCancel: _release,
      onTapUp: (_) => _release(),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

/// Eight short ink dashes, aimed out of the object's own box so a wide pill
/// throws them off its ends instead of round a circle.
class _Dashes extends CustomPainter {
  const _Dashes(this.on);
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    if (!on) return;
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = A.ink
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final dir = Offset(math.cos(a), math.sin(a));
      final edge = Offset(dir.dx * size.width / 2, dir.dy * size.height / 2);
      canvas.drawLine(c + edge + dir * 5, c + edge + dir * 13, paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.on != on;
}

/// Ben-Day dots — the comic layer's only texture. Dense at the left and gone
/// by the right. Deliberately faint: at full strength the dots fight whatever
/// copy sits on top of them instead of backing it.
class Halftone extends StatelessWidget {
  const Halftone({
    super.key,
    this.color = A.accentDeep,
    this.gap = 9,
    this.dot = 1.5,
    this.alpha = 0.34,
  });
  final Color color;
  final double gap, dot, alpha;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _Dots(color, gap, dot, alpha));
}

class _Dots extends CustomPainter {
  const _Dots(this.color, this.gap, this.dot, this.alpha);
  final Color color;
  final double gap, dot, alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    for (var row = 0; gap / 2 + row * gap < size.height; row++) {
      final y = gap / 2 + row * gap;
      // Offset rows: a square grid reads as a screen door, not as halftone.
      for (var x = gap / 2 + (row.isOdd ? gap / 2 : 0); x < size.width; x += gap) {
        final f = 1 - x / size.width;
        if (f < 0.12) continue;
        // Dot size carries the fade, so the whole field is one path, one draw.
        p.addOval(Rect.fromCircle(center: Offset(x, y), radius: dot * f));
      }
    }
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_Dots old) =>
      old.color != color || old.gap != gap || old.dot != dot || old.alpha != alpha;
}

/// Primary action. Cyan, full width by default. [secondary] is the white pill
/// with the navy outline; a disabled button turns grey, because a pale cyan one
/// still looks like the thing you are meant to press.
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = A.accent,
    this.icon,
    this.expand = true,
    this.secondary = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool expand;
  final bool secondary;

  /// Three bouncing dots instead of the label: the states sheet's (c), for when
  /// a report is on its way to the server.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !loading;
    final ink = disabled
        ? A.inkSoft.withValues(alpha: 0.8)
        : secondary
            ? A.ink
            : Colors.white;
    final row = loading
        ? const _LoadingDots()
        : Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 19, color: ink), const SizedBox(width: 9)],
        // Two buttons often share a row, so a long label shrinks instead of
        // shoving its neighbour off the screen.
        Flexible(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: A.h3.copyWith(color: ink)),
        ),
      ],
    );
    return _Press(
      onTap: onTap ?? () {},
      radius: A.rPill,
      dashes: !disabled,
      builder: (down) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(A.rPill),
          boxShadow: disabled
              ? null
              : down
                  ? A.clayPressed()
                  : secondary
                      ? A.clay()
                      : A.lip(color),
          // Pressed draws the navy outline whether or not it is the secondary
          // shape — that outline is the app's "held" state.
          border: (secondary || down) && !disabled
              ? Border.all(color: A.ink, width: 2.2)
              : null,
          gradient: disabled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE2E8EF), Color(0xFFC7D1DC)])
              : secondary
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, A.card])
                  : A.domeGrad(color),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(A.rPill),
          child: Stack(
            children: [
              // The specular cap: a soft white lid over the top half, which is
              // what reads as a moulded, glossy surface in the mockups.
              if (!disabled)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(gradient: A.glossGrad()),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 26),
                child: row,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice among a few: report mode, room, leak type, a list filter. Filled
/// when it is the chosen one, raised and quiet when it is not.
class ClayChip extends StatelessWidget {
  const ClayChip(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.color = A.accent,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _Press(
        onTap: onTap ?? () {},
        radius: A.rPill,
        builder: (down) => AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(A.rPill),
            boxShadow: down ? A.clayPressed() : A.clay(d: selected ? 0.8 : 0.55),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [Color.lerp(color, Colors.white, 0.24)!, color]
                  : [Colors.white, A.card],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : A.inkSoft),
                const SizedBox(width: 6),
              ],
              // Three chips have to share a phone width, so a long label
              // ellipsises rather than pushing its neighbours off the screen.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: A.label.copyWith(
                    fontSize: 14,
                    color: selected ? Colors.white : A.inkSoft,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// A setting you flip. On, the track carries halftone dots — the one place the
/// comic texture sits on a control, and it is how the mockup draws "on".
class ClayToggle extends StatelessWidget {
  const ClayToggle({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 54,
          height: 30,
          child: Stack(
            children: [
              Positioned.fill(
                child: value
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(A.rPill),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(A.rPill),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6FD3EE), A.accent],
                            ),
                          ),
                          child: const Halftone(color: Colors.white, gap: 6, dot: 1.2),
                        ),
                      )
                    : const ClayWell(
                        radius: A.rPill,
                        padding: EdgeInsets.zero,
                        child: SizedBox.expand(),
                      ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // A dome, not a disc: the knob is the one thing on a toggle
                    // your eye follows, so it gets the light spot.
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.5),
                      colors: [Colors.white, value ? const Color(0xFFE6F5FB) : A.card],
                    ),
                    boxShadow: A.clay(d: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Three dots that bounce in turn: the button's loading state. White, because it
/// only ever sits on the cyan pill.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Transform.translate(
                  // A third of a cycle apart, so the bounce travels left to right.
                  offset: Offset(0, -4 * math.sin(((_c.value + i / 3) % 1) * math.pi)),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// The cyan round button — the nav's plus, the camera on a photo card. Pressed,
/// it throws the white starburst the states sheet draws behind it, and it holds
/// that burst on screen through [_Press] like every other control.
class ClayFab extends StatelessWidget {
  const ClayFab({super.key, required this.icon, required this.onTap, this.size = 62});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => _Press(
        onTap: onTap,
        radius: size,
        scale: 0.93,
        paint: (down) => _FabBurst(down),
        builder: (down) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: down ? Border.all(color: A.ink, width: 2.2) : null,
            boxShadow: down ? A.clayPressed() : A.seat(A.accent, d: 1.35),
            gradient: A.discGrad(A.accent),
          ),
          child: Icon(icon, size: size * 0.52, color: Colors.white),
        ),
      );
}

/// White points with a navy outline, poking out from behind the button while it
/// is held. Feedback only — it exists for as long as the finger does.
class _FabBurst extends CustomPainter {
  const _FabBurst(this.on);
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    if (!on) return;
    final c = size.center(Offset.zero);
    final star = Path();
    const n = 11;
    final out = size.shortestSide / 2 + 11, inn = size.shortestSide / 2 - 2;
    for (var i = 0; i < n * 2; i++) {
      final a = i * math.pi / n - math.pi / 2;
      final r = i.isEven ? out : inn;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = Colors.white);
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = A.ink,
    );
  }

  @override
  bool shouldRepaint(_FabBurst old) => old.on != on;
}

/// The toast from the states sheet: a white pill with the navy outline, a filled
/// check, and UNDO in cyan. Undo is the whole point — it is what lets a report
/// send immediately instead of behind a confirm dialog.
void showClayToast(BuildContext context, String message, {VoidCallback? onUndo}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 4),
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 18, 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(A.rPill),
          color: Colors.white,
          border: Border.all(color: A.ink, width: 2),
          boxShadow: A.clay(d: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: A.ink, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(message, style: A.body.copyWith(fontWeight: FontWeight.w600))),
            if (onUndo != null)
              GestureDetector(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onUndo();
                },
                child: Text('UNDO',
                    style: A.label.copyWith(
                      color: A.accentDeep,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    )),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Every sheet in the app opens through here, so every sheet clears the phone's
/// own navigation bar. A sheet padded for the keyboard alone drops its primary
/// button behind the three-button bar on exactly the phones that have one — which
/// is what put "Join" half under the navigation bar.
Future<T?> claySheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          // viewInsets is the keyboard and padding is the system bar. The
          // keyboard covers that bar while it is up, so this is a max, not a sum.
          bottom: 14 +
              math.max(MediaQuery.viewInsetsOf(c).bottom, MediaQuery.paddingOf(c).bottom),
        ),
        child: child,
      ),
    );

/// Frosted glass. Liquid glass is rationed in this app: the nav bar, unread
/// notifications, and the moment panels that sit over a blurred screen.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.radius = A.rCard, this.padding});
  final Widget child;
  final double radius;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding ?? const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.82),
                  Colors.white.withValues(alpha: 0.62),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.4),
              boxShadow: A.clay(),
            ),
            child: child,
          ),
        ),
      );
}

/// A round clay button holding one glyph: back, share, close, settings, sort.
/// Every screen in the mockups is topped by one or two of these instead of an
/// app bar.
class ClayIcon extends StatelessWidget {
  const ClayIcon(this.icon, {super.key, this.onTap, this.size = 46, this.color = A.ink});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ClayCard(
        onTap: onTap,
        radius: size,
        padding: EdgeInsets.zero,
        dashes: true, // share, back, settings: all buttons, so all of them pop
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.46, color: color),
        ),
      );
}

/// Status badge / small chip. Reported, In progress, Still not fixed!, Fixed.
class ClayPill extends StatelessWidget {
  const ClayPill(this.text, {super.key, this.color = A.accent, this.icon, this.dense = false});

  final String text;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 13, vertical: dense ? 5 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(A.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: Color.lerp(color, A.ink, 0.35)),
            const SizedBox(width: 5),
          ],
          // Flexible, because a pill can land in a narrow column and "Still not
          // fixed!" is a long label.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: A.tiny.copyWith(
                color: Color.lerp(color, A.ink, 0.35),
                fontWeight: FontWeight.w600,
                fontSize: dense ? 11 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inset well — text fields, slider tracks, the tank body.
class ClayWell extends StatelessWidget {
  const ClayWell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = A.rField,
    this.color,
    this.depth = 1,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final double depth;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _Well(radius, color ?? A.sunk, depth),
        child: Padding(padding: padding, child: child),
      );
}

/// Flutter has no inset box-shadow, so a well has to be painted: clip to the
/// rounded rect, then bleed a blurred shadow in from *outside* the clip. Light
/// is top-left, so the shaded wall is the top-left one and the lit one is
/// bottom-right — the old single outer shadow had it backwards, which is why
/// every field read flat on the phone.
class _Well extends CustomPainter {
  const _Well(this.radius, this.fill, this.depth);

  final double radius;
  final Color fill;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(r, Paint()..color = fill);
    canvas.save();
    canvas.clipRRect(r);
    _wall(canvas, size, r, Offset(4 * depth, 5 * depth), 11 * depth,
        A.shade.withValues(alpha: 0.6));
    _wall(canvas, size, r, Offset(-3.5 * depth, -4.5 * depth), 9 * depth,
        Colors.white.withValues(alpha: 0.95));
    canvas.restore();
  }

  /// Everything outside the shifted rect, blurred. Clipped to the well, only
  /// the bleed over one inner edge survives — that is the inset shadow.
  void _wall(Canvas canvas, Size size, RRect r, Offset o, double blur, Color c) {
    final out = Path()..addRect(Rect.fromLTRB(-80, -80, size.width + 80, size.height + 80));
    final hole = Path()..addRRect(r.shift(o));
    canvas.drawPath(
      Path.combine(PathOperation.difference, out, hole),
      Paint()
        ..color = c
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  bool shouldRepaint(_Well old) => old.radius != radius || old.fill != fill || old.depth != depth;
}

// PLACEHOLDER_CLAY
