# AquaAlert — project brief

**Spot the Leak. Save the Water.**
A community water-leak reporting app for **UN SDG 6 — Clean Water and Sanitation**.
Built as an interschool-competition prototype: Flutter, Android, no backend.

---

## The problem

A dripping tap in a school corridor or a cracked valve on a street runs for days,
not because nobody notices it but because noticing has nowhere to go. There is no
shared record, so the second person to walk past cannot tell whether it has been
reported already, nobody can tell whether it was ever fixed, and the water lost
is never counted — so it never becomes a number anyone can act on.

## The idea

Anyone reports a leak they walk past, with a photo and a place. The people nearby
confirm it is real. Whoever can fix it closes it. The app counts the litres that
stopped running, for the person, their class and everyone.

Community first: reporting needs no school and no permission. Joining a school or
college is an extra that adds its leaderboard, its event, and a private place to
file the leaks that are inside the building.

## Who uses it

| | |
| --- | --- |
| **Anyone in the community** | reports street leaks, confirms other people's, counts their own litres |
| **A student** | the same, plus reports inside the school and competes for their class |
| **Whoever fixes things** — a caretaker, a plumber, the school office, a municipal crew | can start work on and close other people's reports |

There is no admin, no inspector and no moderator. A report earns its credibility
from the people who can see the leak with their own eyes.

## What it does

- **Report** — photo, place, type of leak, and how bad it is on a slider that
  converts words into litres a day
- **Confirm** — "I've seen it too" on somebody else's report; the count is shown
  on the report's own timeline
- **Track** — reported → in progress → fixed, and flagged as *still not fixed*
  when it has been open too long
- **Count** — litres saved per person, per class and across everyone, credited
  only when a report is marked fixed
- **Map** — every located report on a drawn neighbourhood map, with distance
- **Compete** — the community board, the class board, six water-cycle levels
  (Droplet → Reservoir) and twelve badges

## The rules that shape it

1. **A school report never leaves the school.** It carries no coordinates and no
   map; only people who joined that institution see it or the notices about it.
   Enforced in one place (`Store.canSee`), so no screen can leak it by accident.
2. **Litres only count once a leak is fixed** — so the score measures water saved,
   not reports filed, and reporting the same tap twice wins nothing.
3. **Closing your own report is always allowed**; closing somebody else's needs
   the fixer role. Everyone else can confirm.
4. **The school event counts what the school fixes.** Street reports still count
   everywhere else in the app; they are simply not that competition.

## Design

One material, consistently: soft clay lit from the top-left, where a shadow is
never black — it is the surface's own hue walked towards slate. The accent is
**#26BDE2**, the colour SDG 6 is recognised by, so the app looks like what it is
about. Liquid glass is rationed to three places (the nav bar, unread notices, the
moment panels) and the comic layer — halftone dots, ink dashes, starbursts —
appears only as feedback or to mark a moment.

The water tank is the one skeuomorphic object in the app and the only thing
allowed real glass and real motion. Everything else is clay.

## How it is built

- **Flutter**, Android, one dependency of consequence (`sensors_plus`)
- **No database and no network.** `lib/data/store.dart` is the whole persistence
  layer: in memory, for the length of one run. Swapping in Supabase later touches
  that file and nothing else
- **The map is drawn**, not tiled: roads, blocks, park, water works and the metro
  are stated in metres from the user's position and projected the same way the
  pins are. No API key, no tiles to load, works with the wifi off
- **The tank's water is simulated** — forty-four columns with height and velocity,
  pulled towards the level gravity says the surface should sit at and coupled to
  their neighbours, driven by the phone's accelerometer and gyroscope
- **The splash** is a ported 2.2-second animation: a drop falls, the water punches
  up, ripples and ink leave, the name arrives, and the SDG 6 mark last
- **Everything visual is painted or drawn in code** except eight report photos, a
  launcher render and one variable font, so the app is fully offline

## Checks

`flutter analyze` clean and **27 tests**: the litre maths and Indian digit
grouping, XP levels, the school-visibility rule, the community confirmation loop,
the water physics (it sloshes, it settles, it never invents water, and a hard
shake cannot make it go wild), the map projection and distances, and a full walk
through the app from splash to filing a report.

GitHub Actions runs the analyser and the suite on every push, then builds and
publishes the release APK as a **GitHub Release** — installable without a Flutter
toolchain.

## Honest limits

- No backend: everything resets when the app closes. That was the brief
- The camera is stood in for by bundled photos the reporter picks from
- Location is stated rather than read from GPS, so there is no permission dialog
- The litres-per-leak figures are placeholders and are marked as such in the code
  (`TODO(citation)`); they need a sourced table before any number is quoted
- Google sign-in is a button with no provider behind it yet

## Try it

Three accounts are already on the sign-in screen: **Mohd Rehan** (student, Class
9-C), **Kavita Sharma** (community member, no school — sees nothing the school
filed), **Anil Verma** (school head, can close other people's reports). The join
code for Maxfort Pitampura is **MX7412**.

Repo and installable APK: <https://github.com/Brezzeyboi/AquaAlert/releases>
