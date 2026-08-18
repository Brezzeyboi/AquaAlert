
import 'package:flutter/material.dart';

/// Locked AquaAlert design tokens. Nothing in the app hardcodes a colour or a
/// shadow — it comes from here so the whole app moves together.
///
/// The depth rule, taken from the sign-in mockup: **a shadow is never black and
/// never navy.** It is the surface's own hue walked towards a cool grey-blue, so
/// every object looks moulded out of the background rather than sitting on it
/// with a dark smudge underneath. Light comes from the top-left: white bloom up
/// there, soft shade down-right, and nothing on screen is ever darker than the
/// background except ink.
class A {
  // Surfaces
  static const surface = Color(0xFFEAEFF5); // cool off-white, lit from above
  static const card = Color(0xFFF4F7FB);
  static const sunk = Color(0xFFEBF0F7); // inset wells / track grooves

  // Ink
  static const ink = Color(0xFF0D2750); // navy, all text
  static const inkSoft = Color(0xFF8A94A6); // secondary text, neutral cool grey

  /// The one shadow colour in the app: the surface, pushed towards slate. Soft,
  /// cool, and light enough that a big blur reads as air rather than as dirt.
  static const shade = Color(0xFF9DB0C9);

  // Accent — official UN SDG 6 cyan. Judges recognise it, do not tint it.
  static const accent = Color(0xFF26BDE2);
  static const accentDeep = Color(0xFF178FB5); // community scope, same family

  // Status
  static const amber = Color(0xFFE5A13A); // overdue / caution
  static const green = Color(0xFF4FB783); // fixed

  // Radii — generous, clay is never sharp.
  static const rCard = 28.0;
  static const rPill = 999.0;
  static const rField = 20.0;

  /// Two shadows, both soft: a white bloom up-left and a wide slate shade
  /// down-right. No tight dark contact shadow — that is what was reading as a
  /// grubby black edge instead of moulded clay.
  static List<BoxShadow> clay({double d = 1}) => [
        BoxShadow(
          color: Colors.white,
          offset: Offset(-7 * d, -7 * d),
          blurRadius: 16 * d,
        ),
        BoxShadow(
          color: shade.withValues(alpha: 0.5),
          offset: Offset(0, 6 * d),
          blurRadius: 13 * d,
        ),
        BoxShadow(
          color: shade.withValues(alpha: 0.45),
          offset: Offset(6 * d, 10 * d),
          blurRadius: 22 * d,
        ),
        // The wide one is what puts air under the object. Spread pulled in so it
        // never darkens the whole gap between two cards.
        BoxShadow(
          color: shade.withValues(alpha: 0.3),
          offset: Offset(2 * d, 16 * d),
          blurRadius: 36 * d,
          spreadRadius: -8,
        ),
      ];

