import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';
import 'auth.dart' show AuthField;

/// Only switches that actually do something. A settings screen full of dead
/// toggles is the fastest way to lose a judge's trust — so the motion switch
/// really stops the tank reading the accelerometer, the vibration switch really
/// stops the taps buzzing, and the goal really moves the line in the glass.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The field inside the rename sheet. Owned by the screen, because disposing a
  /// controller as soon as claySheet returns kills it while the sheet is still
  /// animating out — the "A TextEditingController was used after being disposed"
  /// crash the join sheet had.
  final _nameField = TextEditingController();

  @override
  void dispose() {
    _nameField.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    _nameField.text = Store.fullName;
    await claySheet<void>(
      context,
      ClayCard(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SheetGrip()),
            Text('Your name', style: A.h2),
            const SizedBox(height: 4),
            Text('What the app calls you, and what your reports are signed with.',
                style: A.tiny),
            const SizedBox(height: 14),
            AuthField(
              controller: _nameField,
              icon: Icons.person_outline_rounded,
              hint: 'Your name',
              caps: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            ClayButton(
              label: 'Save',
              onTap: () {
                setState(() => Store.rename(_nameField.text));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// One sheet for the rows that exist to tell you something — privacy, storage,
  /// about. The content is the function: a chevron that opens nothing is the part
  /// a judge notices.
  Future<void> _tell(String title, List<String> lines) => claySheet<void>(
        context,
        ClayCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetGrip()),
              Text(title, style: A.h2),
              const SizedBox(height: 12),
              for (final line in lines) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 5, color: A.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(line, style: A.bodySoft.copyWith(fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 9),
              ],
              const SizedBox(height: 8),
              ClayButton(
                label: 'Got it',
                secondary: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );

  /// Signing out drops the whole session, so it asks first. Everything above the
  /// gate goes with it — the settings screen this button lives on included, which
  /// is why the routes are popped before the session is flipped.
  Future<void> _signOut() => claySheet<void>(
        context,
        ClayCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrip(),
              const Medallion(Icons.logout_rounded, size: 56, color: A.amber),
              const SizedBox(height: 14),
              Text('Sign out?', style: A.h2),
              const SizedBox(height: 6),
              Text(
                'The reports stay where they are. You will come back to the '
                'sign-in screen.',
                style: A.bodySoft.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ClayButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                color: A.amber,
                onTap: () {
                  Navigator.of(context).pop(); // the sheet
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  Store.signOut();
                },
              ),
              const SizedBox(height: 10),
              ClayButton(
                label: 'Stay signed in',
                secondary: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );

  Future<void> _editGoal() async {
    var goal = Store.monthlyGoal.toDouble();
    await claySheet<void>(
      context,
      StatefulBuilder(
        builder: (_, set) => ClayCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrip(),
              Text('Monthly goal', style: A.h2),
              const SizedBox(height: 6),
              Text('${litres(goal.round())} L', style: A.mono(30, w: FontWeight.w700)),
              const SizedBox(height: 14),
              Slider(
                value: goal,
                min: 2000,
                max: 30000,
                divisions: 28, // one notch per thousand litres
                activeColor: A.accent,
                onChanged: (v) => set(() => goal = v),
              ),
              const SizedBox(height: 6),
              ClayButton(
                label: 'Save',
                onTap: () {
                  setState(() => Store.monthlyGoal = goal.round());
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
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
                  Expanded(child: Center(child: Text('Settings', style: A.h3))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  ClayCard(
                    onTap: _rename,
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Row(
                      children: [
                        InitialsAvatar(Store.fullName, size: 54, filled: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Store.fullName, style: A.h3),
                              const SizedBox(height: 2),
                              // One line, from one place: class, or the school, or
                              // the town. Leaving a group used to leave this
                              // claiming a school you had just left.
                              Text(Store.userLine, style: A.tiny),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
                      ],
                    ),
                  ),
                  const _Head('School or college'),
                  if (Store.joined)
                    ClayCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Column(
                        children: [
                          _Row(Store.institution,
                              sub: '${Store.institutionPlace} · '
                                  '${Store.userClass.isEmpty ? 'Joined' : Store.userClass}'),
                          GestureDetector(
                            onTap: () => setState(() => Store.joined = false),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text('Leave this group',
                                  style: A.h3.copyWith(color: A.amber, fontSize: 15.5)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ClayCard(
                      onTap: () async {
                        if (await joinSheet(context) && mounted) setState(() {});
                      },
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Row(
                        children: [
                          const Medallion(Icons.group_add_rounded, size: 44),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Join a school or college', style: A.h3),
                                const SizedBox(height: 2),
                                Text('Adds its leaderboard and its events', style: A.tiny),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
                        ],
                      ),
                    ),
                  const _Head('Notifications'),
                  ClayCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Column(
                      children: [
                        // These gate the feed itself, so turning one off takes its
                        // notices out of the bell — a switch that only moves is
                        // the thing this screen refuses to have.
                        for (final e in const [
                          (NotifKind.status, 'Report status changes'),
                          (NotifKind.near, 'Leaks reported near me'),
                          (NotifKind.event, 'Events and results'),
                        ])
                          _ToggleRow(
                            label: e.$2,
                            value: Store.notify[e.$1]!,
                            onChanged: (v) => setState(() {
                              Store.notify[e.$1] = v;
                              Store.touch();
                            }),
                            last: e.$1 == NotifKind.event,
                          ),
                      ],
                    ),
                  ),
                  // No "Your role" switch. Being the person who mends things is
                  // not something you grant yourself from a settings screen — the
                  // school head has it because the school gave it to him, and
                  // [Store.isFixer] comes with the account. It is also the one
                  // switch nobody would ever turn off, which makes it furniture.
                  const _Head('Monthly goal'),
                  ClayCard(
                    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${litres(Store.monthlyGoal)} L',
                                  style: A.mono(26, w: FontWeight.w700)),
                              Text('Your own target', style: A.tiny),
                            ],
                          ),
                        ),
                        ClayButton(
                            label: 'Change', secondary: true, expand: false, onTap: _editGoal),
                      ],
                    ),
                  ),
                  const _Head('Display'),
                  ClayCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Column(
                      children: [
                        _ToggleRow(
                          label: 'Water movement',
                          sub: 'The tank reacts when you tilt the phone',
                          value: Store.motion,
                          onChanged: (v) => setState(() => Store.motion = v),
                        ),
                        _ToggleRow(
                          label: 'Vibration',
                          value: Store.haptics,
                          onChanged: (v) => setState(() => Store.haptics = v),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const _Head('Language'),
                  ClayCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: _Row(
                      'English',
                      value: 'हिन्दी coming soon',
                      last: true,
                      onTap: () => _tell('Language', const [
                        'AquaAlert is in English for this build.',
                        'Hindi is next: the screens are already written so that every '
                            'word comes from one place, which is what makes a second '
                            'language a translation rather than a rebuild.',
                        'A leak report itself needs no language — the photo and the '
                            'place do the work.',
                      ]),
                    ),
                  ),
                  const _Head('Privacy'),
                  ClayCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Column(
                      children: [
                        _Row('Who can see my name',
                            sub: 'Your school only',
                            chevron: true,
                            onTap: () => _tell('Who can see your name', const [
                                  'Your class leaderboard shows your name to people in '
                                      'your school.',
                                  'A community report shows the name you sign it with to '
                                      'anyone who can see the report.',
                                  'The community board shows the town you report from, '
                                      'never your class or your school.',
                                  'Nothing you file inside a school ever leaves it.',
                                ])),
                        _Row('What AquaAlert stores about you',
                            chevron: true,
                            last: true,
                            onTap: () => _tell('What AquaAlert stores', const [
                                  'Your name, your email and the litres you have saved.',
                                  'The reports you file: the words, the picture, and the '
                                      'place — a street location for a community report, '
                                      'and no location at all for one inside a school.',
                                  'No contacts, no browsing, no background location.',
                                  'This build keeps all of it in the phone’s memory '
                                      'and forgets it when the app closes. There is no '
                                      'server yet.',
                                ])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClayCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Column(
                      children: [
                        _Row('About AquaAlert',
                            sub: 'Version 1.0',
                            chevron: true,
                            onTap: () => _tell('About AquaAlert', const [
                                  'Spot the Leak. Save the Water.',
                                  'Anyone can report a leak anywhere. The people nearby '
                                      'confirm it, and whoever can fix it does — there is '
                                      'no authority in the middle.',
                                  'Built for UN Sustainable Development Goal 6: clean '
                                      'water and sanitation for everyone.',
                                  'Version 1.0 — a prototype. No database, no network, '
                                      'nothing leaves the phone.',
                                ])),
                        GestureDetector(
                          onTap: _signOut,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Text('Sign out',
                                    style: A.h3.copyWith(color: A.amber, fontSize: 15.5)),
                                const Spacer(),
                                const Icon(Icons.logout_rounded, size: 18, color: A.amber),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AquaAlert · Spot the Leak. Save the Water.\n'
                    'Built for UN Sustainable Development Goal 6.',
                    style: A.tiny,
                    textAlign: TextAlign.center,
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

/// Section label above a group, the way the mockup separates them — no card,
/// just a heading in the gap.
class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
        child: Text(text, style: A.h3.copyWith(fontSize: 15)),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.sub,
    this.last = false,
  });
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) => _Shell(
        last: last,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: A.body.copyWith(fontWeight: FontWeight.w600)),
                  if (sub != null) ...[const SizedBox(height: 1), Text(sub!, style: A.tiny)],
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClayToggle(value: value, onChanged: onChanged),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label,
      {this.value, this.sub, this.chevron = false, this.last = false, this.onTap});
  final String label;
  final String? value, sub;
  final bool chevron, last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _Shell(
          last: last,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: A.body.copyWith(fontWeight: FontWeight.w600)),
                    if (sub != null) ...[const SizedBox(height: 1), Text(sub!, style: A.tiny)],
                  ],
                ),
              ),
              if (value != null) Text(value!, style: A.tiny),
              if (chevron) const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
            ],
          ),
        ),
      );
}

/// One hairline between rows, none after the last — the card edge is already
/// the boundary there.
class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.last});
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: A.ink.withValues(alpha: 0.07))),
              ),
        child: child,
      );
}
