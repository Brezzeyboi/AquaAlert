import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/clay.dart';
import '../widgets/common.dart';

/// Sign in, register, or come in with Google. AquaAlert is still community first
/// — an account is what carries your litres between phones, not a gate on
/// reporting — so the copy never threatens anyone with a school.
// TODO(supabase): these three paths all hand straight over. Wire them to
// Supabase auth (email/password + Google provider) once the project exists.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _show = false;

  bool get _ok => looksLikeEmail(_email.text) && _pass.text.length >= 6;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: A.surface,
      body: SafeArea(
        child: AuthShell(
          title: 'Welcome back',
          sub: 'Sign in to keep saving water',
          children: [
            // A prototype with no database still has to answer "whose phone is
            // this?" — and being each of the three kinds of person in turn is how
            // the school rule is demonstrated at all.
            Text('Saved on this phone', style: A.label),
            const SizedBox(height: 10),
            ClayCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < Store.saved.length; i++) ...[
                    if (i > 0)
                      Container(height: 1, color: A.ink.withValues(alpha: 0.07)),
                    _SavedRow(
                      Store.saved[i],
                      onTap: () {
                        Store.use(Store.saved[i]);
                        widget.onDone();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const OrRule(label: 'or use another account'),
            const SizedBox(height: 18),
            ClayCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email', style: A.label),
                  const SizedBox(height: 8),
                  AuthField(
                    controller: _email,
                    icon: Icons.mail_outline_rounded,
                    hint: 'you@example.com',
                    keyboard: TextInputType.emailAddress,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Text('Password', style: A.label),
                  const SizedBox(height: 8),
                  AuthField(
                    controller: _pass,
                    icon: Icons.lock_outline_rounded,
                    hint: '••••••',
                    obscure: !_show,
                    onChanged: () => setState(() {}),
                    trailing: GestureDetector(
                      onTap: () => setState(() => _show = !_show),
                      child: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 19, color: A.inkSoft),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      // TODO(supabase): send the reset email from here.
                      onTap: () {},
                      child: Text('Forgot password?',
                          style: A.label.copyWith(
                              color: A.accentDeep, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ClayButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              onTap: _ok
                  ? () {
                      // No database: the name is derived from the address typed,
                      // so a demo signs in as itself rather than as a fixture.
                      Store.signIn(email: _email.text, name: nameFromEmail(_email.text));
                      widget.onDone();
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            const OrRule(),
            const SizedBox(height: 16),
            GoogleButton(onTap: widget.onDone),
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  A.route(RegisterScreen(onDone: widget.onDone)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New here? ', style: A.bodySoft),
                    Flexible(
                      child: Text('Create account',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: A.body.copyWith(
                              color: A.accentDeep, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One saved account. Initials, who they are, and what that means for what they
/// can do — the head's row says it closes reports, because that is the whole
/// difference between them.
class _SavedRow extends StatelessWidget {
  const _SavedRow(this.who, {required this.onTap});
  final Persona who;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              InitialsAvatar(who.name, size: 42, filled: who.fixer),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(who.name, style: A.h3.copyWith(fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(who.role, style: A.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: A.inkSoft),
            ],
          ),
        ),
      );
}

/// A name, an email, a password, and optionally the code that joins a school.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  bool _show = false;

  bool get _ok =>
      _name.text.trim().length > 1 && looksLikeEmail(_email.text) && _pass.text.length >= 6;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final joined = _code.text.toUpperCase() == Store.joinCode;
    return Scaffold(
      backgroundColor: A.surface,
      body: SafeArea(
        child: Stack(
          children: [
            AuthShell(
              title: 'Create account',
              sub: 'Your litres follow you to any phone',
              children: [
                ClayCard(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your name', style: A.label),
                      const SizedBox(height: 8),
                      AuthField(
                        controller: _name,
                        icon: Icons.person_outline_rounded,
                        hint: 'Mohd Rehan',
                        caps: TextCapitalization.words,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Text('Email', style: A.label),
                      const SizedBox(height: 8),
                      AuthField(
                        controller: _email,
                        icon: Icons.mail_outline_rounded,
                        hint: 'you@example.com',
                        keyboard: TextInputType.emailAddress,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Text('Password', style: A.label),
                      const SizedBox(height: 8),
                      AuthField(
                        controller: _pass,
                        icon: Icons.lock_outline_rounded,
                        hint: 'at least 6 characters',
                        obscure: !_show,
                        onChanged: () => setState(() {}),
                        trailing: GestureDetector(
                          onTap: () => setState(() => _show = !_show),
                          child: Icon(
                              _show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 19,
                              color: A.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ClayCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('School or college code', style: A.label)),
                          Text('optional', style: A.tiny),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CodeBoxes(_code, onChanged: () => setState(() {})),
                      const SizedBox(height: 10),
                      if (joined)
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                  color: A.green, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(Store.institution,
                                  style: A.body.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        )
                      else
                        Text('Adds its leaderboard and its events. Reporting works without one.',
                            style: A.tiny),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ClayButton(
                  label: 'Create account',
                  icon: Icons.arrow_forward_rounded,
                  onTap: _ok
                      ? () {
                          Store.signIn(email: _email.text, name: _name.text);
                          Store.joined = joined;
                          widget.onDone();
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                const OrRule(),
                const SizedBox(height: 16),
                GoogleButton(onTap: widget.onDone),
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ', style: A.bodySoft),
                        Text('Sign in',
                            style: A.body.copyWith(
                                color: A.accentDeep, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 20,
              top: 8,
              child: ClayIcon(Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}


/// "rehan@example.com" -> "Rehan". Good enough for a prototype greeting, and it
/// beats asking for a name twice.
String nameFromEmail(String email) {
  final head = email.trim().split('@').first.replaceAll(RegExp(r'[._\-]+'), ' ').trim();
  if (head.isEmpty) return 'You';
  return head
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// An email needs an @ and a dot after it. Anything stricter belongs on the
/// server, and anything looser lets a typo through.
bool looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

/// The shell both auth screens sit in: the mark, a big heading, a soft line, then
/// whatever the screen is asking for — centred, and scrollable for the keyboard.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.sub,
    required this.children,
  });
  final String title, sub;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).vertical -
                46,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The launcher render itself, not a Material droplet — the mark on
              // the home screen and the mark in the app are one object.
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: A.clay(d: 1.15),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/icon/launcher.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(title, style: A.h1.copyWith(fontSize: 36), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(sub, style: A.bodySoft.copyWith(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 22),
              ...children,
            ],
          ),
        ),
      );
}

/// One inset pill with a glyph in it, which is how every field in the mockups is
/// drawn.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.caps = TextCapitalization.none,
    this.trailing,
    this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final TextCapitalization caps;
  final Widget? trailing;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => ClayWell(
        radius: A.rPill,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: A.inkSoft),
            const SizedBox(width: 11),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboard,
                textCapitalization: caps,
                onChanged: (_) => onChanged?.call(),
                style: A.body,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: A.bodySoft.copyWith(color: A.inkSoft.withValues(alpha: 0.6)),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// A hairline with a word sitting in the gap.
class OrRule extends StatelessWidget {
  const OrRule({super.key, this.label = 'or'});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Divider(color: A.ink.withValues(alpha: 0.12))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: A.tiny),
          ),
          Expanded(child: Divider(color: A.ink.withValues(alpha: 0.12))),
        ],
      );
}

/// White pill, Google's mark, one line of type — the shape everybody already
/// knows how to press.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClayCard(
        onTap: onTap,
        radius: A.rPill,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CustomPaint(size: Size(22, 22), painter: _GoogleMark()),
            const SizedBox(width: 12),
            // Flexible: at a large system text size this label is wider than a
            // 360dp phone, and a button that overflows is a red stripe on stage.
            Flexible(
              child: Text('Continue with Google',
                  style: A.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

/// Google's four-colour G, drawn rather than shipped as an asset: four arcs and
/// the bar, in their own colours.
class _GoogleMark extends CustomPainter {
  const _GoogleMark();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r * 0.78);
    final stroke = r * 0.44;
    void arc(double from, double sweep, Color c) => canvas.drawArc(
          rect,
          from * math.pi / 180,
          sweep * math.pi / 180,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = c,
        );
    arc(-18, -72, const Color(0xFFEA4335)); // red, upper right
    arc(-90, -80, const Color(0xFFFBBC05)); // yellow, left top
    arc(170, 80, const Color(0xFF34A853)); // green, lower left
    arc(80, -98, const Color(0xFF4285F4)); // blue, right side
    // The bar into the middle, which is what makes it a G and not a C.
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, size.height * 0.42, size.width * 0.36, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleMark old) => false;
}
