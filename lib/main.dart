import 'dart:ui';

import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/account.dart';
import 'screens/auth.dart';
import 'screens/dashboard.dart';
import 'screens/event.dart';
import 'screens/leaderboard.dart';
import 'screens/leaks.dart';
import 'screens/notifications.dart';
import 'screens/report_chooser.dart';
import 'screens/splash.dart';
import 'theme.dart';
import 'widgets/clay.dart';

void main() => runApp(const AquaAlert());

class AquaAlert extends StatelessWidget {
  const AquaAlert({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AquaAlert',
        debugShowCheckedModeBanner: false,
        theme: A.theme(),
        home: const _Root(),
      );
}

/// Auth is a gate, not a route — until there is a real session there is nothing
/// to navigate back to. The splash is the same kind of gate, one step earlier.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _splash = true;
  bool _in = false;

  @override
  Widget build(BuildContext context) => _Swap(
        index: _splash ? 0 : (_in ? 2 : 1),
        child: _splash
            ? Splash(onDone: () => setState(() => _splash = false))
            : _in
                ? const Shell()
                : AuthScreen(onDone: () => setState(() => _in = true)),
      );
}

/// The hand-off between the three gates: the screen you are leaving slides out to
/// the left and dims while the one you are arriving at comes in from the right.
///
/// AnimatedSwitcher cannot do this — it runs one tween in both directions, so the
/// old screen reverses back out the same way the new one arrives, which reads as a
/// cross-fade rather than a move. Keeping the outgoing screen keyed matters too:
/// re-parented without a key its state is rebuilt, and the splash would start its
/// 2.2 second animation again inside a half-second transition.
class _Swap extends StatefulWidget {
  const _Swap({required this.index, required this.child});

  /// Which gate is showing. Changing it is what starts the move.
  final int index;
  final Widget child;

  @override
  State<_Swap> createState() => _SwapState();
}

