import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/leak_card.dart';
import 'leak_detail.dart';

/// The neighbourhood, drawn. No tile server, no API key, no network: the roads,
/// blocks, park and water works below are stated in metres from [Store.originLat]
/// / [Store.originLng] and projected the same way the pins are, so a report sits
/// on the road its address names.
///
/// This is honest about being a prototype and it costs nothing on stage. Swapping
/// in real tiles later is one widget — every report already carries coordinates.
///
/// School reports never appear here. They carry no coordinates by design, so the
/// rule that keeps a corridor off a public map is the absence of the number
/// rather than a filter somebody has to remember to write.

/// Turns coordinates into pixels for a fixed window around the origin. One place,
/// so the painter and the tap handler agree on where a pin is: a map where the pin
/// you see is not the pin you hit is worse than no map at all.
class MapView {
  const MapView(this.size, {this.spanM = 1450});

  final Size size;

  /// How many metres across the canvas covers.
  final double spanM;

  double get scale => size.width / spanM; // pixels per metre

  /// Metres east and north of the origin, as a point on the canvas.
  Offset at(double east, double north) =>
      Offset(size.width / 2 + east * scale, size.height / 2 - north * scale);

  Offset of(double lat, double lng) => at(
        (lng - Store.originLng) * 111320 * math.cos(Store.originLat * math.pi / 180),
        (lat - Store.originLat) * 110570,
      );
}

/// One street: a name, a width in metres, and its line in metres from the origin.
/// Written out rather than generated — a made-up city looks made up, and this one
/// has to match the addresses the reports already use.
class _Road {
  const _Road(this.name, this.width, this.line, {this.label = true});
  final String name;
  final double width;
  final List<(double, double)> line;
  final bool label;
}

const _roads = <_Road>[
  // The two big ones. Parwana Road runs north-west to south-east through the
  // colony; Ring Road is the arterial down the east side.
  _Road('Parwana Road', 21, [(-880, 640), (-420, 300), (60, -40), (430, -360), (760, -700)]),
  _Road('Outer Ring Road', 26, [(600, 980), (640, 420), (610, -120), (660, -680), (700, -980)]),
  // The cross streets the reports are addressed on.
  _Road('Nehru Road', 16, [(-900, -220), (-320, -190), (240, -150), (700, -130)]),
  _Road('Netaji Marg', 14, [(-880, 340), (-300, 300), (250, 250), (620, 230)]),
  _Road('Gandhi Chowk', 13, [(-40, 620), (10, 120), (60, -420), (90, -880)],
      label: false),
  // Lanes. Unlabelled: a map with a name on every alley is unreadable at this
  // size, and these are here to make the blocks feel like blocks.
  _Road('', 7, [(-620, 700), (-600, -700)], label: false),
  _Road('', 7, [(-330, 640), (-300, -660)], label: false),
  _Road('', 7, [(300, 700), (330, -720)], label: false),
  _Road('', 7, [(-880, 60), (620, 40)], label: false),
  _Road('', 7, [(-880, -520), (640, -480)], label: false),
  _Road('', 6, [(-860, 520), (560, 470)], label: false),
];

/// The metro, because this is Delhi and a magenta dashed line with a station on it
/// is the single most recognisable thing on a map of it.
const _metro = [(-950.0, 900.0), (-300.0, 760.0), (350.0, 640.0), (980.0, 560.0)];
const _station = (150.0, 668.0);

