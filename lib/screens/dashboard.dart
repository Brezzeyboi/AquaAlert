import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import '../widgets/leak_card.dart';
import '../widgets/tank.dart';
import 'leak_detail.dart';
import 'map.dart';

/// Home. The order is the order someone asks: what is running right now, how
/// much water I have saved, how that sits against everyone else, what is open,
/// and what came in lately.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onSeeAll, this.onEvent, this.onBoard, this.onAccount});
  final VoidCallback? onSeeAll, onEvent, onBoard, onAccount;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        // The store is the only source on this screen, so it redraws the moment
        // the store moves: a report filed, litres credited, an account swapped.
        valueListenable: Store.revision,
        builder: (context, _, __) {
          final cards = <Widget>[
      _Greeting(onAccount: onAccount),
      // An event belongs to an institution, so it only exists for somebody who
      // joined one. Reporting never depends on it.
      if (Store.joined && Store.event.days > 0) _EventBanner(Store.event, onTap: onEvent),
      const _TankCard(),
      _ImpactCard(onBoard: onBoard),
      // Where the leaks are, before how many there are: a report is a place
      // first, and tapping this opens the neighbourhood.
      const MapPreview(),
      _StatTiles(onTap: onSeeAll),
      _RecentCard(onSeeAll: onSeeAll),
    ];
          return DropletRefresh(
      // There is no server to ask: the store lives in memory, so a pull is a
      // re-read. The droplet and the halftone arc are real all the same.
      onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 900)),
      child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 152),
      children: [
        for (var i = 0; i < cards.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 0 ? 16 : 13),
            child: Pop(cards[i], index: i),
          ),
      ],
              ),
            );
        },
      );
}

class _Greeting extends StatelessWidget {
  const _Greeting({this.onAccount});
  final VoidCallback? onAccount;

  /// The clock decides, so the app never wishes a child good morning at night.
  static String get _time {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_time, style: A.bodySoft.copyWith(fontSize: 16)),
                Text(Store.userName, style: A.h1),
              ],
            ),
          ),
          InitialsAvatar(Store.fullName, onTap: onAccount),
        ],
      );
}

/// The live event, and the one card carrying the comic layer: a cyan edge, a
/// halftone patch at the left and the LIVE NOW flag. It is loud on purpose and
/// it only exists while the clock is running.
class _EventBanner extends StatelessWidget {
  const _EventBanner(this.event, {this.onTap});
  final EventInfo event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ClayCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        color: A.tint(A.accent, 0.9),
        outlined: true,
        outline: A.accent,
        outlineWidth: 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(A.rCard - 2),
          child: Stack(
            children: [
              // Dots only under the flag, not across the copy — a field behind
              // text turns into grey mush at phone size.
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 130,
                child: Halftone(gap: 8, dot: 1.6),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const _Live(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.name,
                                  style: A.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('Ends in ${event.days} days · you are rank ${Store.you.rank}',
                                  style: A.tiny),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
                      ],
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.fromLTRB(0, 11, 0, 9),
                      color: A.accentDeep.withValues(alpha: 0.18),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.double_arrow_rounded, size: 16, color: A.accentDeep),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Every leak fixed in school counts',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: A.label.copyWith(color: A.ink)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Cyan pill, white type, a lamp on the left. Comic language, so it may shout —
/// and the lamp pings, because "live" is the one claim on this screen that is
/// about right now.
class _Live extends StatefulWidget {
  const _Live();

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(A.rPill),
          boxShadow: A.clay(d: 0.45),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6FD3EE), A.accent],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A fixed box, so the ping cannot nudge the label as it grows.
            SizedBox(
              width: 12,
              height: 12,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final v = _c.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: 1 + v * 1.1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.5 * (1 - v)),
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Text('LIVE NOW',
                style: A.tiny.copyWith(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                )),
          ],
        ),
      );
}

/// The tank, and the number it stands for. The glass does the feeling, the
/// figure does the fact.
class _TankCard extends StatelessWidget {
  const _TankCard();

