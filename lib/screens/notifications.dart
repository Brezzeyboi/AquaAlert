import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import 'leak_detail.dart';

/// Unread notifications are frosted glass, read ones are plain clay. That is
/// the whole read/unread language — no dots, no counters, no bold text.
///
/// The count itself belongs to the store: the bell in the nav bar draws a dot
/// from the same number, and while this screen owned it privately, marking
/// everything read here left that dot lit.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Store.revision,
        builder: (context, _, __) {
          // Only what this account is allowed to read, and only the kinds it asked
          // for in settings: a notice about a report inside a school never reaches
          // somebody outside it.
          final feed = Store.feed;
          final unread = Store.unread;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 152),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Notifications', style: A.h1)),
                  if (unread > 0)
                    GestureDetector(
                      onTap: Store.readAll,
                      child: Text('Mark all read',
                          style: A.label
                              .copyWith(color: A.accentDeep, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (feed.isEmpty)
                const EmptyState(Icons.notifications_none_rounded, 'All quiet',
                    'You will hear from us when a report you follow changes.')
              else
                for (var i = 0; i < feed.length; i++) ...[
                  // Staggered in, like every other list in the app.
                  Pop(_Card(feed[i], unread: i < unread), index: i),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      );
}

class _Card extends StatelessWidget {
  const _Card(this.n, {required this.unread});
  final Notif n;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One matte disc per row, in the status's own colour. The rayed alert
          // badge belonged to a full-screen moment — at 34px in a list it read as
          // a cartoon sun next to four clean discs.
          Medallion(n.status.icon, size: 34, color: n.status.color),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(n.title, style: A.h3)),
                    if (unread) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration:
                            const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(n.ago, style: A.tiny),
                  ],
                ),
                const SizedBox(height: 4),
                Text(n.body, style: A.bodySoft.copyWith(fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );

    // Marking all read turns glass into clay, so it cross-fades rather than
    // snapping — the whole read/unread language is that one change of material.
    final card = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: KeyedSubtree(
        key: ValueKey(unread),
        child: unread
            // Liquid glass, used here and on the nav bar only.
            ? ClipRRect(
                borderRadius: BorderRadius.circular(A.rCard),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(A.rCard),
                      // Brighter than a read card, not duller: unread is the one
                      // that wants your eye, and 0.55 over this surface read grey.
                      color: Colors.white.withValues(alpha: 0.78),
                      border: Border.all(color: A.accent.withValues(alpha: 0.45), width: 1.4),
                      boxShadow: A.clay(d: 0.8),
                    ),
                    child: body,
                  ),
                ),
              )
            : ClayCard(padding: EdgeInsets.zero, child: body),
      ),
    );

    // A notice about a report opens that report. One about the event has nowhere
    // to go, so it does not pretend to be tappable.
    final leak = Store.visible.where((l) => l.id == n.leak).firstOrNull;
    if (leak == null) return card;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        A.route(LeakDetailScreen(leak)),
      ),
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}