/// Leaks near you: the drawn neighbourhood with every report that carries a
/// location on it. Tap a pin to see which report it is, tap the card to open it.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Leak? _picked;

  /// The pin under a tap, if any. Generous radius: a 26px pin on a phone needs a
  /// bigger target than its own outline, and the nearest one wins so two pins
  /// close together still resolve.
  void _tap(Offset spot, Size size) {
    final view = MapView(size);
    Leak? best;
    var near = 34.0;
    for (final l in Store.nearby) {
      final d = (view.of(l.lat!, l.lng!) - spot).distance;
      if (d < near) {
        near = d;
        best = l;
      }
    }
    setState(() => _picked = best);
  }

  @override
  Widget build(BuildContext context) {
    final pins = Store.nearby;
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
                  Expanded(child: Center(child: Text('Leaks near you', style: A.h3))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(child: _map(pins)),
            _footer(pins),
          ],
        ),
      ),
    );
  }

  /// The map itself, sunk into the page like every other window in this app.
  Widget _map(List<Leak> pins) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: ClayCard(
          padding: const EdgeInsets.all(7),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(A.rCard - 8),
            child: LayoutBuilder(
              builder: (_, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (e) => _tap(e.localPosition, size),
                  child: CustomPaint(
                    painter: _Neighbourhood(pins: pins, picked: _picked),
                    size: size,
                  ),
                );
              },
            ),
          ),
        ),
      );

  /// Either the legend, or the report you just tapped. The card replaces the
  /// legend rather than stacking on it: the legend has done its job by then.
  Widget _footer(List<Leak> pins) {
    final picked = _picked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: picked == null
            ? Column(
                children: [
                  // Wrapped, not a Row: three labelled dots do not fit across a
                  // narrow phone at a large text size.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      for (final (s, name) in [
                        (Status.reported, 'Open'),
                        (Status.overdue, 'Overdue'),
                        (Status.fixed, 'Fixed'),
                      ])
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(right: 6),
                              decoration:
                                  BoxDecoration(color: s.color, shape: BoxShape.circle),
                            ),
                            Text(name, style: A.tiny.copyWith(fontSize: 11)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pins.isEmpty
                        ? 'Nothing reported around you yet.'
                        : '${pins.length} reports within '
                            '${_km(Store.distanceKm(pins.last.lat!, pins.last.lng!))} · tap a pin',
                    style: A.tiny,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : _Card(picked, onClose: () => setState(() => _picked = null)),
      ),
    );
  }
}

/// Metres under a kilometre, one decimal above it — nobody says "0.32 km".
String _km(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// The report behind the pin you tapped: enough to recognise it and how far away
/// it is, and a tap opens it properly.
class _Card extends StatelessWidget {
  const _Card(this.leak, {required this.onClose});
  final Leak leak;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ClayCard(
        onTap: () => Navigator.of(context).push(
          A.route(LeakDetailScreen(leak, heroTag: 'map-${leak.id}')),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            LeakThumb(leak, width: 78, height: 60, heroTag: 'map-${leak.id}'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(leak.title,
                      style: A.h3.copyWith(fontSize: 15.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${_km(Store.distanceKm(leak.lat!, leak.lng!))} away · ${leak.place}',
                      style: A.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  ClayPill(leak.status.label,
                      color: leak.status.color, icon: leak.status.icon, dense: true),
                ],
              ),
            ),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 20, color: A.inkSoft),
              ),
            ),
          ],
        ),
      );
}

// The palette of a printed map rather than of the app: warm paper, pale blocks,
// white roads. The clay UI frames it; inside the frame it should look like a map.
const _land = Color(0xFFF2EFE9);
const _block = Color(0xFFDFD9CB);
const _blockEdge = Color(0xFFD0C8B6);
const _casing = Color(0xFFDBD4C5);
const _lane = Color(0xFFFBFAF7);
const _green = Color(0xFFD7E7CD);
const _blue = Color(0xFFC7E3EF);
const _metroInk = Color(0xFFCE4A82);
const _mapInk = Color(0xFF8B8474);

/// A building footprint in metres from the origin.
typedef _Block = (double east, double north, double w, double h);

/// The park and the water works: the two things that break up a grid of blocks and
/// tell you which part of town you are looking at.
const _park = (-430.0, -430.0, 300.0, 210.0);
const _works = (430.0, 470.0, 250.0, 170.0);

/// Worked out once, not per frame: a grid with a deterministic wobble, minus
/// anything that would sit in a road, in the park or in the water.
final List<_Block> _blocks = _layOut();

List<_Block> _layOut() {
  final out = <_Block>[];
  var seed = 7;
  double rand() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return (seed >> 8) % 1000 / 1000;
  }

  for (var e = -880.0; e <= 840; e += 104) {
    for (var n = -900.0; n <= 900; n += 92) {
      final east = e + rand() * 26, north = n + rand() * 20;
      final w = 76 + rand() * 24, h = 62 + rand() * 20;
      if (_onRoad(east, north, math.max(w, h) / 2 + 9)) continue;
      if (_inside(_park, east, north, 40) || _inside(_works, east, north, 40)) continue;
      out.add((east, north, w, h));
    }
  }
  return out;
}

bool _inside((double, double, double, double) box, double e, double n, double pad) =>
    (e - box.$1).abs() < box.$3 / 2 + pad && (n - box.$2).abs() < box.$4 / 2 + pad;

/// Is this point within [pad] metres of any road's centre line?
bool _onRoad(double e, double n, double pad) {
  for (final road in _roads) {
    for (var i = 0; i < road.line.length - 1; i++) {
      final a = road.line[i], b = road.line[i + 1];
      if (_toSegment(e, n, a.$1, a.$2, b.$1, b.$2) < pad + road.width / 2) return true;
    }
  }
  return false;
}

