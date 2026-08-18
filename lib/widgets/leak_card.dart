import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../theme.dart';
import 'clay.dart';

/// One leak, everywhere it appears: dashboard, reports list, fixer queue. A row
/// with the photo doing the talking — the mockups lead with the picture, and a
/// school report that has no photo gets a clay tile with a line drawing so the
/// rows still line up.
class LeakCard extends StatelessWidget {
  const LeakCard(this.leak, {super.key, this.onTap, this.actions, this.heroTag});
  final Leak leak;
  final VoidCallback? onTap;

  /// Which list this row belongs to, so two live lists can both show the same
  /// report without their heroes clashing.
  final String? heroTag;

  /// The close/start row, for whoever may move this report. A resting card
  /// never carries actions.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final overdue = leak.status == Status.overdue;
    return ClayCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(A.rCard),
        child: Row(
          children: [
            // The edge only ever marks an overdue report — the one row state a
            // teacher should be able to spot without reading anything.
            if (overdue) Container(width: 6, color: A.amber),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LeakThumb(leak, heroTag: heroTag),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(leak.title,
                                  style: A.h3, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(leak.place,
                                  style: A.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              // Wrapped, because a school report wears two pills
                              // and a narrow phone has to be allowed to stack
                              // them rather than squeeze either one.
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ClayPill(leak.status.label,
                                      color: leak.status.color,
                                      icon: leak.status.icon,
                                      dense: true),
                                  if (leak.scopeTag != null)
                                    ClayPill(leak.scopeTag!,
                                        color: A.accentDeep,
                                        icon: Icons.lock_outline_rounded,
                                        dense: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
                      ],
                    ),
                    if (actions != null) ...[const SizedBox(height: 12), actions!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The report's picture at list size, or the tile that stands in for one.
class LeakThumb extends StatelessWidget {
  const LeakThumb(this.leak, {super.key, this.width = 96, this.height = 74, this.heroTag});
  final Leak leak;
  final double width, height;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final photo = leak.photo;
    if (photo == null) {
      return ClayWell(
        radius: 15,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: width,
          height: height,
          child: Icon(Icons.water_damage_outlined, size: height * 0.42, color: A.inkSoft),
        ),
      );
    }
    final tile = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: A.clay(d: 0.4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(photo, fit: BoxFit.cover),
        ),
      );
    // The same photo on the row and on the detail screen, so opening a report
    // grows the picture instead of cutting to it.
    return heroTag == null ? tile : Hero(tag: heroTag!, child: tile);
  }
}
