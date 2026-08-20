import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:aquaalert/data/mock.dart';
import 'package:aquaalert/data/store.dart';
import 'package:aquaalert/screens/leaderboard.dart';
import 'package:aquaalert/screens/map.dart';
import 'package:aquaalert/theme.dart';
import 'package:aquaalert/widgets/tank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Indian digit grouping', () {
    expect(litres(0), '0');
    expect(litres(999), '999');
    expect(litres(1000), '1,000');
    expect(litres(12450), '12,450');
    expect(litres(99999), '99,999');
    expect(litres(120000), '1,20,000'); // grouping switches to pairs here
    expect(litres(2400000), '24,00,000');
  });

  test('XP maps to the right level and progress', () {
    expect(levelOf(0).name, 'Droplet');
    expect(levelOf(249).name, 'Droplet');
    expect(levelOf(250).name, 'Puddle');
    expect(levelOf(1240).name, 'Stream'); // 1800 is the River floor
    expect(levelOf(1799).name, 'Stream');
    expect(levelOf(1800).name, 'River');

    final s = levelOf(1275); // Stream: 750 -> 1800
    expect(s.next, 'River');
    expect(s.progress, closeTo(0.5, 0.01));

    final top = levelOf(50000); // Reservoir has no next level
    expect(top.name, 'Reservoir');
    expect(top.next, isNull);
    expect(top.progress, 1);
  });

  test('litres only count once a leak is fixed', () {
    Leak l(Status s) => Leak(
          id: 'x', title: 't', scope: Scope.school, place: 'p',
          litresPerDay: 100, daysOpen: 3, status: s, reporter: 'r',
        );
    expect(l(Status.reported).litresSaved, 0);
    expect(l(Status.overdue).litresSaved, 0);
    expect(l(Status.fixed).litresSaved, 300);
    // Filed and mended the same day: hours of water, credited as one day rather
    // than as nothing, or the whole loop reads as broken on stage.
    expect(
      Leak(
        id: 'x', title: 't', scope: Scope.community, place: 'p',
        litresPerDay: 240, daysOpen: 0, status: Status.fixed, reporter: 'r',
      ).litresSaved,
      240,
    );
  });

  test('leaderboard shortens only long figures', () {
    expect(litresOf(940), '940');
    expect(litresOf(9999), '9,999'); // exact right up to the cutoff
    expect(litresOf(10000), '10k');
    expect(litresOf(42800), '43k');
  });

  test('the fixer queue never holds a fixed leak', () {
    expect(Store.queue.any((l) => l.status == Status.fixed), isFalse);
    expect(Store.queue.length, Store.openCount);
  });

  /// The dashboard tiles read Open / Fixed / Overdue side by side, so the first
  /// two have to account for every leak and overdue has to be a slice of open.
  test('the dashboard tiles partition the leaks', () {
    expect(Store.openCount + Store.fixedCount, Store.visible.length);
    expect(Store.overdueCount, lessThanOrEqualTo(Store.openCount));
  });

  /// The prototype has no database, so the store *is* the app's memory. Filing a
  /// report has to change what every screen counts, and fixing one has to credit
  /// the litres it stopped — those two are the whole demo loop.
  test('filing a report lands it, fixing it credits the litres', () {
    final before = Store.leaks.length;
    final openBefore = Store.openCount;
    final litresBefore = Store.yourLitres;

    final leak = Store.file(
      scope: Scope.community,
      title: 'Street pipe',
      place: 'Nehru Road',
      litresPerDay: 240,
    );
    expect(Store.leaks.length, before + 1);
    expect(Store.leaks.first, leak); // newest first
    expect(Store.openCount, openBefore + 1);
    expect(leak.reporter, Store.userName); // it is yours, so it can score

    // A report that was never open for a day has saved nothing yet.
    leak.status = Status.fixed;
    Store.credit(leak);
    expect(Store.yourLitres, litresBefore + leak.litresSaved);

    Store.leaks.remove(leak); // leave the fixture as it was found
    Store.yourLitres = litresBefore;
  });

  test('badge count is derived, not typed', () {
    expect(Store.badges.where((b) => b.earned).length, 6);
    expect(Store.badges.length, 12);
  });

  /// The school rule, and the reason a student files inside the school at all:
  /// people in it see everything, an account with no institution sees only what
  /// was filed in the open, and the notices about the rest do not reach it either.
  /// The head is the one who can close what somebody else reported.
  test('a school report never leaves the school', () {
    final inside = Store.leaks.where((l) => l.scope != Scope.community).toList();
    expect(inside, isNotEmpty);

    Store.use(Store.saved[1]); // Kavita: community member, no institution
    expect(Store.joined, isFalse);
    expect(Store.visible.any((l) => l.scope != Scope.community), isFalse);
    expect(Store.visible.length, Store.leaks.length - inside.length);
    expect(Store.feed.any((n) => n.leak == 'AA-118'), isFalse); // filed in school
    expect(Store.openCount + Store.fixedCount, Store.visible.length);

    Store.use(Store.saved[2]); // the head: inside the school, and closes reports
    expect(Store.visible.length, Store.leaks.length);
    expect(Store.isFixer, isTrue);
    expect(Store.canClose(inside.first), isTrue);
    // But his say stops at the school gate. A street is nobody's to close but the
    // person who reported it — there is no authority over a community report.
    final street = Store.leaks.firstWhere(
        (l) => l.scope == Scope.community && l.reporter != Store.userName);
    expect(Store.canClose(street), isFalse);

    Store.use(Store.saved.first); // the student the rest of the fixture assumes
    expect(Store.isFixer, isFalse);
    expect(Store.userLine, 'Class 9-C');
    // Their own school report, yes; a classmate's, no.
    expect(Store.canClose(inside.firstWhere((l) => l.reporter == Store.userName)), isTrue);
    expect(Store.canClose(inside.firstWhere((l) => l.reporter != Store.userName)), isFalse);
  });

  /// The water is a simulation now, so it is checked like one. Tilting a glass
  /// moves water from one side to the other; it never makes more of it, and the
  /// surface has to come back to level on its own.
  group('the tank water', () {
    double peak(WaterSurface s) => s.h.map((x) => x.abs()).reduce(math.max);

    test('a shake sloshes, then settles, and the volume never changes', () {
      final sea = WaterSurface();
      sea.kick(1, 1);
      expect(sea.mean, closeTo(0, 0.001)); // a shove tilts water, it does not add

      var high = 0.0;
      for (var i = 0; i < 60; i++) {
        sea.step(1 / 60, 0);
        high = math.max(high, peak(sea));
      }
      expect(high, greaterThan(4)); // it visibly moves, not a 2px shiver
      expect(sea.mean, closeTo(0, 0.5));

      for (var i = 0; i < 60 * 6; i++) {
        sea.step(1 / 60, 0);
      }
      expect(peak(sea), lessThan(0.6)); // six seconds later it is flat again
    });

    test('it leans the way gravity does', () {
      final sea = WaterSurface();
      for (var i = 0; i < 60 * 5; i++) {
        sea.step(1 / 60, 0.5);
      }
      // Half tilt, so each wall sits a quarter of the full lean off the middle.
      expect(sea.h.last, closeTo(WaterSurface.lean * 0.25, 1.5));
      expect(sea.h.first, closeTo(-WaterSurface.lean * 0.25, 1.5));
      expect(sea.mean, closeTo(0, 0.5));
      // And it reads the same off the interpolator the painter samples.
      expect(sea.at(1), closeTo(sea.h.last, 0.001));
      expect(sea.at(0.5), closeTo(0, 1));
    });

    test('the frame rate does not change the water', () {
      final fast = WaterSurface()..kick(1, 1);
      final slow = WaterSurface()..kick(1, 1);
      for (var i = 0; i < 120; i++) {
        fast.step(1 / 120, 0.3);
      }
      for (var i = 0; i < 30; i++) {
        slow.step(1 / 30, 0.3);
      }
      for (var i = 0; i < fast.cols; i++) {
        expect(fast.h[i], closeTo(slow.h[i], 1.5));
      }
    });

    /// Being thrown about is the case that has to stay bounded: the gyro fires
    /// twenty times a second, so a hard shake used to stack shoves until the
    /// surface climbed the walls.
    test('shaking it hard cannot make the water go wild', () {
      final sea = WaterSurface();
      for (var i = 0; i < 200; i++) {
        sea.kick(1.2, i.isEven ? 1 : -1); // a fortnight of aggressive shaking
        sea.step(1 / 50, i.isEven ? 1 : -1);
        expect(peak(sea), lessThanOrEqualTo(WaterSurface.maxRise + 0.001));
        expect(sea.v.map((x) => x.abs()).reduce(math.max),
            lessThanOrEqualTo(WaterSurface.maxSpeed + 0.001));
      }
      // And it still comes back to level once the phone is put down.
      for (var i = 0; i < 60 * 8; i++) {
        sea.step(1 / 60, 0);
      }
      expect(peak(sea), lessThan(0.6));
    });
  });

  /// The map is drawn rather than tiled, so the geometry is ours to get right: a
  /// pin has to land where its coordinates say, and "near you" has to mean it.
  group('the neighbourhood map', () {
    test('distance is measured from where you are', () {
      expect(Store.distanceKm(Store.originLat, Store.originLng), closeTo(0, 0.001));
      // A hundredth of a degree of latitude is 1.1km, wherever you are.
      expect(Store.distanceKm(Store.originLat + 0.01, Store.originLng), closeTo(1.106, 0.01));
      // The same step east is shorter, because Delhi is not on the equator.
      expect(Store.distanceKm(Store.originLat, Store.originLng + 0.01), closeTo(0.977, 0.01));
    });

    test('only located reports are on it, nearest first', () {
      final pins = Store.nearby;
      expect(pins, isNotEmpty);
      // School reports carry no coordinates, which is what keeps them off it.
      expect(pins.any((l) => l.scope != Scope.community), isFalse);
      for (final l in pins) {
        expect(l.lat, isNotNull);
        expect(Store.distanceKm(l.lat!, l.lng!), lessThan(2)); // one neighbourhood
      }
      final far = pins.map((l) => Store.distanceKm(l.lat!, l.lng!)).toList();
      for (var i = 1; i < far.length; i++) {
        expect(far[i], greaterThanOrEqualTo(far[i - 1]));
      }
    });

    test('the projection puts you in the middle, with north above you', () {
      const size = Size(320, 480);
      const v = MapView(size);
      final me = v.of(Store.originLat, Store.originLng);
      expect(me.dx, closeTo(160, 0.01));
      expect(me.dy, closeTo(240, 0.01));
      // North is up, east is right, and 1750m spans the width.
      expect(v.of(Store.originLat + 0.005, Store.originLng).dy, lessThan(me.dy));
      expect(v.of(Store.originLat, Store.originLng + 0.005).dx, greaterThan(me.dx));
      expect(v.at(725, 0).dx, closeTo(size.width, 0.01));
    });
  });

  /// A report is yours by carrying your name, so changing your name has to take
  /// them with it — otherwise renaming yourself in settings quietly empties "Your
  /// reports" and takes away the button to close what you filed.
  test('renaming yourself keeps the reports you filed', () {
    Store.use(Store.saved.first);
    final mine = Store.leaks.where((l) => l.reporter == Store.userName).length;
    expect(mine, greaterThan(0));

    Store.rename('Zaid Khan');
    expect(Store.fullName, 'Zaid Khan');
    expect(Store.userName, 'Zaid'); // a name it has never seen: the first word
    expect(Store.leaks.where((l) => l.reporter == 'Zaid').length, mine);
    expect(Store.canClose(Store.leaks.firstWhere((l) => l.reporter == 'Zaid')), isTrue);

    // And what it calls you survives a longer name that still contains it, which
    // is what stops "Mohd Rehan" being saved back as Mohd.
    Store.rename('Mohd Zaid Khan');
    expect(Store.userName, 'Zaid');
    expect(Store.leaks.where((l) => l.reporter == 'Zaid').length, mine);

    Store.rename('Rehan'); // re-sign them, then put the fixture's account back
    Store.use(Store.saved.first);
    expect(Store.userName, 'Rehan');
    expect(Store.leaks.where((l) => l.reporter == 'Rehan').length, mine);
  });

  /// The whole point of three accounts on one phone: the reports are a shared
  /// place, not one person's list. A student files inside the school, the head sees
  /// it and closes it, and the litres land on the student — who was not even signed
  /// in when it happened. Somebody with no school never sees any of it.
  test('a report outlives the person who filed it', () {
    Store.use(Store.saved.first); // Rehan, Class 9-C
    final klass = Store.classes.firstWhere((c) => c.name == 'Class 9-C');
    final classBefore = klass.litres;
    final rehanBefore = Store.yourLitres;

    final leak = Store.file(
      scope: Scope.school,
      title: 'Tap left running',
      place: 'Block D, first floor',
      litresPerDay: 300,
    );
    leak.status = Status.overdue; // open for a few days by the time it is mended
    const days = 4;

    Store.use(Store.saved[2]); // the head, who was not there when it was filed
    expect(Store.visible.contains(leak), isTrue);
    expect(Store.canClose(leak), isTrue);
    expect(Store.yourLitres, 2100); // his own figure, untouched by the switch

    // He mends it and closes it. Four days of 300 litres stop being wasted.
    final fixed = Leak(
      id: leak.id, title: leak.title, scope: leak.scope, place: leak.place,
      litresPerDay: leak.litresPerDay, daysOpen: days, status: Status.fixed,
      reporter: leak.reporter,
    );
    Store.credit(fixed);
    expect(Store.yourLitres, 2100); // not the head's litres — he did not report it

    Store.use(Store.saved[1]); // Kavita: no institution at all
    expect(Store.visible.contains(leak), isFalse);

    Store.use(Store.saved.first); // back to Rehan, and it is waiting for him
    expect(Store.yourLitres, rehanBefore + 300 * days);
    expect(klass.litres, classBefore + 300 * days); // and his class climbed with him
    expect(Store.visible.contains(leak), isTrue);

    // Put the fixture back.
    Store.leaks.remove(leak);
    Store.litresBy['Rehan'] = rehanBefore;
    Store.xpBy['Rehan'] = 1240;
    klass.litres = classBefore;
  });

  /// The count is only worth something if it counts people rather than taps.
  test('one vouch per person, remembered on the report', () {
    Store.use(Store.saved.first);
    final leak = Store.leaks.firstWhere((l) => l.reporter != Store.userName);
    final before = leak.confirms;

    expect(Store.confirm(leak), isTrue);
    expect(leak.confirms, before + 1);
    expect(Store.confirm(leak), isFalse); // the same person, again
    expect(leak.confirms, before + 1);

    Store.use(Store.saved[2]); // somebody else on the phone gets their own say
    expect(Store.confirm(leak), isTrue);
    expect(leak.confirms, before + 2);

    leak.confirms = before;
    leak.confirmedBy.clear();
    Store.use(Store.saved.first);
  });

  /// The dashboard is a tab that stays alive behind settings, so it only redraws
  /// when the store says it moved. Changing the goal has to say so, or the tank
  /// keeps measuring against the old line until something else happens to touch.
  test('changing the monthly goal moves the store, and is your own', () {
    Store.use(Store.saved.first);
    final was = Store.revision.value;

    Store.monthlyGoal = 14000;
    expect(Store.monthlyGoal, 14000);
    expect(Store.revision.value, greaterThan(was)); // the dashboard hears it

    Store.use(Store.saved[2]); // the head's target is his own
    expect(Store.monthlyGoal, 10000);

    Store.use(Store.saved.first);
    expect(Store.monthlyGoal, 14000);
    Store.goalBy.clear();
  });

  /// A photograph taken inside a school is a photograph of a school. The rule sits
  /// on [Leak.photo] rather than on the screens, so this checks the data as well as
  /// a report filed with a picture attached anyway.
  test('nothing filed inside an institution carries a photo', () {
    for (final l in Store.leaks.where((l) => l.scope != Scope.community)) {
      expect(l.photo, isNull, reason: '${l.id} is inside a building');
    }
    // At least one street report has one, or this test would pass on an empty rule.
    expect(Store.leaks.any((l) => l.scope == Scope.community && l.photo != null), isTrue);

    final filed = Store.file(
      scope: Scope.school,
      title: 'Tap running',
      place: 'Block C',
      litresPerDay: 100,
      photo: 'assets/demo/tap.jpg', // handed one anyway
    );
    expect(filed.photo, isNull);
    Store.leaks.remove(filed);
  });

  group('the notification feed', () {
    test('marking all read clears the count the nav bell draws from', () {
      Store.notify[NotifKind.status] = true;
      Store.notify[NotifKind.near] = true;
      expect(Store.unread, greaterThan(0));
      Store.readAll();
      expect(Store.unread, 0);
      // Signing out re-arms it, so the next person is not handed a read feed.
      Store.signOut();
      expect(Store.unread, greaterThan(0));
    });

    test('a switch that is off takes its notices out of the feed', () {
      Store.notify[NotifKind.status] = true;
      Store.notify[NotifKind.near] = true;
      Store.notify[NotifKind.event] = false;
      final on = Store.feed.length;
      expect(Store.feed.any((n) => n.kind == NotifKind.near), isTrue);
      expect(Store.feed.any((n) => n.kind == NotifKind.event), isFalse);
      Store.notify[NotifKind.near] = false;
      expect(Store.feed.length, lessThan(on));
      expect(Store.feed.any((n) => n.kind == NotifKind.near), isFalse);
      Store.notify[NotifKind.near] = true; // the rest of the suite reads the feed
    });

    test('unread can never outrun the feed it points at', () {
      Store.notify[NotifKind.status] = false;
      Store.notify[NotifKind.near] = false;
      Store.notify[NotifKind.event] = false;
      expect(Store.feed, isEmpty);
      expect(Store.unread, 0);
      Store.notify[NotifKind.status] = true;
      Store.notify[NotifKind.near] = true;
    });
  });
}
