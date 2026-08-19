import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/mock.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';

/// A standard household bucket. Kept here as a named constant because the share
/// card states it as a fact, and a judge is entitled to ask where it came from.
// TODO(citation): source this figure before the submission.
const bucketLitres = 15;

/// The same card as plain text. It has to stand on its own in a chat list, so it
/// names the place and what the leak costs and nothing about whoever sent it.
String _asText(Leak leak, int total, int perHour) {
  final fixed = leak.status == Status.fixed;
  return '''
${leak.title} — ${leak.place}
$perHour L every hour · ${litres(total)} L ${fixed ? 'saved by fixing it' : 'wasted so far'}
${fixed ? 'Now fixed.' : 'Reported ${leak.daysOpen} days ago, still leaking.'}

Spot the Leak. Save the Water. — AquaAlert, for SDG 6''';
}

/// The phone's own share sheet, over one method channel to an ACTION_SEND in
/// MainActivity. No plugin and no Gradle change for an intent that has not
/// changed since Android 1 — and it is the sheet every phone already knows,
/// rather than an app-shaped imitation of one.
const _sheet = MethodChannel('aquaalert/share');

/// The card itself, as a PNG. Flutter can hand back the pixels of anything it has
/// already painted, so what leaves the app is the card on the screen rather than a
/// second description of it built for the purpose.
Future<Uint8List?> _cardPng(GlobalKey key) async {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderRepaintBoundary) return null;
  // 3x, so it is still sharp when a chat app blows it up on a big screen.
  final shot = await box.toImage(pixelRatio: 3);
  final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
  shot.dispose();
  return bytes?.buffer.asUint8List();
}

/// Hands the leak to whatever the person picks: the card as a picture, the same
/// words beside it. Falls back to text, and then to the clipboard — on a desktop or
/// test build the channel is not there at all, and the words still have to be able
/// to get out.
Future<void> _send(BuildContext context, GlobalKey card, String text, String subject) async {
  final png = await _cardPng(card);
  try {
    if (png != null) {
      await _sheet.invokeMethod<void>(
          'image', {'png': png, 'text': text, 'subject': subject});
    } else {
      await _sheet.invokeMethod<void>('text', {'text': text, 'subject': subject});
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showClayToast(context, 'Copied. Paste it into any chat.');
  }
}

/// The card that leaves the app. One leak, its picture, what it is costing and
/// the tagline — it has to make sense to somebody who has never heard of
/// AquaAlert and is looking at it in a chat list.
class ShareScreen extends StatelessWidget {
  ShareScreen(this.leak, {super.key});
  final Leak leak;

  /// Marks the card for the camera. Held by the widget rather than by a State
  /// because this screen is a pushed route: it is built once and never rebuilt
  /// from above, so there is no second key to collide with.
  final _card = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final total = leak.litresPerDay * leak.daysOpen;
    final perHour = (leak.litresPerDay / 24).round();
    final buckets = total ~/ bucketLitres;
    // A fixed leak's figure is not a loss any more, and the detail screen already
    // says so — a card that still calls it wasted contradicts the app it came from.
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
                  const SizedBox(width: 14),
                  Text('Share this leak', style: A.h2),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  // The boundary is what makes the card photographable, and it is
                  // wrapped in the app's own surface: a card cut out with nothing
                  // behind it arrives in a chat with a transparent border, which
                  // every chat app fills with black.
                  RepaintBoundary(
                    key: _card,
                    child: ColoredBox(
                      color: A.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ClayCard(
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
                              _Big(litres(total),
                                  fixed ? 'SAVED BY FIXING IT' : 'WASTED SO FAR'),
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
                              child: Text(
                                  'That is $buckets buckets of drinking water'
                                  '${fixed ? ' saved' : ''}.',
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClayButton(
                    label: 'Share',
                    icon: Icons.ios_share_rounded,
                    onTap: () =>
                        _send(context, _card, _asText(leak, total, perHour), leak.title),
                  ),
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
            // Backed by something opaque. A pill's own fill is a 15% tint of its
            // status colour, which is right on the app's surface and an illegible
            // smear over a photograph — and this stamp is the part of the card that
            // has to survive being read at thumbnail size in a chat list.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(A.rPill),
              child: ColoredBox(
                color: A.surface,
                child: ClayPill('${leak.status.label} · ${leak.daysOpen} days',
                    color: leak.status.color, icon: leak.status.icon),
              ),
            ),
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
