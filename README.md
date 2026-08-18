# AquaAlert

**Spot the Leak. Save the Water.**

A community water-leak reporting app for **UN SDG 6 - Clean Water and Sanitation**.
Anyone can report a leak they walk past: a running tap, a burst pipe, an
overflowing tank. The people nearby confirm it is real, whoever can fix it closes
it, and the app counts the litres that stopped running.

Community first. Reporting needs no school, no login gate and no official - an
adult, a student, a social worker or a municipal crew all use the same app.
Joining a school or college is an extra that adds its leaderboard, its events and
a place to file the leaks that are inside the building.

## What it does

- **Report** a leak in the open, or inside a school you have joined
- **Confirm** somebody else's report - there is no admin in this app, a report
  earns its credibility from the people who can see the leak
- **Track** it: reported -> in progress -> fixed, or flagged as still not fixed
- **Count** the litres saved, per person, per class and across everyone
- **Map** every located report on a drawn neighbourhood map - no API key, no
  network, pins projected from real coordinates
- **Compete** on the community and class boards, climb the water-cycle levels
  (Droplet -> Reservoir) and collect badges

## The rule that shapes it

A report filed inside a school never leaves that school. It carries no
coordinates and no map, and only people who joined that institution can see it or
the notices about it. Everything else is public to everyone on AquaAlert. That
single rule is enforced in one place - `Store.canSee` - so no screen can leak it.

## Prototype, deliberately

There is no database and no network. `lib/data/store.dart` is the entire
persistence layer: in memory, for the length of one run. Report photos are
bundled assets, the map is drawn rather than fetched, and the tank's water is a
small physics simulation driven by the phone's own sensors. The brief was a
prototype that works on a stage with no wifi.

## Try it

Three accounts are already "signed in on this phone":

| Account | Who they are |
| --- | --- |
| Mohd Rehan | student, Class 9-C at Maxfort Pitampura |
| Kavita Sharma | community member, no institution - sees nothing the school filed |
| Anil Verma | school head - can close other people's reports |

Join code for Maxfort Pitampura: **MX7412**

```bash
flutter pub get
flutter run                     # a phone or emulator
flutter build apk --release     # or an installable APK
flutter analyze && flutter test
```

## Layout

| Path | What is in it |
| --- | --- |
| `lib/screens/` | one file per screen, plus the splash and the drawn map |
| `lib/widgets/` | the clay design system, the water tank, the leak card |
| `lib/data/` | the in-memory store and the mock model |
| `lib/theme.dart` | every colour, shadow, radius and text style in the app |
| `design/mockups/` | the 24 mockups the build follows |
| `design/prototype/` | the HTML splash the Flutter splash is ported from |
| `test/` | logic, physics, map geometry and a full walk through the app |

Built with Flutter. SDG 6 cyan is `#26BDE2` throughout.
