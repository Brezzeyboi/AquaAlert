import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import 'share.dart';

/// One leak, opened. Photo, where it is, what it is costing, what has happened
/// to it so far — in that order, because that is the order someone asks.
class LeakDetailScreen extends StatefulWidget {
  const LeakDetailScreen(this.leak, {super.key, this.heroTag});
  final Leak leak;

  /// The tag of the thumbnail that opened this screen, so the photo flies in
  /// from the row it was tapped on.
  final String? heroTag;

  @override
  State<LeakDetailScreen> createState() => _LeakDetailScreenState();
}

class _LeakDetailScreenState extends State<LeakDetailScreen> {
  Leak get leak => widget.leak;

  /// One vouch per person, and the report remembers who — so this survives leaving
  /// the screen, and switching accounts hands the next person their own say.
  bool get _confirmed => leak.confirmedBy.contains(Store.userName);

  /// Community verification: there is no inspector and no admin in this app, so a
  /// report earns its credibility from the people who can see the leak with their
  /// own eyes. Confirming it is the thing anyone can do about somebody else's.
  void _confirm() {
    if (!Store.confirm(leak)) return;
    setState(() {});
    showClayToast(context, '${leak.confirms} people have seen this one');
  }

  void _set(Status s) {
    final was = leak.status;
    setState(() => leak.status = s);
    // Every list in the app is listening to the store, so this is what makes the
    // change land on the tabs sitting behind this screen.
    Store.touch();
    if (s == Status.inProgress) {
      showClayToast(context, 'Marked as started', onUndo: () {
        setState(() => leak.status = was);
        Store.touch();
      });
    }
    // Fixing it is the payoff, so it gets the one loud screen in the app: the
    // litres that stopped running, in a starburst, for exactly one tap.
    if (s == Status.fixed) {
      // The litres a fixed leak will not waste are credited to whoever reported
      // it, so the tank on the dashboard actually rises after this.
      Store.credit(leak);
      showDialog<void>(
        context: context,
        barrierColor: A.ink.withValues(alpha: 0.35),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: _Saved(leak.litresSaved),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixed = leak.status == Status.fixed;
    return Scaffold(
      backgroundColor: A.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  ClayIcon(Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ClayIcon(
                    Icons.ios_share_rounded,
                    onTap: () => Navigator.of(context).push(
                      A.route(ShareScreen(leak)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: [
                  if (leak.photo != null) ...[
                    if (widget.heroTag != null)
                      Hero(tag: widget.heroTag!, child: _Photo(leak.photo!))
                    else
                      _Photo(leak.photo!),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ClayPill('${leak.status.label} · ${leak.daysOpen} days',
                          color: leak.status.color, icon: leak.status.icon),
                      if (leak.scopeTag != null)
                        ClayPill(leak.scopeTag!,
                            color: A.accentDeep, icon: Icons.lock_outline_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(leak.title, style: A.h1.copyWith(fontSize: 26)),
                  const SizedBox(height: 5),
                  Text(leak.place, style: A.bodySoft),
                  const SizedBox(height: 14),
                  if (leak.lat != null && leak.lng != null) ...[
                    _Where(leak.lat!, leak.lng!),
                    const SizedBox(height: 14),
                  ],
                  _Meter(leak),
                  const SizedBox(height: 14),
                  _Timeline(leak),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 14, color: A.inkSoft),
                        const SizedBox(width: 6),
                        Expanded(child: Text(leak.visibleTo, style: A.tiny)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ClayButton(
                          label: 'Share',
                          icon: Icons.share_outlined,
                          secondary: true,
                          onTap: () => Navigator.of(context).push(
                            A.route(ShareScreen(leak)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        // You can close your own report, and a fixer can close
                        // anyone's. Everybody else can vouch for it, which is how
                        // a report gets believed with nobody in charge.
                        child: Store.canClose(leak)
                            ? ClayButton(
                                label: fixed ? 'Fixed' : 'Mark as fixed',
                                icon: Icons.check_rounded,
                                onTap: fixed ? null : () => _set(Status.fixed),
                              )
                            : ClayButton(
                                label: _confirmed ? 'Confirmed' : 'I’ve seen it too',
                                icon: Icons.how_to_reg_rounded,
                                onTap: fixed || _confirmed ? null : _confirm,
                              ),
                      ),
                    ],
                  ),
                  // Saying work has started is the same authority as closing it:
                  // the head for something inside the school, the reporter for
                  // their own. Nobody has it over a street somebody else reported.
                  if (Store.canClose(leak) && leak.status != Status.fixed &&
                      leak.status != Status.inProgress) ...[
                    const SizedBox(height: 12),
                    ClayButton(
                      label: 'Maintenance has started',
                      icon: Icons.build_rounded,
                      color: A.accentDeep,
                      onTap: () => _set(Status.inProgress),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The moment a leak stops running: the litres it will not waste any more, in
/// the comic layer, gone on the next tap.
class _Saved extends StatelessWidget {
  const _Saved(this.saved);
  final int saved;

  @override
  Widget build(BuildContext context) => GlassPanel(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Starburst(
              size: 150,
              color: A.green,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text('+${litres(saved)} L',
                    textAlign: TextAlign.center,
                    style: A.figure(26, c: Colors.white).copyWith(
                      shadows: [const Shadow(color: A.accentDeep, blurRadius: 2)],
                    )),
              ),
            ),
            const SizedBox(height: 14),
            Text('Fixed. That water stays in the tank.',
                style: A.h3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Counted from the day it was reported.',
                style: A.bodySoft.copyWith(fontSize: 13.5), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ClayButton(label: 'Done', onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
}

class _Photo extends StatelessWidget {
  const _Photo(this.asset);
  final String asset;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: A.clay(),
        ),
        padding: const EdgeInsets.all(7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(aspectRatio: 16 / 10, child: Image.asset(asset, fit: BoxFit.cover)),
        ),
      );
}

/// The map tile and the coordinates, split like the mockup: picture on the
/// left, machine-printed numbers on the right.
class _Where extends StatelessWidget {
  const _Where(this.lat, this.lng);
  final double lat, lng;

  @override
  Widget build(BuildContext context) => ClayCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            MapTile(lat, lng),
            Container(
              width: 1,
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: A.ink.withValues(alpha: 0.08),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${lat.toStringAsFixed(4)} N', style: A.mono(14)),
                const SizedBox(height: 6),
                Text('${lng.toStringAsFixed(4)} E', style: A.mono(14)),
              ],
            ),
          ],
        ),
      );
}

/// The cost, on a dial. A number alone does not land; a needle that has swung
/// most of the way round does.
class _Meter extends StatelessWidget {
  const _Meter(this.leak);
  final Leak leak;

  @override
  Widget build(BuildContext context) {
    final perHour = (leak.litresPerDay / 24).round();
    final total = leak.litresPerDay * leak.daysOpen;
    final fixed = leak.status == Status.fixed;
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            // The gauge reads itself out when the screen opens: the needle swings
            // up and settles the way a real meter does, and the odometer counts.
            // A dial that is simply *at* its value is a picture of a dial.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1100),
              builder: (_, t, __) => CustomPaint(
                painter: _Dial(
                  // The needle overshoots a little and comes back; the digits do
                  // not, because digits never bounce.
                  perHour / 100 * Curves.easeOutBack.transform(t),
                  (total * Curves.easeOutCubic.transform(t)).round(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Figure('$perHour', 'L / hour', 'Leak rate', A.ink),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 11),
                  color: A.ink.withValues(alpha: 0.08),
                ),
                _Figure(litres(total), 'L', fixed ? 'Saved by fixing it' : 'Wasted so far',
                    fixed ? A.green : A.ink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.unit, this.label, this.color);
  final String value, unit, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: A.mono(27, w: FontWeight.w700, c: color)),
                const SizedBox(width: 5),
                Text(unit, style: A.body),
              ],
            ),
          ),
          Text(label, style: A.tiny),
        ],
      );
}

/// What has happened to it, oldest first. Overdue is not a fourth step — it is
/// the first step having waited too long, so it lands as an amber last entry.
class _Timeline extends StatelessWidget {
  const _Timeline(this.leak);
  final Leak leak;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec'];

  String _day(int daysAgo) {
    final d = DateTime.now().subtract(Duration(days: daysAgo));
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, Color)>[
      ('Reported by ${leak.reporter}', _day(leak.daysOpen), A.accent),
      if (leak.confirms > 0)
        (
          'Confirmed by ${leak.confirms} ${leak.confirms == 1 ? 'person' : 'people'} nearby',
          _day((leak.daysOpen - 1).clamp(0, leak.daysOpen)),
          A.accent,
        ),
      switch (leak.status) {
        Status.inProgress => ('Maintenance started', _day(0), A.accent),
        Status.fixed => ('Marked fixed', _day(0), A.green),
        Status.overdue => ('Still not fixed', _day(0), A.amber),
        Status.reported => ('Waiting to be seen', 'now', A.inkSoft),
      },
    ];
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++)
            // Staggered, so the history reads as a history: reported, then seen,
            // then wherever it has got to.
            Pop(
              index: i,
              from: 10,
              Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rows[i].$3,
                        boxShadow: A.clay(d: 0.3),
                      ),
                    ),
                    if (i != rows.length - 1)
                      Container(width: 2, height: 34, color: A.accent.withValues(alpha: 0.5)),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$1, style: A.body.copyWith(fontWeight: FontWeight.w600)),
                        Text(rows[i].$2, style: A.tiny),
                      ],
                    ),
                  ),
                ),
              ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A house water meter: ticks, a red needle and an odometer. Clay body, because
