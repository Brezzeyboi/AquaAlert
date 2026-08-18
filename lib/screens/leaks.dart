import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import '../widgets/leak_card.dart';
import 'leak_detail.dart';
import 'map.dart';

/// Every report you are allowed to see. This is also the fixer's queue — the
/// same list with the buttons switched on, because a second screen holding the
/// same rows is a second screen to keep in step.
class LeaksScreen extends StatefulWidget {
  const LeaksScreen({super.key});

  @override
  State<LeaksScreen> createState() => _LeaksScreenState();
}

/// Null is "everything". Overdue is a slice of open, so it gets its own filter
/// rather than hiding inside one.
const _filters = <(String, Status?, Color)>[
  ('All', null, A.accent),
  ('Open', Status.reported, A.accent),
  ('Overdue', Status.overdue, A.amber),
  ('Fixed', Status.fixed, A.green),
];

class _LeaksScreenState extends State<LeaksScreen> {
  int _filter = 0;
  bool _worstFirst = true;

  List<Leak> get _shown {
    final want = _filters[_filter].$2;
    final list = Store.visible.where((l) => switch (want) {
          null => true,
          // "Open" means anything not fixed, or the tab would hide the leaks
          // that are already being worked on.
          Status.reported => l.status != Status.fixed,
          final s => l.status == s,
        }).toList();
    // Still leaking always outranks already fixed, whatever the volumes are.
    int open(Leak l) => l.status == Status.fixed ? 1 : 0;
    list.sort((a, b) {
      final byState = open(a) - open(b);
      if (byState != 0) return byState;
      // "Worst" is how fast it is running, not how much it has already wasted.
      // Ranking by cumulative waste buried every fresh report at the bottom of
      // the list — a report filed a minute ago has wasted nothing yet, which is
      // exactly when somebody goes looking for it.
      return _worstFirst ? b.litresPerDay - a.litresPerDay : a.daysOpen - b.daysOpen;
    });
    return list;
  }

  /// Nothing to fetch — the store is in memory — so a pull re-reads it and
  /// re-sorts. The gesture is still worth having: it is how anyone checks a list.
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() {});
  }

  /// Move a report from this list. No local setState: the list is built inside the
  /// store's revision listener like every other list, so announcing the change is
  /// what redraws it — and every other screen with it.
  void _set(Leak l, Status s) {
    final wasOpen = l.status != Status.fixed;
    l.status = s;
    // Closing it here has to credit the litres exactly as closing it on the
    // detail screen does, or the tank only moves on one of the two paths.
    if (s == Status.fixed && wasOpen) Store.credit(l);
    Store.touch();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        // Rebuilt whenever the store moves. The tabs stay alive in an
        // IndexedStack, so without this a report filed from the + is missing here
        // until something else happens to rebuild the list.
        valueListenable: Store.revision,
        builder: (context, _, __) {
          final shown = _shown;
          return DropletRefresh(
            onRefresh: _refresh,
            child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 152),
      children: [
        Row(
          children: [
            Expanded(child: Text('Reports', style: A.h1)),
            // The badge only shows for an account that really can close other
            // people's reports.
            if (Store.isFixer) const ClayPill('Fixer', icon: Icons.build_rounded),
            const SizedBox(width: 8),
            // The same reports, on the map. A list answers "how bad"; a map
            // answers "where", and that is the question a second reporter has.
            ClayIcon(
              Icons.map_rounded,
              size: 42,
              onTap: () => Navigator.of(context).push(A.route(const MapScreen())),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Unclipped: a scroll view cuts everything at its own edge, and
                // what got cut here was the chips' own light and shade — which read
                // as a band of slightly different background behind the row.
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (var i = 0; i < _filters.length; i++) ...[
                      ClayChip(
                        _filters[i].$1,
                        selected: i == _filter,
                        color: _filters[i].$3,
                        onTap: () => setState(() => _filter = i),
                      ),
                      const SizedBox(width: 9),
                    ],
                  ],
                ),
              ),
            ),
            ClayIcon(
              _worstFirst ? Icons.sort_rounded : Icons.schedule_rounded,
              size: 42,
              onTap: () => setState(() => _worstFirst = !_worstFirst),
            ),
          ],
        ),
        const SizedBox(height: 13),
        // In a Pop like everything else, which also keeps it alive while it is
        // scrolled off — otherwise the three counts recount from zero every time
        // it comes back on screen.
        Pop(
          index: 1,
          StatStrip([
            (Store.openCount, 'Open', A.ink),
            (Store.overdueCount, 'Overdue', A.amber),
            (Store.fixedCount, 'Fixed', A.green),
          ]),
        ),
        const SizedBox(height: 14),
        Text(_worstFirst ? 'Worst leak first' : 'Newest first', style: A.tiny),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          EmptyState(
            Icons.water_drop_outlined,
            'Nothing here',
            _filter == 0
                ? 'Be the first to report a leak near you.'
                : 'No ${_filters[_filter].$1.toLowerCase()} reports right now.',
          )
        else
          for (final l in shown) ...[
            Pop(
              // Keyed by the filter as well as the row, so switching tabs
              // re-runs the cascade instead of swapping the rows in silently.
              key: ValueKey('$_filter-$_worstFirst-${l.id}'),
              index: shown.indexOf(l),
              LeakCard(
              l,
              heroTag: 'list-${l.id}',
              onTap: () async {
                await Navigator.of(context).push(
                  A.route(LeakDetailScreen(l, heroTag: 'list-${l.id}')),
                );
                setState(() {}); // its status may have changed in there
              },
              // Your own report, or a fixer's queue: either way, only while
              // there is still something to move.
              actions: Store.canClose(l) && l.status != Status.fixed
                  ? Row(
                      children: [
                        // Starting work is a fixer's word, not a reporter's.
                        if (Store.isFixer && l.status != Status.inProgress) ...[
                          Expanded(
                            child: _Action('Start', Icons.build_rounded, A.accentDeep,
                                () => _set(l, Status.inProgress)),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _Action('Mark fixed', Icons.check_rounded, A.green,
                              () => _set(l, Status.fixed)),
                        ),
                      ],
                    )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
              ),
            );
          },
        );
}

/// A small clay chip, not a ClayButton — a full cyan bar inside a card would
/// outshout the report it belongs to.
class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClayCard(
        onTap: onTap,
        radius: A.rPill,
        padding: const EdgeInsets.symmetric(vertical: 11),
        color: Color.lerp(A.card, color, 0.13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Color.lerp(color, A.ink, 0.25)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: A.h3.copyWith(fontSize: 14.5, color: Color.lerp(color, A.ink, 0.25))),
            ),
          ],
        ),
      );
}