double _toSegment(double px, double py, double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  final len = dx * dx + dy * dy;
  final t = len == 0 ? 0.0 : (((px - ax) * dx + (py - ay) * dy) / len).clamp(0.0, 1.0);
  return math.sqrt(math.pow(px - ax - dx * t, 2) + math.pow(py - ay - dy * t, 2));
}

/// Draws the neighbourhood: ground, park, water, blocks, roads, the metro, the
/// labels, you, and a pin per report.
class _Neighbourhood extends CustomPainter {
  const _Neighbourhood({required this.pins, this.picked, this.plain = false});

  final List<Leak> pins;
  final Leak? picked;

  /// The dashboard preview: no labels and no legend-sized detail, because at
  /// 150px high the type would be mud.
  final bool plain;

  @override
  void paint(Canvas canvas, Size size) {
    final v = MapView(size, spanM: plain ? 1900 : 1450);
    canvas.drawRect(Offset.zero & size, Paint()..color = _land);
    _patch(canvas, v, _park, _green);
    _patch(canvas, v, _works, _blue);
    _buildings(canvas, v);
    _streets(canvas, v);
    _rail(canvas, v);
    if (!plain) _names(canvas, v, size);
    _you(canvas, v);
    for (final l in pins) {
      if (l != picked) _pin(canvas, v.of(l.lat!, l.lng!), l.status.color, false);
    }
    // The chosen one last, so it sits over its neighbours.
    if (picked != null) {
      _pin(canvas, v.of(picked!.lat!, picked!.lng!), picked!.status.color, true);
    }
    if (!plain) _scale(canvas, v, size);
  }

