import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import '../widgets/leak_card.dart';
import 'leak_detail.dart';
import 'settings.dart';

/// You. Who you are, how far up the ladder, what you have earned, and the
/// reports you filed — in that order, because that is how the mockup stacks it.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        // Your reports, your litres and your level all come out of the store, so
        // this redraws when the store moves rather than when the tab is rebuilt.
        valueListenable: Store.revision,
        builder: (context, _, __) {
          final level = levelOf(Store.xp);
          final mine = Store.visible.where((l) => l.reporter == Store.userName).toList();

          final cards = <Widget>[
            _Profile(level),
            if (!Store.joined) _JoinCard(),
            _Levels(level.name),
            const _Badges(),
          ];
          return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 152),
      children: [
        Row(
          children: [
            const SizedBox(width: 46),
            Expanded(child: Center(child: Text('Account', style: A.h2))),
            ClayIcon(
              Icons.settings_outlined,
              onTap: () => Navigator.of(context).push(
                A.route(const SettingsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < cards.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Pop(cards[i], index: i),
          ),
        SectionHead('Your reports · ${mine.length}'),
        if (mine.isEmpty)
          const EmptyState(Icons.water_drop_outlined, 'Nothing yet',
              'The leaks you report show up here with what they saved.')
        else
          for (final l in mine) ...[
            LeakCard(l,
                heroTag: 'mine-${l.id}',
                onTap: () => Navigator.of(context).push(
                      A.route(LeakDetailScreen(l, heroTag: 'mine-${l.id}')),
                    )),
            const SizedBox(height: 12),
          ],
      ],
            );
        },
      );
}

/// The optional half of AquaAlert, offered rather than demanded: a code adds an
/// institution's board and events, and nothing else changes.
class _JoinCard extends StatefulWidget {
  @override
  State<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends State<_JoinCard> {
  @override
  Widget build(BuildContext context) => ClayCard(
        onTap: () async {
          if (await joinSheet(context) && mounted) setState(() {});
        },
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        child: Row(
          children: [
            const Medallion(Icons.group_add_rounded, size: 46),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join a school or college', style: A.h3),
                  const SizedBox(height: 2),
                  Text('Optional. Adds its leaderboard and its events.', style: A.tiny),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
          ],
        ),
      );
}

class _Profile extends StatelessWidget {
  const _Profile(this.level);
  final Level level;

  @override
  Widget build(BuildContext context) => ClayCard(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          children: [
            RingAvatar(InitialsAvatar.of(Store.fullName), level.progress, size: 108),
            const SizedBox(height: 14),
            Text(Store.fullName, style: A.h1.copyWith(fontSize: 26)),
            const SizedBox(height: 2),
            Text('${level.name} · ${Store.userLine}', style: A.bodySoft),
            const SizedBox(height: 6),
            Text(
              level.next == null
                  ? '${litres(Store.xp)} XP · top level'
                  : '${litres(Store.xp)} XP · ${level.span - level.into} XP to ${level.next}',
              style: A.label.copyWith(color: A.ink),
            ),
          ],
        ),
      );
}

/// The whole ladder as droplets, the one you are on ringed. Built from the
/// levels map, so adding a level adds a droplet here. The track fills and the
/// droplets land left to right the first time you open the tab — the ladder is
/// the one thing on this screen that is meant to feel climbed.
class _Levels extends StatelessWidget {
  const _Levels(this.current);
  final String current;

