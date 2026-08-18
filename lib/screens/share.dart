import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';

/// A standard household bucket. Kept here as a named constant because the share
/// card states it as a fact, and a judge is entitled to ask where it came from.
// TODO(citation): source this figure before the submission.
const bucketLitres = 15;

/// The card that leaves the app. One leak, its picture, what it is costing and
/// the tagline — it has to make sense to somebody who has never heard of
/// AquaAlert and is looking at it in a chat list.
class ShareScreen extends StatelessWidget {
  const ShareScreen(this.leak, {super.key});
  final Leak leak;

  @override
  Widget build(BuildContext context) {
    final total = leak.litresPerDay * leak.daysOpen;
    final perHour = (leak.litresPerDay / 24).round();
    final buckets = total ~/ bucketLitres;
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
                  const SizedBox(width: 14),
                  Text('Share this leak', style: A.h2),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  ClayCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Logomark(size: 34),
                            const SizedBox(width: 10),
                            Text('AquaAlert', style: A.h2.copyWith(fontSize: 23)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _Shot(leak),
                        const SizedBox(height: 16),
                        Text(leak.title, style: A.h1.copyWith(fontSize: 25)),
                        const SizedBox(height: 4),
                        Text(
                          leak.status == Status.fixed
                              ? 'Reported ${leak.daysOpen} days ago, now fixed'
                              : 'Reported ${leak.daysOpen} days ago, still leaking',
                          style: A.bodySoft,
                        ),
                        const SizedBox(height: 16),
                        ClayWell(
                          radius: 22,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              _Big(litres(total), 'WASTED SO FAR'),
                              Container(width: 1, height: 44, color: A.ink.withValues(alpha: 0.08)),
                              _Big('$perHour', 'EVERY HOUR'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.water_drop_rounded, size: 17, color: A.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('That is $buckets buckets of drinking water.',
                                  style: A.body.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text('Spot the Leak. Save the Water.',
                              style: A.h3.copyWith(fontSize: 16)),
                        ),
                        const SizedBox(height: 3),
                        Center(child: Text('Reported on AquaAlert · SDG 6', style: A.tiny)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // TODO(share_plus): render this card to an image and hand it over.
                  ClayButton(label: 'Share', icon: Icons.ios_share_rounded, onTap: () {}),
                  const SizedBox(height: 12),
                  Center(child: Text('Nothing about you is included.', style: A.tiny)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo with the status stamped on it, because the card is read at
/// thumbnail size and the pill is the only part that survives.
class _Shot extends StatelessWidget {
  const _Shot(this.leak);
  final Leak leak;

  @override
  Widget build(BuildContext context) {
    final photo = leak.photo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          if (photo != null)
            AspectRatio(aspectRatio: 16 / 9, child: Image.asset(photo, fit: BoxFit.cover))
          else
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: A.sunk,
                child: Icon(Icons.water_damage_outlined, size: 40, color: A.inkSoft),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: ClayPill('${leak.status.label} · ${leak.daysOpen} days',
                color: leak.status.color, icon: leak.status.icon),
          ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: A.figure(30)),
                const SizedBox(width: 4),
                Text('L', style: A.h3.copyWith(fontSize: 19)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: A.tiny.copyWith(fontSize: 10, letterSpacing: 1.1)),
          ],
        ),
      );
}
