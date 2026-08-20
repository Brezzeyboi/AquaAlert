import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mock.dart';

/// In-memory stand-in for Supabase. One place, so swapping in the real client
/// later touches this file and nothing else.
///
/// AquaAlert is community first: a user is a user — an adult, a social worker, a
/// municipal team, anyone — and reporting a leak needs no institution at all.
/// Joining a school or college is an extra that unlocks its leaderboard and its
/// events, which is why every campus-shaped thing in the app hangs off [joined].
class Store {
  static const institution = 'Maxfort School, Pitampura';
  static const shortName = 'Maxfort Pitampura';

  /// The street, for the places that name the institution properly — a school is
  /// a building on a road, not a label.
  static const institutionPlace = 'Parwana Road, Pitampura, Delhi';

  /// What kind of place it is, so the report form offers "School" or "College"
  /// and never both. Maxfort is a school.
  static const institutionScope = Scope.school;

  /// Has this user joined an institution? False is a perfectly normal account:
  /// it reports, it scores, it just has no class to compete with — and it never
  /// sees anything filed inside a school.
  static bool joined = true;

  /// Joining codes are six characters, which is why the sign-in screen can draw
  /// six boxes instead of one open field.
  static const joinCode = 'MX7412';
  static const codeLength = 6;
  /// Who is signed in. Set by the login or register screen — there is no
  /// database in this prototype, so the session is the source of truth and it
  /// lasts exactly as long as the app is open.
  static String fullName = 'Mohd Rehan'; // what the avatar and settings show

  /// What the app calls you, and what your reports are signed with. Stated, not
  /// sliced off the front of [fullName]: "Mohd Rehan" is Rehan, and a greeting
  /// that gets somebody's name wrong is the first thing they notice.
  static String _call = 'Rehan';
  static String get userName => _call;

  /// Their class, or 'Staff'. Empty for an account that joined nothing, so
  /// anything that prints it checks [joined] first.
  static String userClass = 'Class 9-C';

  /// Where you report from. This is what the community board shows beside your
  /// name — a class only means anything to the people in it.
  static String userPlace = 'Pitampura, Delhi';

  /// Where the map centres and where "near you" is measured from. Parwana Road,
  /// Pitampura — the same neighbourhood as the school, because that is where this
  /// account's reports are. A real build reads this from the phone; a prototype
  /// with no permission dialog states it.
  static const originLat = 28.6980;
  static const originLng = 77.1360;