  @override
  Widget build(BuildContext context) {
    final names = levels.keys.toList();
    final at = names.indexOf(current);
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Levels', style: A.h3),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut,
            builder: (_, v, __) => Row(
              children: [
                for (var i = 0; i < names.length; i++)
                  // Each droplet gets its own slice of the run, so they arrive in
                  // order instead of all at once.
                  _rung(names, i, at, (v * (names.length + 1) - i).clamp(0.0, 1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rung(List<String> names, int i, int at, double p) => Expanded(
        child: Column(
          children: [
            // Half a track each side of the droplet, so the line meets its
            // neighbours without any measuring.
            Row(children: [
              _track(i > 0, i <= at ? p : 0),
              Transform.scale(scale: 0.7 + 0.3 * p, child: _drop(i, at)),
              _track(i < names.length - 1, i < at ? p : 0),
            ]),
            const SizedBox(height: 7),
            Opacity(
              opacity: p,
              child: Text(
                names[i],
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: A.tiny.copyWith(
                  fontSize: 9.5,
                  color: i <= at ? A.ink : A.inkSoft,
                  fontWeight: i == at ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _track(bool show, double fill) => Expanded(
        child: SizedBox(
          height: 2.5,
          child: !show
              ? null
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: A.ink.withValues(alpha: 0.09)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fill,
                      child: const ColoredBox(color: A.accent),
                    ),
                  ],
                ),
        ),
      );

  /// A droplet, not a dot: the levels are the water cycle and the mockup draws
  /// them as drops. The one you are on is ringed.
  Widget _drop(int i, int at) => SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(painter: _Drop(reached: i <= at, here: i == at)),
      );
}

/// What you have earned. Round clay medallions with the name under them, and the
/// newest one standing in its own pool of cyan light — the NEW pill that used to
/// hang off that corner collided with the tile beside it and shoved its medallion
/// off the grid, which is what made this whole card look crooked.
class _Badges extends StatelessWidget {
  const _Badges();

  @override
  Widget build(BuildContext context) {
    final earned = Store.badges.where((b) => b.earned).toList();
    // The list is authored earned-first, so the last earned entry is the most
    // recent one. No timestamps in the mock data to sort by.
    final newest = earned.isEmpty ? null : earned.last;
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Badges', style: A.h3)),
              Text('${earned.length} of ${Store.badges.length}', style: A.bodySoft),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // A cell only has to hold a 54px disc and two short lines. The old
            // 0.82 left 40px of dead air under every row.
            childAspectRatio: 1.06,
            mainAxisSpacing: 18,
            crossAxisSpacing: 10,
            children: [
              for (var i = 0; i < Store.badges.length; i++)
                Pop(
                  index: i,
                  from: 10,
                  _BadgeTile(Store.badges[i], fresh: Store.badges[i] == newest),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile(this.badge, {this.fresh = false});
  final Award badge;
  final bool fresh;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => claySheet<void>(context, _BadgeSheet(badge, fresh: fresh)),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (fresh)
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            A.accent.withValues(alpha: 0.28),
                            A.accent.withValues(alpha: 0),
                          ],
                          stops: const [0.55, 1],
                        ),
                      ),
                    ),
                  Medallion(
                    badge.earned ? badge.icon : Icons.lock_outline_rounded,
                    size: 54,
                    earned: badge.earned,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            // Expanded, so the cell's height is fixed by the grid and the label
            // fits itself into what is left. A label that sets its own height
            // overflows the moment a font measures wider than expected.
            Expanded(
              child: Text(
                badge.name,
                style: A.tiny.copyWith(
                  fontSize: 11,
                  height: 1.15,
                  color: fresh
                      ? A.accentDeep
                      : badge.earned
                          ? A.ink
                          : A.inkSoft,
                  fontWeight: badge.earned ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

/// The badge, opened. The medallion springs in over its own pool of light — that
/// is the reward — and everything under it settles a beat later, so the sheet
/// arrives as one movement instead of a block of text appearing.
class _BadgeSheet extends StatefulWidget {
  const _BadgeSheet(this.badge, {this.fresh = false});
  final Award badge;
  final bool fresh;

  @override
  State<_BadgeSheet> createState() => _BadgeSheetState();
}

class _BadgeSheetState extends State<_BadgeSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    final glow = b.earned ? A.accent : A.inkSoft;
    final pop = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    final settle = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
    );
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetGrip(),
          AnimatedBuilder(
            animation: pop,
            builder: (_, child) => Transform.scale(scale: 0.55 + 0.45 * pop.value, child: child),
            child: SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [glow.withValues(alpha: 0.22), glow.withValues(alpha: 0)],
                        stops: const [0.48, 1],
                      ),
                    ),
                  ),
                  Medallion(
                    b.earned ? b.icon : Icons.lock_outline_rounded,
                    size: 84,
                    earned: b.earned,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FadeTransition(
            opacity: settle,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(settle),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(b.name, style: A.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 7),
                  Text(b.how, style: A.bodySoft, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.fresh) ...[
                        const ClayPill('Just earned',
                            color: A.accent, icon: Icons.auto_awesome_rounded),
                        const SizedBox(width: 8),
                      ],
                      ClayPill(
                        b.earned ? 'Earned' : 'Not yet',
                        color: b.earned ? A.green : A.inkSoft,
                        icon: b.earned ? Icons.check_rounded : Icons.lock_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClayButton(
                    label: 'Close',
                    secondary: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One level's droplet: cyan once reached, ringed while you stand on it.
class _Drop extends CustomPainter {
  const _Drop({required this.reached, required this.here});
  final bool reached, here;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const h = 21.0, w = 15.0;
    final t = c - const Offset(0, h * 0.52);
    final drop = Path()
      ..moveTo(t.dx, t.dy)
      ..cubicTo(t.dx + w * 0.52, t.dy + h * 0.44, t.dx + w * 0.52, t.dy + h * 0.66,
          t.dx + w * 0.52, t.dy + h * 0.68)
      ..arcToPoint(Offset(t.dx - w * 0.52, t.dy + h * 0.68),
          radius: const Radius.circular(w * 0.52))
      ..cubicTo(t.dx - w * 0.52, t.dy + h * 0.66, t.dx - w * 0.52, t.dy + h * 0.44, t.dx, t.dy)
      ..close();
    canvas.drawPath(
      drop.shift(const Offset(1, 1.5)),
      Paint()..color = A.ink.withValues(alpha: reached ? 0.13 : 0.06),
    );
    canvas.drawPath(drop, Paint()..color = reached ? A.accent : const Color(0xFFE3E9F0));
    if (reached) {
      canvas.drawOval(
        Rect.fromCenter(center: c - const Offset(2.5, 3), width: 5, height: 3.4),
        Paint()..color = Colors.white.withValues(alpha: 0.65),
      );
    }
    if (here) {
      canvas.drawCircle(
        c,
        size.shortestSide / 2 - 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = A.ink.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(_Drop old) => old.reached != reached || old.here != here;
}