/// every physical object in this app is clay.
class _Dial extends CustomPainter {
  const _Dial(this.sweep, this.total);
  final double sweep;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFDCE3EA));
    canvas.drawCircle(c, r - 5, Paint()..color = const Color(0xFFF4F7FA));
    final tick = Paint()
      ..color = A.inkSoft.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 40; i++) {
      final a = i * math.pi / 20;
      final long = i % 5 == 0;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r - 8), c + d * (r - (long ? 15 : 11)), tick);
    }
    // The needle. Clamped, because a 1,500 L/day street burst would otherwise
    // wrap the dial twice and read as nothing.
    final a = -math.pi / 2 + sweep.clamp(0.0, 1.0) * math.pi * 1.75;
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * (r - 18),
      Paint()
        ..color = const Color(0xFFD64545)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, 4.5, Paint()..color = A.inkSoft);
    // Odometer: five digits in a dark window, like the real thing.
    final box = Rect.fromCenter(center: c + Offset(0, r * 0.42), width: r * 1.1, height: 15);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()..color = A.ink);
    final t = TextPainter(
      text: TextSpan(
        text: total.toString().padLeft(5, '0'),
        style: A.mono(10, c: Colors.white, w: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(canvas, box.center - Offset(t.width / 2, t.height / 2));
  }

  @override
  bool shouldRepaint(_Dial old) => old.sweep != sweep || old.total != total;
}