  /// Kilometres from [originLat]/[originLng], flat-earth style. Over a couple of
  /// kilometres that is accurate to a few metres, and it costs no dependency: one
  /// degree of latitude is 110.57km, one of longitude 111.32km times the cosine of
  /// the latitude.
  static double distanceKm(double lat, double lng) {
    final dy = (lat - originLat) * 110.57;
    final dx = (lng - originLng) * 111.32 * math.cos(originLat * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// The reports the map can draw: anything visible that carries coordinates,
  /// nearest first. School reports have none by design, so they are simply not
  /// here — the rule that keeps a corridor off a public map is the absence of the
  /// number, not a filter somebody has to remember to write.
  static List<Leak> get nearby {
    final list = visible.where((l) => l.lat != null && l.lng != null).toList()
      ..sort((a, b) =>
          distanceKm(a.lat!, a.lng!).compareTo(distanceKm(b.lat!, b.lng!)));
    return list;
  }

  /// The one line that goes under somebody's name anywhere in the app: their
  /// class if they have one, the institution if they joined without a class, and
  /// otherwise the town they report from. Three screens used to spell this out
  /// themselves and two of them got it wrong after you left a group.
  static String get userLine =>
      joined ? (userClass.isEmpty ? shortName : userClass) : userPlace;

  /// Whether this account can close reports inside its own institution. It comes
  /// with the account and there is no switch for it: being the person who mends
  /// things is something a school gives you, not something you grant yourself in
  /// settings. Off for everybody else, because the ordinary user of a community app
  /// is a reporter, and it means nothing at all without an institution to be one
  /// for.
  static bool isFixer = false;

  /// Who may mark a report fixed.
  ///
  /// Your own, always: you are the one who can go back and see whether the water
  /// stopped. Beyond that the only authority in AquaAlert is inside an institution
  /// — a school head is the person who actually gets the corridor mended, and that
  /// is exactly where their say ends. A street has no head, so a community report
  /// can only be closed by whoever filed it, and everybody else says "I've seen it
  /// too" instead. That is the whole point of there being no admin.
  static bool canClose(Leak leak) =>
      leak.reporter == userName || (isFixer && joined && leak.scope != Scope.community);

  /// The accounts already signed in on this phone, in the order the sign-in
  /// screen lists them. Three, because the app has exactly three kinds of person
  /// and the whole point of a demo is to be each of them in turn: a student
  /// inside Maxfort, somebody with no institution at all, and the head who
  /// closes what the students file.
  static const saved = <Persona>[
    Persona('Mohd Rehan', 'rehan@maxfort.in', 'Student · Class 9-C',
        call: 'Rehan',
        place: 'Pitampura, Delhi',
        joined: true,
        klass: 'Class 9-C',
        fixer: false,
        xp: 1240,
        litres: 8600),
    Persona('Kavita Sharma', 'kavita.sharma@gmail.com', 'Community member',
        call: 'Kavita',
        place: 'Jaipur',
        joined: false,
        klass: '',
        fixer: false,
        xp: 2100,
        litres: 19400),
    Persona('Anil Verma', 'head@maxfort.in', 'School head',
        call: 'Anil',
        place: 'Pitampura, Delhi',
        joined: true,
        klass: 'Staff',
        fixer: true,
        xp: 640,
        litres: 2100),
  ];

  /// Becomes that person. Everything downstream reads these fields, so this one
  /// call changes the greeting, the badges, what the lists are allowed to show
  /// and whether the close buttons exist.
  ///
  /// It deliberately does *not* reset the litres or the XP. Those belong to the
  /// person and not to the session, so switching away and back finds them where
  /// they were left — including credit somebody else earned for you while you were
  /// gone.
  static void use(Persona p) {
    fullName = p.name;
    _call = p.call;
    userEmail = p.email;
    userClass = p.klass;
    userPlace = p.place;
    joined = p.joined;
    isFixer = p.fixer;
    touch(); // what the lists may show changes with the person
  }

  /// Litres saved and XP, per person on this phone.
  ///
  /// A report belongs to whoever filed it, so the credit for fixing one has to
  /// reach them even when somebody else is signed in: the head closes a student's
  /// report, and it is the student's tank that rises. Seeded from the saved
  /// accounts, and owned by the app after that. Somebody who types a brand new
  /// address starts at nothing, which is the truth.
  static final litresBy = <String, int>{for (final p in saved) p.call: p.litres};
  static final xpBy = <String, int>{for (final p in saved) p.call: p.xp};

  static int get xp => xpBy[userName] ?? 0;
  static set xp(int v) => xpBy[userName] = v;

  /// Grows when a leak you reported is marked fixed, which is what makes the
  /// tank rise and the impact bars move during a demo.
  static int get yourLitres => litresBy[userName] ?? 0;
  static set yourLitres(int v) => litresBy[userName] = v;

  /// The class a person on this phone belongs to, and nothing for somebody it does
  /// not know — which is most of AquaAlert and every name in the fixture.
  static String classOf(String call) =>
      saved.where((p) => p.call == call).map((p) => p.klass).firstOrNull ?? '';

  static const campusLitres = 214000;
  static const allLitres = 1870000;

  /// Your own monthly target — the line drawn across the tank, and the figure the
  /// settings screen lets you change.
  ///
  /// Per person, like the litres it is measured against: one shared number would
  /// have the head's target deciding how full a student's glass looks. Writing it
  /// says so out loud, because the dashboard is a tab that stays alive in an
  /// IndexedStack behind settings — it redraws when the store moves and not when a
  /// screen it cannot see calls setState.
  static final goalBy = <String, int>{};
  static int get monthlyGoal => goalBy[userName] ?? 10000;
  static set monthlyGoal(int v) {
    goalBy[userName] = v;
    touch();
  }

  /// Settings that actually do something. Motion gates the tank's accelerometer,
  /// haptics gate the tap feedback on every clay control.
  static bool motion = true;
  static bool haptics = true;

  /// Bumped whenever the store changes shape: a report filed, a status moved, an
  /// account swapped. The four tabs live in an IndexedStack and stay alive while
  /// you are on another one, so a list you are not looking at never rebuilds by
  /// itself — which is why a report you had just filed was missing from Reports
  /// until you happened to touch a filter. Every list listens to this instead.
  static final revision = ValueNotifier<int>(0);

  /// Say the data moved. Called by everything that writes.
  static void touch() => revision.value++;

  static final leaks = <Leak>[
    Leak(
      id: 'AA-118',
      confirms: 2,
      title: 'Tap left running',
      scope: Scope.school,
      place: 'Block B, near the stairs',
      litresPerDay: 240,
      daysOpen: 6,
      status: Status.overdue,
      reporter: 'Aarav S.',
      description: 'Left tap will not close fully. Water runs all day.',
    ),
    Leak(
      id: 'AA-117',
      confirms: 4,
      title: 'Overflowing tank',
      scope: Scope.community,
      place: '12, Nehru Road — near the bus stop',
      litresPerDay: 900,
      daysOpen: 2,
      status: Status.inProgress,
      reporter: 'Meera K.',
      photo: 'assets/demo/tank.jpg',
      lat: 28.7012,
      lng: 77.1338,
      description: 'The street tank overflows every morning around 7.',
    ),
    // No photo, like everything else filed inside the school: the words are the
    // report in there. See [Leak.photo].
    Leak(
      id: 'AA-116',
      confirms: 3,
      title: 'Burst pipe',
      scope: Scope.school,
      place: 'Corridor outside the lab',
      litresPerDay: 400,
      daysOpen: 4,
      status: Status.fixed,
      reporter: 'Rehan',
      description: 'Joint had split. Maintenance replaced it.',
    ),
    Leak(
      id: 'AA-115',
      confirms: 6,
      title: 'Leaking street valve',
      scope: Scope.community,
      place: 'Gandhi Chowk, opposite the chemist',
      litresPerDay: 1500,
      daysOpen: 9,
      status: Status.fixed,
      reporter: 'Ishaan P.',
      photo: 'assets/demo/street.jpg',
      lat: 28.6938,
      lng: 77.1401,
    ),
    Leak(
      id: 'AA-114',
      title: 'Washbasin dripping',
      scope: Scope.school,
      place: 'Wing B washroom, first floor',
      litresPerDay: 120,
      daysOpen: 1,
      status: Status.reported,
      reporter: 'Nikhil R.',
    ),
    Leak(
      id: 'AA-113',
      confirms: 3,
      title: 'Rooftop tank overflowing',
      scope: Scope.community,
      place: 'C-Block, Pitampura — terrace',
      litresPerDay: 700,
      daysOpen: 4,
      status: Status.overdue,
      reporter: 'Neha B.',
      photo: 'assets/demo/rooftop.jpg',
      lat: 28.6996,
      lng: 77.1424,
      description: 'The float valve is stuck, so it spills down the wall every time '
          'the supply comes.',
    ),
    Leak(
      id: 'AA-112',
      confirms: 5,
      title: 'Street valve cracked',
      scope: Scope.community,
      place: 'Ring Road, outside the sweet shop',
      litresPerDay: 1100,
      daysOpen: 6,
      status: Status.inProgress,
      // A name from the community board, so the same people run through the
      // reports and the leaderboard.
      reporter: 'Imran S.',
      photo: 'assets/demo/valve.jpg',
      lat: 28.6949,
      lng: 77.1312,
      description: 'The joint on the valve chamber has split and it has been running '
          'across the road for days.',
    ),
    Leak(
      id: 'AA-111',
      confirms: 1,
      title: 'Hand pump running',
      scope: Scope.community,
      place: 'Gali No. 4, behind the market',
      litresPerDay: 320,
      daysOpen: 3,
      status: Status.reported,
      reporter: 'Farhan Q.',
      photo: 'assets/demo/handpump.jpg',
      lat: 28.7003,
      lng: 77.1291,
      description: 'The handle will not seat, so it keeps running when nobody is using it.',
    ),
    Leak(
      id: 'AA-110',
      confirms: 2,
      title: 'Water cooler leaking',
      scope: Scope.community,
      place: 'Community centre, ground floor',
      litresPerDay: 180,
      daysOpen: 2,
      status: Status.fixed,
      reporter: 'Kavita',
      photo: 'assets/demo/cooler.jpg',
      lat: 28.6962,
      lng: 77.1372,
      description: 'The tap washer had gone. The caretaker changed it the same evening.',
    ),
  ];

  /// Whether this account is allowed to see a report at all. A community report
  /// is public to everyone on AquaAlert; anything filed inside an institution
  /// never leaves it. That rule is the reason a student files to the school in
  /// the first place — the corridor outside the lab is nobody else's business,
  /// and the head is the person who can actually get it fixed.
  static bool canSee(Leak l) => l.scope == Scope.community || joined;

  /// Every list, counter and feed in the app reads this, never [leaks]. One
  /// gate, so a school report cannot leak out through a screen somebody forgot.
  static List<Leak> get visible => leaks.where(canSee).toList();

  /// What the dashboard calls recent: the three filed most lately, by how long
  /// they have been open rather than by where they happen to sit in the fixture.
  static List<Leak> get recent {
    final list = visible..sort((a, b) => a.daysOpen - b.daysOpen);
    return list.take(3).toList();
  }

  /// Every class in the school, sections A to E of classes 9, 10 and 11 — the
  /// three years the event runs for. Litres are stated per class rather than
  /// generated at random, so the board is the same every time it is opened and a
  /// demo can point at a row and talk about it. They move from there: [credit]
  /// adds a fixed school leak to its reporter's class.
  static final classes = <ClassRow>[
    ClassRow('Class 10-B', 42800, 38),
    ClassRow('Class 9-C', 39100, 41), // Rehan's, second and chasing
    ClassRow('Class 11-A', 36500, 35),
    ClassRow('Class 10-D', 33200, 40),
    ClassRow('Class 9-A', 31600, 37),
    ClassRow('Class 11-C', 29800, 33),
    ClassRow('Class 10-A', 27400, 39),
    ClassRow('Class 9-E', 25100, 36),
    ClassRow('Class 11-E', 23700, 34),
    ClassRow('Class 10-C', 22900, 38),
    ClassRow('Class 9-B', 20400, 40),
    ClassRow('Class 11-B', 18600, 35),
    ClassRow('Class 10-E', 16300, 37),
    ClassRow('Class 9-D', 14800, 39),
    ClassRow('Class 11-D', 12200, 32),
  ];

  /// The class board, highest first. Sorted on the way out rather than kept in
  /// order, because the litres move now: fix a leak in school and a class climbs,
  /// which a list authored in descending order would quietly stop reflecting.
  static List<ClassRow> get board => [...classes]..sort((a, b) => b.litres - a.litres);

  /// Top few only, plus your own row. A named public ranking of every child
  /// means some child is visibly last in a school app.
  static const topStudents = <Student>[
    Student(1, 'Aarav S.', 'Class 9-C', 14200),
    Student(2, 'Meera K.', 'Class 10-B', 12800),
    Student(3, 'Ishaan P.', 'Class 12-C', 11500),
  ];

  /// The board that matters: everyone on AquaAlert, wherever they report from.
  /// Campus and community litres are summed — a leak fixed on a street counts
  /// exactly the same as one fixed in a corridor.
  static const topSavers = <Student>[
    Student(1, 'Sunita R.', 'Jaipur', 41200),
    Student(2, 'Imran S.', 'Delhi', 38600),
    Student(3, 'Faizan A.', 'Lucknow', 29400),
  ];
  static Student get you => Student(9, 'You', userLine, yourLitres);

  static const badges = <Award>[
    Award('First report', Icons.flag_rounded, true, 'File your first report'),
    Award('Quick spotter', Icons.bolt_rounded, true, 'Report a leak within a day of it starting'),
    Award('Fixed five', Icons.check_circle_rounded, true, 'Five of your reports get fixed'),
    Award('Tank saver', Icons.water_drop_rounded, true, 'Save 5,000 litres'),
    Award('Sharp eye', Icons.visibility_rounded, true, 'Ten reports confirmed real'),
    Award('Follow through', Icons.replay_rounded, true, 'Chase a leak until it is fixed'),
    Award('Campus hero', Icons.school_rounded, false, 'Top of your school for a month'),
    Award('Ten thousand', Icons.savings_rounded, false, 'Save 10,000 litres'),
    Award('Streak of seven', Icons.calendar_month_rounded, false, 'Report on seven different days'),
    Award('Event winner', Icons.emoji_events_rounded, false, 'Win a school event'),
    Award('Neighbourhood watch', Icons.location_city_rounded, false, 'Twenty community reports'),
    Award('Reservoir', Icons.waves_rounded, false, 'Reach the Reservoir level'),
  ];

  static const notifs = <Notif>[
    Notif('Leak reported near you', 'Hand pump running in Gali No. 4 — 400m away.', '40m',
        Status.reported, 'AA-111', NotifKind.near),
    Notif('Your report was fixed', 'AA-116 — burst pipe outside the lab. 1,600 litres saved.', '2h', Status.fixed, 'AA-116'),
    Notif('Still not fixed', 'AA-118 has been open for six days. Two people have seen it.', '5h', Status.overdue, 'AA-118'),
    Notif('Maintenance started', 'AA-117 — overflowing tank on Nehru Road.', 'Yesterday', Status.inProgress, 'AA-117'),
    Notif('Report confirmed', 'Two people nearby have seen AA-118 too. +20 XP.', '2 days', Status.reported, 'AA-118'),
    Notif('Water Week Challenge is live', 'Six days left. Your class is second by 3,700 litres.',
        '2 days', Status.reported, null, NotifKind.event),
  ];

  /// Which notices this account wants at all — the three switches in settings,
  /// held here rather than in that screen so turning one off actually empties a
  /// row out of the feed.
  static final notify = <NotifKind, bool>{
    NotifKind.status: true,
    NotifKind.near: true,
    NotifKind.event: false,
  };

  /// The notices this account may read. A notice about a report it cannot see
  /// would tell an outsider exactly what a school filed, which is the leak the
  /// scope rule exists to stop.
  static List<Notif> get feed {
    final seen = visible.map((l) => l.id).toSet();
    return notifs
        .where((n) => notify[n.kind]!)
        .where((n) => n.leak == null || seen.contains(n.leak))
        .toList();
  }

  /// How many of the newest notices have not been read yet. It lives here and
  /// not in the notifications screen because two widgets need the one fact: that
  /// screen frosts the unread cards, and the nav bell draws the dot. With the
  /// count private to the screen, marking everything read left the dot lit.
  static int _unread = 2;
  static int get unread => math.min(_unread, feed.length);
  static void readAll() {
    _unread = 0;
    touch();
  }

  static const event = EventInfo('Water Week Challenge', '18–24 August', 'Trophy for the winning class', 15, 6);

  /// Whether anybody is signed in. The gate at the root of the app watches this,
  /// so signing out is one assignment from wherever the button happens to be
  /// rather than a callback threaded down through four widgets.
  static final session = ValueNotifier<bool>(false);

  /// Starts a session. There is no database in this prototype, so signing in is
  /// simply the app agreeing to call you by your name for as long as it is open.
  /// A typed address is a brand new account: community only, no fixer powers.
  /// Coming in as one of the [saved] people goes through [use] instead.
  static void signIn({required String email, required String name}) {
    if (name.trim().isNotEmpty) fullName = name.trim();
    // Nothing to go on for a typed name, so the first word it is.
    _call = fullName.split(' ').first;
    userEmail = email.trim();
    joined = false;
    isFixer = false;
    userClass = '';
    userPlace = 'Delhi';
  }

  /// Ends it. The reports stay — they belong to the neighbourhood, not to the
  /// phone — and the next person to sign in comes to a feed they have not read.
  static void signOut() {
    _unread = 2;
    session.value = false;
    touch();
  }

  /// What the app calls you, changed from settings. Both names move together, or
  /// the greeting and the avatar start disagreeing — and the reports you signed
  /// move with them, since a report is yours by carrying your name and nothing
  /// else. Rename yourself without that and your own list goes empty.
  static void rename(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final was = _call;
    fullName = clean;
    // What it calls you only changes when the new name stops containing it:
    // "Mohd Rehan" is Rehan, so opening that sheet and saving it untouched must
    // not start greeting him as Mohd. A name it has never seen falls back to the
    // first word, which is all a typed string gives you.
    final words = clean.split(RegExp(r'\s+'));
    _call = words.contains(was) ? was : words.first;
    for (final l in leaks) {
      if (l.reporter == was) l.reporter = _call;
    }
    touch();
  }

  static String userEmail = 'rehan@example.com';

  /// Files a report from the form. In-memory, because the brief is a prototype
  /// with no database: it shows up in Reports, on the dashboard and in the
  /// counters immediately, and it is gone when the app closes.
  static Leak file({
    required Scope scope,
    required String title,
    required String place,
    required int litresPerDay,
    String description = '',
    String? photo,
    double? lat,
    double? lng,
  }) {
    final leak = Leak(
      id: 'AA-${119 + _filed++}',
      title: title,
      scope: scope,
      place: place,
      litresPerDay: litresPerDay,
      daysOpen: 0,
      status: Status.reported,
      reporter: userName,
      description: description,
      photo: photo,
      lat: lat,
      lng: lng,
    );
    leaks.insert(0, leak);
    touch();
    return leak;
  }

  static int _filed = 0;

  /// Credits the litres a fixed leak will no longer waste, and the XP that comes
  /// with it — to whoever *reported* it, never to whoever happened to close it.
  /// That is the whole shape of the thing: a student files it, the head mends it,
  /// and the student's tank is what rises.
  static void credit(Leak leak) {
    final saved = leak.litresSaved;
    if (saved > 0) {
      litresBy[leak.reporter] = (litresBy[leak.reporter] ?? 0) + saved;
      xpBy[leak.reporter] = (xpBy[leak.reporter] ?? 0) + (saved / 20).round();
      // Fixed inside the school, so it counts for the reporter's class too — which
      // is the number the event and the class board are actually about.
      final klass = classOf(leak.reporter);
      if (leak.scope != Scope.community && klass.isNotEmpty) {
        final row = classes.where((c) => c.name == klass).firstOrNull;
        if (row != null) row.litres += saved;
      }
    }
    touch();
  }

  /// Somebody nearby says they can see it too. One vouch per person, remembered on
  /// the report itself: leaving the screen, or coming back as somebody else, must
  /// not let the same person vouch twice. Returns false if they already have.
  static bool confirm(Leak leak) {
    if (!leak.confirmedBy.add(userName)) return false;
    leak.confirms++;
    touch();
    return true;
  }

  // Counted from what this account can see, or the tiles would promise reports
  // the list underneath them refuses to show.
  static int get openCount => visible.where((l) => l.status != Status.fixed).length;
  static int get fixedCount => visible.where((l) => l.status == Status.fixed).length;
  static int get overdueCount => visible.where((l) => l.status == Status.overdue).length;
  static List<Leak> get queue => visible.where((l) => l.status != Status.fixed).toList();
}
