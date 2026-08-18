import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';

/// Everyone first: AquaAlert is a community app, so the board that matters sums
/// every report from every place. A school view sits behind it for the people
/// who joined one — a class beating another class is the interschool
/// competition, and it keeps no single child visibly last.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: Center(child: Text('Leaderboard', style: A.h2))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  if (Store.joined)
                    _Switch(
                      labels: const ['Everyone', 'Your school'],
                      value: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _tab == 1
                            ? '${Store.shortName} · this month'
                            : 'All of AquaAlert · this month',
                        style: A.tiny,
                      ),
                    ),
                  ),
                  if (_tab == 1)
                    for (var i = 0; i < Store.classes.length; i++) ...[
                      // Keyed by the tab, so flipping between the two boards
                      // re-runs the cascade instead of swapping rows in silently.
                      Pop(
                        key: ValueKey('school-$i'),
                        index: i,
                        _Row(
                          rank: i + 1,
                          name: Store.classes[i].name,
                          sub: '${Store.classes[i].students} students',
                          litres: Store.classes[i].litres,
                          mine: Store.classes[i].name == Store.userClass,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ]
                  else ...[
                    for (final s in Store.topSavers) ...[
                      Pop(
                        key: ValueKey('all-${s.rank}'),
                        index: s.rank - 1,
                        _Row(
                          rank: s.rank,
                          name: s.name,
                          sub: s.className,
                          litres: s.litres,
                          initials: InitialsAvatar.of(s.name),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // The gap between the named top three and your own row. The
                    // mockup marks it with three dots and so does this.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: A.inkSoft.withValues(alpha: 0.45),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Pop(
                      index: 4,
                      _Row(
                        rank: Store.you.rank,
                        name: Store.you.name,
                        sub: Store.userPlace,
                        litres: Store.you.litres,
                        initials: InitialsAvatar.of(Store.fullName),
                        mine: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Every litre counts the same, whether the leak was on a street or '
                      'inside a campus. Only the top three are named — everyone else sees '
                      'their own place and nobody else’s.',
                      style: A.bodySoft.copyWith(fontSize: 13.5),
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

/// Two halves in one groove, the chosen one a raised cyan pill.
class _Switch extends StatelessWidget {
  const _Switch({required this.labels, required this.value, required this.onChanged});
  final List<String> labels;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ClayWell(
        radius: A.rPill,
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(A.rPill),
                      boxShadow: i == value ? A.clay(d: 0.7) : null,
                      gradient: i == value
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6FD3EE), A.accent],
                            )
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: A.h3.copyWith(
                        fontSize: 15,
                        color: i == value ? Colors.white : A.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.name,
    required this.sub,
    required this.litres,
    this.initials,
    this.mine = false,
  });
  final int rank, litres;
  final String name, sub;

  /// Only a person gets an initials disc. "Class 10-B" reduced to letters is
  /// noise, so a class row carries its rank and nothing else.
  final String? initials;
  final bool mine;

  @override
  Widget build(BuildContext context) => ClayCard(
        padding: const EdgeInsets.fromLTRB(12, 11, 16, 11),
        color: mine ? A.tint(A.accent, 0.9) : null,
        outlined: mine,
        outline: A.accent,
        outlineWidth: 1.6,
        child: Row(
          children: [
            _Circle('$rank', filled: mine),
            const SizedBox(width: 9),
            if (initials != null) ...[
              _Circle(initials!, filled: mine),
              const SizedBox(width: 13),
            ] else
              const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: A.h3),
                  const SizedBox(height: 1),
                  Text(sub, style: A.tiny),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(litresOf(litres), style: A.figure(19)),
                const SizedBox(width: 3),
                Text('L', style: A.body),
              ],
            ),
          ],
        ),
      );
}

/// Rank and initials both ride in one of these: a raised disc, cyan when the row
/// is yours.
class _Circle extends StatelessWidget {
  const _Circle(this.text, {required this.filled});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: A.clay(d: 0.45),
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6FD3EE), A.accent],
                )
              : A.cardGrad(null),
        ),
        child: Text(text, style: A.figure(15, c: filled ? Colors.white : A.ink)),
      );
}

/// Litre counts on a leaderboard row are long; k for anything over 9,999 keeps
/// the row on one line without touching the exact figures elsewhere.
String litresOf(int n) => n >= 10000 ? '${(n / 1000).round()}k' : litres(n);