  /// The lit edge of a moulded object. Faint on purpose: in the mockup the card's
  /// edge is light, not outlined, and Flutter refuses a rounded border whose
  /// sides differ, so this stays a whisper all the way round.
  static Border get rim =>
      Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1);

  /// Even the fill is lit from the top-left. A flat fill is what made the
  /// first build read as flat paper on a real screen.
  static LinearGradient cardGrad(Color? c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c ?? card, Colors.white, c == null ? 1 : 0.22)!, c ?? card],
      );

  /// Pressed clay: the object sinks, so the shadows swap sides and shrink.
  static List<BoxShadow> clayPressed() => [
        BoxShadow(
          color: shade.withValues(alpha: 0.6),
          offset: const Offset(-3, -4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.9),
          offset: const Offset(3, 4),
          blurRadius: 8,
        ),
      ];

  /// The extruded lip under a pressable cyan pill: a hard, un-blurred edge of the
  /// deeper cyan, which is what makes the mockup's Sign in button look like a key
  /// you can push rather than a coloured rectangle.
  static List<BoxShadow> lip(Color c) => [
        BoxShadow(color: Color.lerp(c, ink, 0.28)!, offset: const Offset(0, 4)),
        BoxShadow(
          color: c.withValues(alpha: 0.45),
          offset: const Offset(0, 12),
          blurRadius: 22,
          spreadRadius: -6,
        ),
      ];


  /// A moulded cyan object seen under a light from the top-left: bright cap,
  /// saturated middle, deeper underside. This is the gradient that makes the
  /// mockup's buttons look like objects rather than coloured rectangles.
  static LinearGradient domeGrad(Color c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(c, Colors.white, 0.22)!,
          c,
          Color.lerp(c, ink, 0.12)!,
        ],
        stops: const [0, 0.55, 1],
      );

  /// A coloured disc moulded out of clay: badges, the plus, the chooser icons.
  /// The light is a whisper and there is no dark underside — a bright spot on the
  /// left over a hard dark crescent is what read as wet plastic on the phone.
  static RadialGradient discGrad(Color c) => RadialGradient(
        center: const Alignment(-0.22, -0.3),
        radius: 1.0,
        colors: [Color.lerp(c, Colors.white, 0.13)!, c, Color.lerp(c, ink, 0.05)!],
        stops: const [0, 0.58, 1],
      );

  /// What a coloured disc sits in, instead of [lip]'s extruded edge: the same
  /// two-sided clay light every other object gets, tinted by the disc's colour so
  /// it seats into the card rather than hovering over it.
  static List<BoxShadow> seat(Color c, {double d = 1}) => [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.85),
          offset: Offset(-2 * d, -2.5 * d),
          blurRadius: 6 * d,
        ),
        BoxShadow(
          color: Color.lerp(c, shade, 0.5)!.withValues(alpha: 0.55),
          offset: Offset(1 * d, 5 * d),
          blurRadius: 11 * d,
          spreadRadius: -1,
        ),
      ];

  /// The specular cap that sits inside the top of a pressable object. Wrapped in
  /// its own widget-free gradient so a Stack can drop it over any shape.
  static LinearGradient glossGrad() => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.02),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.75, 1],
      );

  /// Page transitions. The whole app slides in from the right and fades, so a
  /// push reads as a push instead of a cut.
  static Route<T> route<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) {
          final eased = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(eased),
              child: child,
            ),
          );
        },
      );

  // No inset() here: Flutter has no inset box-shadow, so a well is painted
  // rather than decorated. See _Well in widgets/clay.dart.

  /// A colour washed down to a card fill — the cyan event banner, the amber
  /// prize card. Mixing towards white rather than towards the surface keeps the
  /// tint on the raised side of the clay.
  static Color tint(Color c, [double t = 0.86]) => Color.lerp(c, Colors.white, t)!;

  // ---- Type: Outfit, rounded geometric sans ----
  static TextStyle _o(double size, FontWeight w, {Color? c, double? h}) => TextStyle(
        fontFamily: 'Outfit',
        // Outfit ships as one variable file, so the weight travels on the wght
        // axis; fontWeight stays for anything that falls back to a system font.
        fontVariations: [FontVariation('wght', w.value.toDouble())],
        fontWeight: w,
        fontSize: size,
        color: c ?? ink,
        height: h,
        letterSpacing: -0.2,
      );

  static TextStyle get h1 => _o(28, FontWeight.w700);
  static TextStyle get h2 => _o(21, FontWeight.w600);
  static TextStyle get h3 => _o(17, FontWeight.w600);
  static TextStyle get body => _o(15, FontWeight.w400, h: 1.4);
  static TextStyle get bodySoft => _o(15, FontWeight.w400, c: inkSoft, h: 1.4);
  static TextStyle get label => _o(13, FontWeight.w600, c: inkSoft);
  static TextStyle get tiny => _o(11.5, FontWeight.w500, c: inkSoft);

  /// Litre figures only. Tabular so digits never jitter as counters tick.
  static TextStyle figure(double size, {Color? c, FontWeight? w}) => TextStyle(
        fontFamily: 'Outfit',
        fontVariations: [FontVariation('wght', (w ?? FontWeight.w700).value.toDouble())],
        fontWeight: w ?? FontWeight.w700,
        fontSize: size,
        color: c ?? ink,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Coordinates, DIGIPIN, meter readings. The platform's own monospace: the
  /// mockups type these like a machine printed them, and a second web font
  /// would be another runtime download for four short strings.
  static TextStyle mono(double size, {Color? c, FontWeight? w}) => TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Roboto Mono', 'Courier New'],
        fontSize: size,
        fontWeight: w ?? FontWeight.w500,
        color: c ?? ink,
        letterSpacing: 0.4,
      );

  static ThemeData theme() => ThemeData(
        scaffoldBackgroundColor: surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          primary: accent,
          surface: surface,
        ),
        fontFamily: 'Outfit',
        textTheme: Typography.material2021().black.apply(bodyColor: ink),
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
      );
}

/// 12,450 -> "12,450". Indian grouping kicks in above 99,999 (1,20,000).
String litres(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final head = s.substring(0, s.length - 3);
  final tail = s.substring(s.length - 3);
  final buf = StringBuffer();
  for (var i = 0; i < head.length; i++) {
    if (i != 0 && (head.length - i) % 2 == 0) buf.write(',');
    buf.write(head[i]);
  }
  return '$buf,$tail';
}
