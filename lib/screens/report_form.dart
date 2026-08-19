import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';

/// One form for all three scopes, and the three pills at the top switch between
/// them — the scope decides which fields exist, not which screen you are on.
class ReportForm extends StatefulWidget {
  const ReportForm({super.key, required this.scope});
  final Scope scope;

  @override
  State<ReportForm> createState() => _ReportFormState();
}

/// Chips, per scope. Short lists on purpose: a child picking from five things is
/// reporting, a child picking from twenty is filling in a form.
const _rooms = ['Washroom', 'Corridor', 'Canteen', 'Playground', 'Water cooler'];
const _hostelRooms = ['Washroom', 'Corridor', 'Hostel', 'Library', 'Canteen'];
const _campusKinds = [
  'Dripping tap',
  'Running tap',
  'Broken pipe',
  'Overflowing tank',
  'Water cooler',
  'Flush running',
  'Blocked drain',
  'Seepage on a wall',
];
const _streetKinds = [
  'Street pipe',
  'Public tap',
  'Hand pump',
  'Water tanker',
  'Valve chamber',
  'Rooftop tank',
  'Open drain',
  'Fire hydrant',
];

/// The stand-in for the camera, in the order the retry button walks them. The
/// picker is a TODO, so the reporter chooses a picture from these instead of the
/// app guessing one from what they tapped.
const demoShots = [
  'assets/demo/tap.jpg',
  'assets/demo/pipe.jpg',
  'assets/demo/valve.jpg',
  'assets/demo/handpump.jpg',
  'assets/demo/tank.jpg',
  'assets/demo/rooftop.jpg',
  'assets/demo/cooler.jpg',
  'assets/demo/street.jpg',
];

/// Severity in litres a day. The slider is the only place a child estimates a
/// number, so it estimates in words and this table turns words into litres.
// TODO(citation): the partner owes a sourced litres-per-leak table; these three
// anchors are placeholders until it lands.
const _rates = [60, 240, 900];

class _ReportFormState extends State<ReportForm> {
  /// Community leads, and the campus modes only exist for somebody who joined an
  /// institution — the same rule the chooser follows.
  late Scope _scope = Store.joined ? widget.scope : Scope.community;
  List<Scope> get _scopes =>
      [Scope.community, if (Store.joined) Store.institutionScope];
  final _where = TextEditingController();
  final _note = TextEditingController();
  String? _room, _kind;
  double _severity = 0.5;
  bool _located = false;
  bool _photo = false;

  /// Which stand-in photo is showing. The retry button moves it on.
  int _shot = 0;
  String get _photoPath => demoShots[_shot % demoShots.length];

  bool get _campus => _scope != Scope.community;

  /// No camera inside a building, school or college alike: a picture taken in
  /// there is a picture of the place and the people in it. [Leak.photo] enforces
  /// the same rule on the data, so this is only about not asking for something
  /// that would be dropped.
  bool get _canPhoto => !_campus;
  bool get _canSend =>
      _kind != null && (_campus ? _where.text.trim().isNotEmpty || _room != null : _located || _where.text.trim().isNotEmpty);

  /// Litres a day at the current slider position, interpolated between the three
  /// anchors so the readout moves with the thumb.
  int get _litres {
    final t = _severity.clamp(0.0, 1.0) * 2;
    final i = t.floor().clamp(0, 1);
    return (_rates[i] + (_rates[i + 1] - _rates[i]) * (t - i)).round();
  }