  /// A scale bar. Nothing says "this is a map" like knowing how far across it is,
  /// and it is the honest way to show that the pins are really placed.
  void _scale(Canvas canvas, MapView v, Size size) {
    const metres = 200.0;
    final len = metres * v.scale;
    final y = size.height - 16;
    const x = 14.0;
    final ink = Paint()
      ..color = _mapInk
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(x, y), Offset(x + len, y), ink);
    canvas.drawLine(Offset(x, y - 4), Offset(x, y + 1), ink);
    canvas.drawLine(Offset(x + len, y - 4), Offset(x + len, y + 1), ink);
    _label(canvas, Offset(x + len / 2, y - 11), '200 m', 8.5, _mapInk);
  }

  void _patch(Canvas canvas, MapView v, (double, double, double, double) box, Color c) {
    final centre = v.at(box.$1, box.$2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: box.$3 * v.scale, height: box.$4 * v.scale),
        const Radius.circular(10),
      ),
      Paint()..color = c,
    );
  }

  void _buildings(Canvas canvas, MapView v) {
    final fill = Paint()..color = _block;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _blockEdge;
    for (final b in _blocks) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: v.at(b.$1, b.$2), width: b.$3 * v.scale, height: b.$4 * v.scale),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, edge);
    }
  }

  Path _path(MapView v, List<(double, double)> line) {
    final p = Path();
    for (var i = 0; i < line.length; i++) {
      final o = v.at(line[i].$1, line[i].$2);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  /// Casing under fill, the way every printed map does it: it is the dark edge
  /// that makes a white line read as a road rather than as a gap.
  void _streets(Canvas canvas, MapView v) {
    for (final road in _roads) {
      final path = _path(v, road.line);
      final w = math.max(3.2, road.width * v.scale * 2.1);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 2.4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = _casing,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = road.width >= 13 ? Colors.white : _lane,
      );
      // A dashed centre line on the two arterials only.
      if (road.width < 20) continue;
      canvas.drawPath(
        _dash(path, 9, 7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFE9C86A),
      );
    }
  }

  /// Splits a path into dashes. Flutter has no dash support, so this walks the
  /// metrics and copies alternate slices.
  Path _dash(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  /// The metro: a magenta dashed line and a station ring. Instantly says Delhi.
  void _rail(Canvas canvas, MapView v) {
    final line = _path(v, _metro);
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..color = _metroInk.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      _dash(line, 7, 5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = _metroInk,
    );
    final s = v.at(_station.$1, _station.$2);
    canvas.drawCircle(s, 5, Paint()..color = Colors.white);
    canvas.drawCircle(
      s,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _metroInk,
    );
  }

  /// Street names along their own longest stretch, plus the park, the water works
  /// and the station. Labels are most of what makes a drawing read as a map.
  void _names(Canvas canvas, MapView v, Size size) {
    for (final road in _roads) {
      if (!road.label) continue;
      var best = 0.0;
      var at = 0;
      for (var i = 0; i < road.line.length - 1; i++) {
        final a = road.line[i], b = road.line[i + 1];
        final len = math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
        if (len > best) {
          best = len;
          at = i;
        }
      }
      final a = v.at(road.line[at].$1, road.line[at].$2);
      final b = v.at(road.line[at + 1].$1, road.line[at + 1].$2);
      var angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      // Never upside down: a label at 170° reads as gibberish.
      if (angle.abs() > math.pi / 2) angle += math.pi;
      _label(canvas, a + (b - a) * 0.32, road.name, 9.5, _mapInk,
          angle: angle, bounds: size);
    }
    _label(canvas, v.at(_park.$1, _park.$2), 'D-Block Park', 9.5, const Color(0xFF6E8C5E));
    _label(canvas, v.at(_works.$1, _works.$2), 'Water works', 9.5, const Color(0xFF5B8798));
    _label(canvas, v.at(_station.$1 - 150, _station.$2 - 30), 'Kohat Enclave', 9, _metroInk);
  }

  /// Text with a paper-coloured halo behind it, which is how a map keeps a label
  /// legible over whatever it happens to cross.
  void _label(Canvas canvas, Offset at, String text, double size, Color c,
      {double angle = 0, Size? bounds}) {
    final t = TextPainter(
      text: TextSpan(
        text: text,
        style: A.tiny.copyWith(
          fontSize: size,
          color: c,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          shadows: [
            const Shadow(color: _land, blurRadius: 3),
            const Shadow(color: _land, blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var spot = at;
    if (bounds != null) {
      // Kept inside the frame: a street name half off the edge reads as a bug.
      final half = (t.width / 2 * math.cos(angle)).abs() + 6;
      spot = Offset(
        at.dx.clamp(half, math.max(half, bounds.width - half)),
        at.dy.clamp(10, math.max(10, bounds.height - 10)),
      );
    }
    canvas.save();
    canvas.translate(spot.dx, spot.dy);
    if (angle != 0) canvas.rotate(angle);
    t.paint(canvas, Offset(-t.width / 2, -t.height / 2));
    canvas.restore();
  }

  /// You are here: a soft accuracy halo and a cyan dot with a white collar, the
  /// convention every map app shares.
  void _you(Canvas canvas, MapView v) {
    final c = v.at(0, 0);
    canvas.drawCircle(c, 130 * v.scale, Paint()..color = A.accent.withValues(alpha: 0.1));
    canvas.drawCircle(
      c,
      130 * v.scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = A.accent.withValues(alpha: 0.35),
    );
    canvas.drawCircle(c, 8, Paint()..color = Colors.white);
    canvas.drawCircle(c, 5.5, Paint()..color = A.accent);
  }

  /// A report: the pin shape everyone knows, in the status colour, with a white
  /// rim so it stays legible over a dark road or the park.
  void _pin(Canvas canvas, Offset at, Color c, bool chosen) {
    final r = chosen ? 11.0 : 8.0;
    final tip = at.translate(0, r * 2.1);
    final body = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(at.dx - r * 0.72, at.dy + r * 0.72)
      ..lineTo(at.dx + r * 0.72, at.dy + r * 0.72)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..color = A.ink.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(at, r + 2, Paint()..color = Colors.white);
    canvas.drawPath(body, Paint()..color = Colors.white);
    canvas.drawCircle(at, r, Paint()..color = c);
    canvas.drawCircle(at, r * 0.34, Paint()..color = Colors.white);
    if (!chosen) return;
    canvas.drawCircle(
      at,
      r + 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = c.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_Neighbourhood old) => old.picked != picked || old.pins.length != pins.length;
}

/// The dashboard's window onto the same map: the same painter, wider view, no
/// labels, and the whole card opens the real thing.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, this.height = 132});
  final double height;

  @override
  Widget build(BuildContext context) {
    final pins = Store.nearby;
    return ClayCard(
      onTap: () => Navigator.of(context).push(A.route(const MapScreen())),
      padding: const EdgeInsets.all(7),
      child: Column(
        mainAxisSize: MainAxisSize.min, // never stretch: it is a card, not a page
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(A.rCard - 8),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(painter: _Neighbourhood(pins: pins, plain: true)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 10, 4, 3),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, size: 17, color: A.accentDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pins.isEmpty
                        ? 'Nothing reported around you'
                        : '${pins.length} leaks near you',
                    style: A.label.copyWith(color: A.ink),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: A.inkSoft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
