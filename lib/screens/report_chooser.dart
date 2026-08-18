import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import 'report_form.dart';

/// The + button. Community sits on top because it is the everyday action; the
/// institution is a single compact row underneath. Nothing on this screen
/// explains scoring, and nothing on it lists examples — a child who has seen a
/// leak does not need to be told what a leak looks like.
class ReportChooser extends StatelessWidget {
  const ReportChooser({super.key});

  void _open(BuildContext context, Scope scope) => Navigator.of(context).push(
        A.route(ReportForm(scope: scope)),
      );

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
                  ClayIcon(Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                  Expanded(child: Center(child: Text('New report', style: A.h3))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Center(child: Text('Where is the leak?', style: A.h1.copyWith(fontSize: 32))),
                  const SizedBox(height: 22),
                  ClayCard(
                    onTap: () => _open(context, Scope.community),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Medallion(Icons.place_rounded, size: 74, color: A.accentDeep),
                        const SizedBox(height: 18),
                        Text('Anywhere around you', style: A.h1.copyWith(fontSize: 25)),
                        const SizedBox(height: 6),
                        Text('Out of school, on your street, on your way home.',
                            style: A.bodySoft.copyWith(fontSize: 16)),
                        const SizedBox(height: 16),
                        const _Can(Icons.photo_camera_rounded, 'Add a photo'),
                        const SizedBox(height: 9),
                        const _Can(Icons.my_location_rounded,
                            'Use my location or type the address'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Only somebody who joined an institution has an inside to
                  // report from; everyone else already has what they need above.
                  if (Store.joined)
                    ClayCard(
                      onTap: () => _open(context, Store.institutionScope),
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                      child: Row(
                        children: [
                          const Medallion(Icons.school_rounded, size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Store.shortName, style: A.h3),
                                const SizedBox(height: 2),
                                // The reason this route exists at all: it stays
                                // inside, and the office is who can act on it.
                                Text('Only your school sees it · the office fixes it',
                                    style: A.tiny),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
                        ],
                      ),
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

/// What this route lets you do, stated as an affordance rather than as an
/// example of a leak.
class _Can extends StatelessWidget {
  const _Can(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: A.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: A.body.copyWith(fontWeight: FontWeight.w500))),
        ],
      );
}
