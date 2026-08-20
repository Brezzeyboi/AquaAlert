import 'package:flutter/material.dart';

import '../theme.dart';

/// Where a report lives. This is a *visibility* scope, not a place — a school
/// report is words only and visible to that school; the litres always count
/// everywhere. See [Leak.visibleTo].
enum Scope { school, college, community }

enum Status { reported, inProgress, overdue, fixed }

extension StatusLook on Status {
  String get label => switch (this) {
        Status.reported => 'Reported',
        Status.inProgress => 'In progress',
        Status.overdue => 'Still not fixed!',
        Status.fixed => 'Fixed',
      };

  Color get color => switch (this) {
        Status.reported => A.accent,
        Status.inProgress => A.accentDeep,
        Status.overdue => A.amber,
        Status.fixed => A.green,
      };

  IconData get icon => switch (this) {
        Status.reported => Icons.flag_outlined,
        Status.inProgress => Icons.build_outlined,
        Status.overdue => Icons.priority_high_rounded,
        Status.fixed => Icons.check_rounded,
      };
}

class Leak {
  Leak({
    required this.id,
    required this.title,
    required this.scope,
    required this.place,
    required this.litresPerDay,
    required this.daysOpen,
    required this.status,
    required this.reporter,
    this.description = '',
    String? photo,
    this.lat,
    this.lng,
    this.confirms = 0,
  }) : _photo = photo;

  final String id, title, place, description;

  /// Who filed it. Not final: renaming yourself in settings re-signs what you
  /// filed, because "your reports" is worked out by matching this against your
  /// name — leave it alone and your own list empties itself and the button to
  /// close your own report disappears.
  String reporter;
  final Scope scope;
  final int litresPerDay, daysOpen;

  /// Where it is, for the community reports that carry a location at all. A
  /// campus report deliberately has none: the block and floor are the address,
  /// and pinning a child's school on a map helps nobody.
  final double? lat, lng;

  /// Asset path of the report's photo, or null when there is none. A bundled
  /// asset stands in for Supabase storage; the lists and the detail screen only
  /// ever ask "is there a photo and where", so swapping in a network URL later
  /// is a one-line change.
  final String? _photo;

  /// The picture — and only ever for a community report.
  ///
  /// A photograph taken inside a school is a photograph *of* a school: its
  /// corridors, its washrooms, and the children in them. Inside a building the
  /// words are the report, which is why the form does not offer a camera there.
  /// The rule lives on this one getter rather than in every list, card, share
  /// sheet and detail screen that draws a thumbnail, so a fixture or a later
  /// writer cannot hand one out by accident. Same reason a campus report carries
  /// no coordinates: what keeps the picture off the screen is that there is
  /// nothing to fetch, not a filter somebody has to remember.
  String? get photo => scope == Scope.community ? _photo : null;
  Status status;

  /// How many people nearby have said "yes, this is real". AquaAlert has no
  /// inspector and no admin: a report earns its credibility from the people who
  /// can see the leak with their own eyes, which is the whole model.
  int confirms;

  /// Which of them were on this phone. The count above starts from the fixture, so
  /// this is what stops one person vouching twice by reopening the screen or by
  /// switching accounts and back.
  final Set<String> confirmedBy = {};

  /// A school or college report carries no photo and no map — only people who
  /// joined that institution can see it at all.
  String get visibleTo => switch (scope) {
        Scope.school => 'Visible to your school only',
        Scope.college => 'Visible to your college only',
        Scope.community => 'Visible to everyone on AquaAlert',
      };

  /// The tag a row wears when it is not public, and nothing when it is. Two
  /// reports side by side look identical otherwise, and which of them left the
  /// building is the one thing you cannot read off the words.
  String? get scopeTag => switch (scope) {
        Scope.school => 'School',
        Scope.college => 'College',
        Scope.community => null,
      };

  /// What this report has stopped being wasted, once somebody marks it fixed.
  ///
  /// A leak reported and mended on the same day still saved water — hours of it —
  /// so a same-day fix counts as one day rather than as nothing. Without that floor
  /// the whole loop reads as broken: file a report, fix it, and the app credits you
  /// zero litres for it.
  int get litresSaved =>
      status == Status.fixed ? litresPerDay * (daysOpen < 1 ? 1 : daysOpen) : 0;
}

/// XP levels. Reservoir is the ceiling; the names are the water cycle.
const levels = <String, int>{
  'Droplet': 0,
  'Puddle': 250,
  'Stream': 750,
  'River': 1800,
  'Lake': 4000,
  'Reservoir': 9000,
};

class Level {
  const Level(this.name, this.next, this.into, this.span);
  final String name;
  final String? next;
  final int into, span;
  double get progress => span == 0 ? 1 : (into / span).clamp(0, 1);
}

/// XP -> level, plus how far into it. Reservoir has no next, so it sits full.
Level levelOf(int xp) {
  final names = levels.keys.toList();
  var i = 0;
  while (i + 1 < names.length && xp >= levels[names[i + 1]]!) {
    i++;
  }
  final base = levels[names[i]]!;
  if (i + 1 == names.length) return Level(names[i], null, 0, 0);
  return Level(names[i], names[i + 1], xp - base, levels[names[i + 1]]! - base);
}

/// Not called Badge: material.dart exports a Badge widget, and any file that
/// imported both would stop compiling on an ambiguous name.
class Award {
  const Award(this.name, this.icon, this.earned, this.how);
  final String name, how;
  final IconData icon;
  final bool earned;
}

class ClassRow {
  ClassRow(this.name, this.litres, this.students);
  final String name;

  /// Not final: a leak fixed inside the school lands on its reporter's class, so
  /// the board is something the app moves rather than a table it prints.
  int litres;

  final int students;
}

class Student {
  const Student(this.rank, this.name, this.className, this.litres);
  final int rank, litres;
  final String name, className;
}

/// The three things AquaAlert tells you about, and the three switches in
/// settings. A notice carries its kind so a switch that is off actually silences
/// something instead of just moving.
enum NotifKind { status, near, event }

class Notif {
  const Notif(this.title, this.body, this.ago, this.status,
      [this.leak, this.kind = NotifKind.status]);
  final String title, body, ago;
  final Status status;

  /// Which report it is about, when it is about one. A notice about a school
  /// report has no business showing up for somebody outside that school, so the
  /// feed drops any notice whose report the account cannot see.
  final String? leak;

  final NotifKind kind;
}

/// An account already signed in on this phone. A prototype has no database, so
/// switching person is picking one of these — which is also how a shared phone
/// behaves once two people have used the app on it.
class Persona {
  const Persona(
    this.name,
    this.email,
    this.role, {
    required this.call,
    required this.place,
    required this.joined,
    required this.klass,
    required this.fixer,
    required this.xp,
    required this.litres,
  });

  final String name, email, role, place;

  /// What the app calls them to their face, and what their reports are signed
  /// with. Not always the first word of the name — "Mohd Rehan" is Rehan — so it
  /// is stated here rather than guessed from the string.
  final String call;

  /// Their class, or 'Staff' for someone who works there. Empty for an account
  /// that has joined nothing — most of AquaAlert.
  final String klass;

  final bool joined, fixer;
  final int xp, litres;
}

class EventInfo {
  const EventInfo(this.name, this.dates, this.prize, this.classes, this.days);
  final String name, dates, prize;
  final int classes, days;
}
