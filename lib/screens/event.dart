import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import 'leaderboard.dart';

/// The event, read-only for a student. LIVE NOW, a countdown, the prize stated
/// plainly, and where your class stands — a vague prize is what kills
/// participation, so it is a card of its own.
///
/// It belongs to the school, so it counts what the school fixes. Somebody with no
/// class — the head, the office — gets the leading class instead of "yours".
class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const e = Store.event;
    final mine = Store.classes.where((c) => c.name == Store.userClass).firstOrNull;
    final show = mine ?? Store.classes.first;
    final rank = Store.classes.indexOf(show) + 1;
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
                  Expanded(child: Center(child: Text('Event', style: A.h3))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  const Center(child: _Live()),
                  const SizedBox(height: 12),
                  Text(e.name,
                      style: A.h1.copyWith(fontSize: 31), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('${Store.shortName} · ${e.dates}',
                      style: A.bodySoft, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  _Countdown(e.days),
                  const SizedBox(height: 16),
                  ClayCard(
                    color: A.tint(A.amber, 0.82),
                    padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                    child: Row(
                      children: [
                        const Medallion(Icons.emoji_events_rounded, size: 56, color: A.amber),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.prize, style: A.h3),
                              const SizedBox(height: 2),
                              Text('${e.classes} classes are taking part', style: A.tiny),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClayCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('How it works', style: A.h3),
                        const SizedBox(height: 12),
                        // The event is the school's own, so it counts what the
                        // school fixes. Street reports still count everywhere
                        // else in the app; they are just not this competition.
                        const _How(Icons.water_drop_rounded, 'Report leaks in school',
                            'Anything inside ${Store.shortName} counts for your class'),
                        const SizedBox(height: 10),
                        const _How(Icons.star_rounded, 'Every litre counts twice',
                            'Double XP while the event runs'),
                        const SizedBox(height: 10),
                        const _How(Icons.check_rounded, 'Points land when it is fixed',
                            'So the water is really saved, not just spotted'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClayCard(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mine == null ? 'Leading right now' : 'Your class right now',
                            style: A.h3),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: A.cardGrad(null),
                                boxShadow: A.clay(d: 0.45),
                              ),
                              child: Text('$rank', style: A.figure(17)),
                            ),
                            const SizedBox(width: 13),
                            Expanded(child: Text(show.name, style: A.h2.copyWith(fontSize: 19))),
                            Text('${litres(show.litres)} L', style: A.figure(21)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          mine == null
                              ? '${Store.classes.length} classes are on the board.'
                              : '${show.students} students · '
                                  '${litres(Store.classes.first.litres - show.litres)} L behind '
                                  '${Store.classes.first.name}',
                          style: A.tiny,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClayButton(
                    label: 'See the leaderboard',
                    icon: Icons.leaderboard_rounded,
                    onTap: () => Navigator.of(context).push(
                      A.route(const LeaderboardScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Litres only count once a report is marked fixed, so a class cannot win '
                    'by reporting the same tap twice.',
                    style: A.bodySoft.copyWith(fontSize: 13.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The flag, with the ink dashes the mockup draws either side of it.
class _Live extends StatelessWidget {
  const _Live();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Dashes(true),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(A.rPill),
              boxShadow: A.clay(d: 0.6),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6FD3EE), A.accent],
              ),
            ),
            child: Text('LIVE NOW',
                style: A.h3.copyWith(color: Colors.white, fontSize: 16, letterSpacing: 1)),
          ),
          const _Dashes(false),
        ],
      );
}

class _Dashes extends StatelessWidget {
  const _Dashes(this.left);
  final bool left;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: left ? 0 : 8, right: left ? 8 : 0),
        child: Transform.scale(
          scaleX: left ? 1 : -1,
          child: SizedBox(
            width: 22,
            height: 34,
            child: CustomPaint(painter: _Ink()),
          ),
        ),
      );
}

class _Ink extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = A.ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 4), const Offset(14, 11), p);
    canvas.drawLine(const Offset(0, 17), const Offset(12, 17), p);
    canvas.drawLine(Offset(4, size.height - 4), const Offset(14, 23), p);
  }

  @override
  bool shouldRepaint(_Ink old) => false;
}

/// Days, hours, minutes, seconds — four clay tiles. It ticks, because a
/// countdown that does not move is a label.
class _Countdown extends StatefulWidget {
  const _Countdown(this.days);
  final int days;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Stream<void> _tick =
      Stream.periodic(const Duration(seconds: 1)).asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    // The event ends at midnight on its last day, which is all the mock data
    // knows; the real end time comes from Supabase later.
    final end = DateTime.now().add(Duration(days: widget.days));
    return StreamBuilder<void>(
      stream: _tick,
      builder: (_, __) {
        final left = end.difference(DateTime.now());
        final parts = [
          (left.inDays, 'days'),
          (left.inHours % 24, 'hrs'),
          (left.inMinutes % 60, 'min'),
          (left.inSeconds % 60, 'sec'),
        ];
        return Row(
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              Expanded(
                child: ClayCard(
                  radius: 22,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    children: [
                      Text(parts[i].$1.toString().padLeft(2, '0'), style: A.figure(27)),
                      Text(parts[i].$2, style: A.tiny),
                    ],
                  ),
                ),
              ),
              if (i != parts.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

/// One row of the how-it-works card: a sunk disc, a bold line, a soft line.
class _How extends StatelessWidget {
  const _How(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          ClayWell(
            radius: 44,
            padding: const EdgeInsets.all(11),
            color: A.tint(A.accent, 0.86),
            child: Icon(icon, size: 20, color: A.ink),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: A.h3.copyWith(fontSize: 15)),
                const SizedBox(height: 1),
                Text(body, style: A.tiny),
              ],
            ),
          ),
        ],
      );
}