  @override
  Widget build(BuildContext context) {
    final fill = (Store.yourLitres / Store.monthlyGoal).clamp(0.0, 1.0);
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
      child: Row(
        children: [
          SizedBox(width: 116, child: WaterTank(fill: fill, height: 152)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // scaleDown, not a smaller font: 18,70,000 L has to fit beside
                // the glass on a narrow phone and at a large text setting.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      CountUp(Store.yourLitres, style: A.figure(40)),
                      const SizedBox(width: 5),
                      Text('L', style: A.h2.copyWith(fontSize: 22)),
                    ],
                  ),
                ),
                Text('saved this month', style: A.bodySoft.copyWith(fontSize: 16)),
                const SizedBox(height: 10),
                Text('goal ${litres(Store.monthlyGoal)} L', style: A.bodySoft.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text('${(fill * 100).round()}% of the way', style: A.tiny),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// You inside your campus inside the whole app. Each bar is that tier's share of
/// the one above it — a bar against the global total would leave the top one
/// full and the other two invisible.
class _ImpactCard extends StatelessWidget {
  const _ImpactCard({this.onBoard});
  final VoidCallback? onBoard;

  @override
  Widget build(BuildContext context) => ClayCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your impact this month', style: A.h3),
            const SizedBox(height: 14),
            _row('You', Store.yourLitres, A.accent,
                Store.yourLitres / (Store.joined ? Store.campusLitres : Store.allLitres)),
            const SizedBox(height: 11),
            if (Store.joined) ...[
              _row('Your school', Store.campusLitres, A.accentDeep,
                  Store.campusLitres / Store.allLitres),
              const SizedBox(height: 11),
            ],
            _row('Everyone', Store.allLitres, A.ink, 1),
            Container(
              height: 1,
              margin: const EdgeInsets.fromLTRB(0, 13, 0, 3),
              color: A.ink.withValues(alpha: 0.07),
            ),
            GestureDetector(
              onTap: onBoard,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.leaderboard_rounded, size: 17, color: A.accentDeep),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text('See the leaderboard',
                          style: A.label.copyWith(color: A.ink)),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: A.inkSoft),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, int value, Color c, double share) => Row(
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: A.body.copyWith(fontSize: 14.5)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text('${litres(value)} L', style: A.figure(15, c: A.ink)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: LevelBar(share, color: c, height: 9)),
        ],
      );
}

/// The three numbers a reporter and a fixer both open the app for. Counted from
/// the reports, never typed.
class _StatTiles extends StatelessWidget {
  const _StatTiles({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _tile(Store.openCount, 'Open', A.ink),
          const SizedBox(width: 11),
          _tile(Store.fixedCount, 'Fixed', A.ink),
          const SizedBox(width: 11),
          _tile(Store.overdueCount, 'Overdue', A.amber),
        ],
      );

  Widget _tile(int n, String label, Color c) => Expanded(
        child: ClayCard(
          onTap: onTap,
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              CountUp(n, style: A.figure(30, c: c)),
              const SizedBox(height: 1),
              Text(label, style: A.bodySoft.copyWith(fontSize: 14)),
            ],
          ),
        ),
      );
}

/// The last few reports, as rows inside one card — the picture is what makes a
/// leak real, so it leads.
class _RecentCard extends StatelessWidget {
  const _RecentCard({this.onSeeAll});
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final recent = Store.recent;
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Recent reports', style: A.h3)),
              GestureDetector(
                onTap: onSeeAll,
                child: Text('See all',
                    style: A.label.copyWith(color: A.accentDeep, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final l in recent) _Row(l, last: l == recent.last),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.leak, {required this.last});
  final Leak leak;
  final bool last;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          A.route(LeakDetailScreen(leak, heroTag: 'dash-${leak.id}')),
        ),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.only(bottom: last ? 6 : 12),
          child: Row(
            children: [
              LeakThumb(leak, width: 92, height: 68, heroTag: 'dash-${leak.id}'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leak.title, style: A.h3.copyWith(fontSize: 15.5),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(leak.place, style: A.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    ClayPill(leak.status.label, color: leak.status.color, dense: true),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
            ],
          ),
        ),
      );
}