  @override
  void dispose() {
    _where.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Files the report into the in-memory store, then shows the moment. It has to
  /// land somewhere before the dialog appears — a demo where you file a report
  /// and the list does not change is a demo of nothing.
  void _send() {
    Store.file(
      scope: _scope,
      title: _kind ?? 'Leak',
      place: _campus
          ? [_room, _where.text.trim()].where((p) => p != null && p.isNotEmpty).join(', ')
          : (_where.text.trim().isEmpty ? 'Near me' : _where.text.trim()),
      litresPerDay: _litres,
      description: _note.text.trim(),
      photo: _photo ? _photoPath : null,
      lat: _located ? 28.6139 : null,
      lng: _located ? 77.2090 : null,
    );
    showDialog<void>(
      context: context,
      barrierColor: A.ink.withValues(alpha: 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: _Sent(scope: _scope, litresPerDay: _litres),
      ),
    );
  }

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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Report a leak',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: A.h1.copyWith(fontSize: 25)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  if (_scopes.length > 1) ...[
                    Row(
                      children: [
                        for (final s in _scopes) ...[
                          Expanded(
                            child: ClayChip(
                              switch (s) {
                                Scope.school => 'School',
                                Scope.college => 'College',
                                Scope.community => 'Community',
                              },
                              selected: s == _scope,
                              onTap: () => setState(() {
                                _scope = s;
                                _room = null;
                                _kind = null;
                              }),
                            ),
                          ),
                          if (s != _scopes.last) const SizedBox(width: 9),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_campus) ...[
                    _Note(
                        _scope == Scope.school
                            ? 'Only your school sees this one'
                            : 'Only your college sees this one',
                        'It goes to ${Store.shortName} — its students and its office, '
                            'nobody outside. Photos are off inside the building, so use '
                            'words.'),
                    const SizedBox(height: 14),
                  ],
                  if (_canPhoto) ...[
                    _PhotoCard(
                      taken: _photo,
                      photo: _photoPath,
                      // TODO(image_picker): wire the camera once the plugin is added.
                      onTap: () => setState(() => _photo = true),
                      onNext: () => setState(() => _shot++),
                      onClear: () => setState(() {
                        _photo = false;
                        _shot = 0;
                      }),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _Group(
                    'Type of leak',
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final k in _campus ? _campusKinds : _streetKinds)
                          ClayChip(k,
                              selected: k == _kind, onTap: () => setState(() => _kind = k)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_campus)
                    _Group(
                      'Where is it?',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: [
                              for (final r in _scope == Scope.college ? _hostelRooms : _rooms)
                                ClayChip(r,
                                    selected: r == _room, onTap: () => setState(() => _room = r)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _Input(_where, 'Block and floor', onChanged: () => setState(() {})),
                        ],
                      ),
                    )
                  else
                    _Group('Where is it?', _Location(
                      located: _located,
                      controller: _where,
                      onLocate: () => setState(() => _located = true),
                      onChanged: () => setState(() {}),
                    )),
                  const SizedBox(height: 14),
                  _Group(
                    'How bad is it?',
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Slow to gushing', style: A.tiny)),
                            Text('about ${litres(_litres)} L a day',
                                style: A.label.copyWith(color: A.accentDeep)),
                          ],
                        ),
                        _Severity(_severity, (v) => setState(() => _severity = v)),
                        Row(
                          children: [
                            Expanded(child: Text('Slow', style: A.tiny)),
                            Text('Steady', style: A.tiny),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text('Gushing', style: A.tiny),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Group('Describe it', _Input(_note, 'How long it has been running', lines: 4)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      InitialsAvatar(Store.fullName, size: 38),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          _campus
                              ? 'Everyone in your school can see it'
                              : 'Everyone on AquaAlert can see this one — that is the point',
                          style: A.tiny,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClayButton(
                    label: 'Send report',
                    icon: Icons.send_rounded,
                    onTap: _canSend ? _send : null,
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

/// A labelled group: the mockups wrap every field in its own card with the label
/// inside it, which is what keeps a long form from reading as a wall.
class _Group extends StatelessWidget {
  const _Group(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClayCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: A.h3.copyWith(fontSize: 15.5)),
            const SizedBox(height: 11),
            child,
          ],
        ),
      );
}

/// The cyan-tinted note card: a fact about the mode you are in, never a warning.
class _Note extends StatelessWidget {
  const _Note(this.title, this.body);
  final String title, body;

  @override
  Widget build(BuildContext context) => ClayCard(
        color: A.tint(A.accent, 0.88),
        padding: const EdgeInsets.fromLTRB(14, 13, 16, 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: A.ink, shape: BoxShape.circle),
              child: const Icon(Icons.info_outline_rounded, size: 19, color: Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: A.h3.copyWith(fontSize: 15.5)),
                  const SizedBox(height: 1),
                  Text(body, style: A.tiny),
                ],
              ),
            ),
          ],
        ),
      );
}

/// One text row, sunk into the card it lives in.
class _Input extends StatelessWidget {
  const _Input(this.controller, this.hint, {this.lines = 1, this.onChanged});
  final TextEditingController controller;
  final String hint;
  final int lines;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => ClayWell(
        radius: lines > 1 ? A.rField : A.rPill,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: TextField(
          controller: controller,
          maxLines: lines,
          onChanged: (_) => onChanged?.call(),
          style: A.body,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: A.bodySoft.copyWith(color: A.inkSoft.withValues(alpha: 0.6)),
          ),
        ),
      );
}

