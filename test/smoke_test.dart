import 'package:aquaalert/data/store.dart';
import 'package:aquaalert/main.dart';
import 'package:aquaalert/screens/splash.dart';
import 'package:aquaalert/theme.dart';
import 'package:aquaalert/widgets/clay.dart';
import 'package:aquaalert/widgets/common.dart';
import 'package:aquaalert/widgets/tank.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One pass through the whole app. The tank animates forever, so this pumps
/// fixed durations — pumpAndSettle would never return.
void main() {
  /// The store is static and outlives a test, so the session has to be put back
  /// between them — otherwise the second test boots straight past the sign-in
  /// screen the first one came through.
  setUp(() => Store.session.value = false);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Come in as the saved student — the row that gets tapped on stage, and the
  /// only kind of account that can see anything filed inside the school.
  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.text('Mohd Rehan'));
    await tester.pump();
    // The shared-axis swap into the shell runs 620ms and starts in a post-frame
    // callback, so its ticker only takes its zero on the *next* frame: one long
    // pump leaves the whole shell still shifted 115px to the right, and every tap
    // on the nav lands beside the icon it was aiming at.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// The splash owns the first 2.2 seconds. Tap through it, which is also the
  /// skip path a real user gets, then sign in.
  Future<void> boot(WidgetTester tester) async {
    await phone(tester);
    await tester.pumpWidget(const AquaAlert());
    await tester.tap(find.byType(Splash));
    await tester.pump(const Duration(milliseconds: 400));
    await signIn(tester);
  }

  /// A push needs one pump to start the route, then one to run it out.
  Future<void> open(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Lists are lazy, so anything below the fold has to be scrolled into
  /// existence before it can be found. Dragging the vertical list by hand rather
  /// than scrollUntilVisible: the tabs stay alive behind each other and the
  /// filter chips are a scrollable too, so "the last Scrollable" is a coin toss.
  Future<void> reach(WidgetTester tester, Finder target) async {
    Future<void> pull() async {
      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
      await tester.pump(const Duration(milliseconds: 120));
      // A drag releases with velocity, so the list is still flinging: let it stop
      // before anything is tapped, or the tap lands on whatever slid under it.
      await tester.pump(const Duration(seconds: 1));
    }

    for (var i = 0; i < 14 && target.evaluate().isEmpty; i++) {
      await pull();
    }
    expect(target, findsWidgets);
    // Built is not the same as tappable: a row can exist in the cache extent
    // below the fold, or sit under the floating nav bar, which swallows the tap.
    for (var i = 0; i < 6 && tester.getCenter(target.first).dy > 600; i++) {
      await pull();
    }
  }

  testWidgets('sign in, then every tab builds', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const AquaAlert());
    await tester.tap(find.byType(Splash));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome back'), findsOneWidget);

    await signIn(tester);
    expect(find.text('saved this month'), findsOneWidget);

    // The nav is icons only now, so the tabs are found by their glyphs.
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Reports'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Levels'), findsOneWidget);
  });

  testWidgets('the + files a community report', (tester) async {
    await boot(tester);

    // Look at Reports first. The tabs stay alive in an IndexedStack, so this is
    // the built list that used to go stale the moment a report was filed.
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Street pipe'), findsNothing);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pump(const Duration(milliseconds: 400));

    await open(tester, find.byIcon(Icons.add_rounded));
    expect(find.text('Where is the leak?'), findsOneWidget);

    await open(tester, find.text('Anywhere around you'));
    expect(find.text('Report a leak'), findsOneWidget);

    await reach(tester, find.text('Street pipe'));
    await tester.tap(find.text('Street pipe'));
    await tester.pump();
    await reach(tester, find.text('Use my current location'));
    await tester.tap(find.text('Use my current location'));
    await tester.pump();
    await reach(tester, find.text('Send report'));
    await open(tester, find.text('Send report'));
    expect(find.text('REPORTED!'), findsOneWidget);

    // Back to the app, and it has to be in the list. The tabs stay alive in an
    // IndexedStack, so Reports used to still be showing the list it built before
    // the report existed.
    await open(tester, find.text('Done'));
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    await reach(tester, find.text('Street pipe'));
  });

  testWidgets('a report opens, and someone else\'s cannot be closed', (tester) async {
    await boot(tester);
    // From the Reports list, which is the one place every report appears — the
    // dashboard only carries the three most recent.
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    final row = find.text('Tap left running');
    await reach(tester, row);
    await open(tester, row);
    expect(find.text('Leak rate'), findsOneWidget);
    // Aarav reported this one and the account is not a fixer, so the only thing
    // on offer is vouching for it — nobody here can close somebody else's report.
    await reach(tester, find.text('I’ve seen it too'));
    expect(find.text('Mark as fixed'), findsNothing);
    // And vouching counts: the timeline says so, live.
    await tester.tap(find.text('I’ve seen it too'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.textContaining('Confirmed by 3 people nearby'), findsOneWidget);
  });

  /// Typing an address is a brand new account: community only. It must not be
  /// able to read a word of what the school filed — that rule is why a student
  /// files there in the first place.
  testWidgets('a typed-in account sees the street but never the school', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const AquaAlert());
    await tester.tap(find.byType(Splash));
    await tester.pump(const Duration(milliseconds: 400));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'someone@example.com');
    await tester.pump();
    await tester.enterText(fields.at(1), 'water123');
    await tester.pump();
    // The saved accounts push the form down the scroll view on a short window.
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    // Scrolled to, not just expected: the list is long enough that a row this far
    // down is not built until it is near the viewport.
    await reach(tester, find.text('Leaking street valve')); // filed in the open
    expect(find.text('Tap left running'), findsNothing); // filed inside the school
    expect(find.text('Washbasin dripping'), findsNothing);

    // And the same gate on the notices, or an outsider reads the school's post.
    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('AA-118'), findsNothing);
  });

  /// The bell's dot and the frosted cards used to be two different counts — the
  /// screen owned one privately — so reading everything left the dot lit.
  testWidgets('reading the notifications puts the bell out', (tester) async {
    await boot(tester);
    expect(Store.unread, greaterThan(0));

    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Mark all read'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(Store.unread, 0);
    expect(find.text('Mark all read'), findsNothing);

    // Off the tab and back: the dot is drawn from the store now, so it is gone.
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('saved this month'), findsOneWidget);
  });

  /// Sign out is four screens deep and the gate is at the root, so this is the
  /// one path that proves the session, not a callback, is what closes the app.
  testWidgets('signing out from settings goes back to the sign-in screen',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    await open(tester, find.byIcon(Icons.settings_outlined));
    expect(find.text('Settings'), findsOneWidget);

    await reach(tester, find.text('Sign out'));
    // A sheet is a route: it needs the frame that starts it and the frame that
    // runs it out, or its button is still below the bottom of the screen.
    await open(tester, find.text('Sign out'));
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Sign out').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(Store.session.value, isFalse);
    // And the next person is not handed a feed somebody else has read.
    expect(Store.unread, greaterThan(0));
  });

  /// The slider estimates severity from three words. Somebody who has watched a
  /// bucket fill, or read a meter, knows better than that — so the readout is also
  /// the way in, and what they type is what the report carries.
  testWidgets('a typed figure replaces the slider estimate', (tester) async {
    await boot(tester);
    await open(tester, find.byIcon(Icons.add_rounded));
    await open(tester, find.text('Anywhere around you'));

    final readout = find.textContaining('L a day');
    await reach(tester, readout);
    expect(find.textContaining('about'), findsWidgets); // estimating, to start with
    await open(tester, readout.first);

    final field = find.ancestor(of: find.text('e.g. 240'), matching: find.byType(TextField));
    await tester.enterText(field, '1500');
    await tester.pump();
    await open(tester, find.text('Use this figure'));

    expect(find.text('1,500 L a day'), findsOneWidget);
    expect(find.text('Your own figure'), findsOneWidget);
    expect(find.text('about 1,500 L a day'), findsNothing);
  });

  /// A fast tap used to be invisible: down and up land in the same frame, so the
  /// squash and the ink dashes were painted for no time at all and the comic
  /// press only showed if you held the button a moment longer. The press is now
  /// latched for a readable beat.
  testWidgets('a quick tap still shows the press', (tester) async {
    await phone(tester);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: A.theme(),
      home: Scaffold(
        body: Center(child: ClayIcon(Icons.ios_share_rounded, onTap: () => taps++)),
      ),
    ));

    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1);

    await tester.tap(find.byType(ClayIcon)); // down and up in one frame
    await tester.pump(const Duration(milliseconds: 60));
    expect(taps, 1);
    expect(scale(), lessThan(1)); // still held, so it can be seen

    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), 1); // and it lets go on its own
  });

  /// The tank has to be *running*: its ticker is what fills the glass and moves
  /// the surface, and a `late final` ticker that nothing ever reads is never
  /// created — which is how the water came out invisible, sitting at zero fill and
  /// dead still.
  testWidgets('the tank is actually ticking', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: A.theme(),
      home: const Scaffold(
        body: Center(child: WaterTank(fill: 0.8, tilt: 0.3, height: 150)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  /// The map is reachable from the home screen and knows what is on it.
  testWidgets('the dashboard opens the neighbourhood map', (tester) async {
    await boot(tester);
    final card = find.textContaining('leaks near you');
    await reach(tester, card);
    await open(tester, card);
    expect(find.text('Leaks near you'), findsOneWidget);
    expect(find.textContaining('tap a pin'), findsOneWidget);
  });

  /// Opening the join sheet and dismissing it used to throw
  /// "_dependents.isEmpty is not true": the helper disposed the code controller
  /// as soon as showModalBottomSheet returned, while the sheet was still
  /// animating out and its field still depended on it. The sheet owns the
  /// controller now, and flutter_test fails on any framework error, so this is
  /// the guard.
  ///
  /// It also pins the thing every sheet got wrong: with a three-button
  /// navigation bar at the bottom of the phone, the sheet's own button has to sit
  /// above that bar, not behind it.
  testWidgets('the join sheet opens and closes cleanly, clear of the system bar',
      (tester) async {
    await phone(tester);
    const navBar = 126.0; // three-button navigation, 42dp at this pixel ratio
    tester.view.padding = const FakeViewPadding(bottom: navBar);
    tester.view.viewPadding = const FakeViewPadding(bottom: navBar);
    await tester.pumpWidget(MaterialApp(
      theme: A.theme(),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(child: ClayButton(label: 'Open', onTap: () => joinSheet(c))),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Join a school or college'), findsOneWidget);

    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final ratio = tester.view.devicePixelRatio;
    expect(tester.getBottomLeft(find.text('Join')).dy, lessThan(screen - navBar / ratio));

    await tester.tapAt(const Offset(20, 20)); // the barrier
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Join a school or college'), findsNothing);
  });
}