class _SwapState extends State<_Swap> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    value: 1,
  );
  Widget? _leaving;
  int _leavingIndex = -1;

  @override
  void didUpdateWidget(_Swap old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _leaving = old.child;
    _leavingIndex = old.index;
    // Leaving the splash is a hand-off, not a step sideways: it dissolves and the
    // sign-in comes up through it. Sliding a splash off looked broken, because both
    // screens are the same colour and you see two of them at once.
    _c.duration = Duration(milliseconds: old.index == 0 ? 460 : 620);
    // Rewound on this frame, not in the callback: the controller was left at 1 by
    // the last move, and painting one frame at 1 flashed the arriving screen fully
    // in place — empty, because its own entrance animations had not started.
    _c.value = 0;
    // Started after the next frame. The arriving screen is expensive to build the
    // first time — the shell wakes four tabs, the tank and six entrance
    // animations — and in a debug build that frame takes longer than the move
    // itself, so an immediate forward() was over before it was painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.forward().then((_) {
        // Dropped once it is off screen, so a finished splash is not left
        // mounted and still ticking behind the app.
        if (mounted) setState(() => _leaving = null);
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);
    // A hand-off from the splash dissolves; a step between two real screens slides.
    final handover = _leavingIndex == 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The floor under both screens: while they cross there is a sliver of
        // nothing on one side, and it has to be the app's own surface.
        const ColoredBox(color: A.surface),
        if (_leaving != null)
          IgnorePointer(
            child: FadeTransition(
              // Gone before the end, so the two screens are not both on top of
              // each other for the whole move.
              opacity: Tween<double>(begin: 1, end: 0).animate(
                CurvedAnimation(parent: _c, curve: Interval(0, handover ? 0.55 : 0.7)),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: handover ? 1.06 : 1).animate(move),
                child: SlideTransition(
                  position: Tween(
                    begin: Offset.zero,
                    end: Offset(handover ? 0 : -0.32, 0),
                  ).animate(move),
                  child: KeyedSubtree(key: ValueKey(_leavingIndex), child: _leaving!),
                ),
              ),
            ),
          ),
        FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: const Interval(0, 0.45)),
          child: ScaleTransition(
            scale: Tween<double>(begin: handover ? 0.98 : 1, end: 1).animate(move),
            child: SlideTransition(
              position: Tween(
                begin: Offset(handover ? 0 : 0.32, 0),
                end: Offset.zero,
              ).animate(move),
              child: KeyedSubtree(key: ValueKey(widget.index), child: widget.child),
            ),
          ),
        ),
      ],
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  void _push(Widget page) =>
      Navigator.of(context).push(A.route(page));

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: A.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          // The nav sits at the bottom edge, so the Stack has to fill the
          // screen rather than shrink to the tab content.
          fit: StackFit.expand,
          children: [
            // IndexedStack, so the tank animation and scroll position survive a
            // trip to the reports list and back.
            _Fade(
              index: _tab,
              child: IndexedStack(
              index: _tab,
              children: [
                DashboardScreen(
                  onSeeAll: () => _go(1),
                  onEvent: () => _push(const EventScreen()),
                  onBoard: () => _push(const LeaderboardScreen()),
                  onAccount: () => _go(3),
                ),
                const LeaksScreen(),
                const NotificationsScreen(),
                const AccountScreen(),
              ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _Nav(
                tab: _tab,
                onTab: _go,
                onReport: () => _push(const ReportChooser()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cross-fades and lifts whatever tab you land on. The IndexedStack keeps every
/// tab alive underneath — this only animates the hand-off, so scroll positions
/// and the tank's water survive the switch.
class _Fade extends StatefulWidget {
  const _Fade({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Fade> createState() => _FadeState();
}

class _FadeState extends State<_Fade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void didUpdateWidget(_Fade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eased = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: eased,
      builder: (_, child) => Opacity(
        opacity: 0.35 + 0.65 * eased.value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - eased.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Five slots and a raised plus in the middle, exactly as every mockup draws
/// it. Liquid glass lives on this bar and on unread notifications, nowhere else.
class _Nav extends StatelessWidget {
  const _Nav({required this.tab, required this.onTab, required this.onReport});
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onReport;

  // Index 2 is the gap the plus sits in, so the icons stay evenly spaced. The
  // second number is the slot, which is what the indicator slides along.
  static const _items = [
    (0, 0, Icons.home_rounded),
    (1, 1, Icons.format_list_bulleted_rounded),
    (-1, 2, Icons.add_rounded),
    (2, 3, Icons.notifications_none_rounded),
    (3, 4, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    // Three-button navigation eats real space at the bottom, so the bar rides
    // well clear of it rather than sitting in it.
    final bottom = MediaQuery.paddingOf(context).bottom + 10;
    // Five equal slots, so the indicator's target is pure arithmetic — no
    // measuring, no keys, no layout pass.
    final slot = _items.firstWhere((e) => e.$1 == tab).$2;
    return SizedBox(
      height: 104 + bottom,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 18,
            right: 18,
            bottom: 16 + bottom,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(A.rPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(A.rPill),
                    color: Colors.white.withValues(alpha: 0.62),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.2),
                    boxShadow: A.clay(d: 0.9),
                  ),
                  child: Stack(
                    children: [
                      // The lit cradle slides to whichever tab you chose, and the
                      // dash under it lands a beat later.
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 340),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(-1 + slot / 2, 0),
                        child: FractionallySizedBox(
                          widthFactor: 1 / 5,
                          child: Center(
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    A.accent.withValues(alpha: 0.16),
                                    A.accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        alignment: Alignment(-1 + slot / 2, 1),
                        child: FractionallySizedBox(
                          widthFactor: 1 / 5,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 22,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 9),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6FD3EE), A.accent],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (final (i, _, icon) in _items)
                            Expanded(
                              child: i < 0
                                  ? const SizedBox()
                                  : GestureDetector(
                                      onTap: () => onTab(i),
                                      behavior: HitTestBehavior.opaque,
                                      child: Center(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: i == tab ? 1 : 0),
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOutCubic,
                                          builder: (_, v, __) => Transform.translate(
                                            offset: Offset(0, -3 * v),
                                            child: Transform.scale(
                                              scale: 1 + 0.16 * v,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Icon(icon,
                                                      size: 25,
                                                      color: Color.lerp(A.inkSoft, A.accent, v)),
                                                  // Unread lives on the bell and
                                                  // nowhere else; the count is on
                                                  // the list itself.
                                                  if (i == 2 &&
                                                      tab != 2 &&
                                                      Store.feed.isNotEmpty)
                                                    Positioned(
                                                      right: -1,
                                                      top: 0,
                                                      child: Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: const BoxDecoration(
                                                            color: A.accent,
                                                            shape: BoxShape.circle),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The plus is a separate object riding above the bar: reporting is the
          // app, so it is the one control that breaks the bar's line.
          Positioned(
            bottom: 30 + bottom,
            child: ClayFab(icon: Icons.add_rounded, onTap: onReport),
          ),
        ],
      ),
    );
  }
}