/// The photo slot. Tapping stands in for the camera until image_picker is
/// wired; when there is a picture it shows with the camera button on top of it,
/// exactly as the community mockup draws it.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.taken,
    required this.photo,
    required this.onTap,
    required this.onNext,
    required this.onClear,
  });
  final bool taken;

  /// The picture showing right now.
  final String photo;

  /// Take one, walk to the next one, or throw it away.
  final VoidCallback onTap, onNext, onClear;

  @override
  Widget build(BuildContext context) => ClayCard(
        padding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: taken
                    ? Image.asset(photo, fit: BoxFit.cover)
                    : ColoredBox(
                        color: A.sunk,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.photo_camera_rounded, size: 30, color: A.inkSoft),
                            const SizedBox(height: 8),
                            Text('Add a photo', style: A.label),
                          ],
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: GestureDetector(
                onTap: taken ? onNext : onTap,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: A.clay(d: 0.6),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6FD3EE), A.accent],
                    ),
                  ),
                  child: Icon(taken ? Icons.refresh_rounded : Icons.photo_camera_rounded,
                      size: 24, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Where a community report is. The map tile appears once there is a fix, and
/// the address stays editable either way — a pin is not an address.
class _Location extends StatelessWidget {
  const _Location({
    required this.located,
    required this.controller,
    required this.onLocate,
    required this.onChanged,
  });
  final bool located;
  final TextEditingController controller;
  final VoidCallback onLocate, onChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              if (located) ...[
                const MapTile(28.6139, 77.2090, width: 96, height: 62),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: onLocate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(A.rPill),
                      boxShadow: A.clay(d: 0.55),
                      color: located ? A.tint(A.accent, 0.8) : null,
                      gradient: located ? null : A.cardGrad(null),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(located ? Icons.check_rounded : Icons.my_location_rounded,
                            size: 18, color: A.ink),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(located ? 'Location added' : 'Use my current location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: A.h3.copyWith(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (located) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: A.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                // TODO(digipin): print the DIGIPIN here once the encoder is in —
                // a made-up code on a demo screen is worse than no code.
                Text('28.6139 N, 77.2090 E', style: A.mono(13, c: A.inkSoft)),
              ],
            ),
          ],
          const SizedBox(height: 11),
          _Input(controller, 'Address or landmark', onChanged: onChanged),
        ],
      );
}

/// The severity groove. Flutter's own slider inside a clay well: the theme does
/// the looks, so there is no drag maths here to get wrong.
class _Severity extends StatelessWidget {
  const _Severity(this.value, this.onChanged);
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => ClayWell(
        radius: A.rPill,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Slow, Steady, Gushing as three dots in the track, so the thumb has
            // something to sit against.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: A.inkSoft.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: A.accent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: A.accent,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ],
        ),
      );
}

/// The moment. Hand-lettered REPORTED!, a starburst, and the one number the
/// report is worth — the loudest screen in the app, and it lasts one tap.
class _Sent extends StatelessWidget {
  const _Sent({required this.scope, required this.litresPerDay});
  final Scope scope;
  final int litresPerDay;

  @override
  Widget build(BuildContext context) => GlassPanel(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -0.06,
              child: Text('REPORTED!',
                  style: A.figure(34).copyWith(fontStyle: FontStyle.italic, letterSpacing: -1)),
            ),
            const SizedBox(height: 10),
            Starburst(
              size: 148,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: A.clay(d: 0.7),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6FD3EE), A.accent],
                  ),
                ),
                child: const Icon(Icons.check_rounded, size: 42, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              scope == Scope.community
                  ? 'Everyone on AquaAlert can see it now.'
                  : 'Your school group can see it now.',
              style: A.body.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text('About ${litres(litresPerDay)} L a day until it is fixed.',
                style: A.bodySoft.copyWith(fontSize: 13.5), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ClayButton(
              label: 'Done',
              // Back to the shell, not to the chooser: the chooser is still on
              // the stack under the form, and popping twice left you staring at
              // "Where is the leak?" again after you had just answered it.
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ],
        ),
      );
}




