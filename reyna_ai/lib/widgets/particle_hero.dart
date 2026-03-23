// lib/widgets/particle_hero.dart
//
// 🌊 AURORA WAVE HERO — Premium animated gradient mesh
// ──────────────────────────────────────────────────────────────────────────────
// Animation timeline (4 000 ms controller):
//   0.00–0.40  Aurora waves rise from bottom, flowing gradient ribbons
//   0.35–0.70  "REYNA AI" text fades in with shimmer sweep
//   0.65–0.85  Floating orb particles settle into constellation
//   0.80–1.00  Subtext "YOUR PERSONAL AI TUTOR" fades in
// ──────────────────────────────────────────────────────────────────────────────
import 'dart:math' as math;
import 'package:flutter/material.dart';

// New palette colours
const Color _kIndigo = Color(0xFF6A49FA);
const Color _kDeep   = Color(0xFF453284);
const Color _kSky    = Color(0xFFC6E6FF);
const Color _kBlush  = Color(0xFFFEDADA);

// ─────────────────────────────────────────────────────────────────────────────
// Floating orb particle
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingOrb {
  final double x, y, radius, speed, phase;
  final Color color;
  const _FloatingOrb({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class ParticleHero extends StatefulWidget {
  const ParticleHero({super.key});
  @override
  State<ParticleHero> createState() => _ParticleHeroState();
}

class _ParticleHeroState extends State<ParticleHero>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _loopCtrl;
  late final Animation<double> _auroraAnim;
  late final Animation<double> _textAnim;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _orbAnim;
  late final Animation<double> _subAnim;

  final _rng = math.Random(42);
  final List<_FloatingOrb> _orbs = [];
  bool _orbsReady = false;

  @override
  void initState() {
    super.initState();

    // Main intro controller
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000));

    _auroraAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _textAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
    _shimmerAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.75, curve: Curves.easeInOut),
    );
    _orbAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.50, 0.85, curve: Curves.easeOut),
    );
    _subAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.80, 1.0, curve: Curves.easeIn),
    );

    // Infinite loop for continuous wave motion
    _loopCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  void _initOrbs(Size size) {
    if (_orbsReady) return;
    _orbsReady = true;
    _orbs.clear();

    final colors = [_kIndigo, _kSky, _kBlush, _kDeep];
    for (int i = 0; i < 50; i++) {
      _orbs.add(_FloatingOrb(
        x: _rng.nextDouble() * size.width,
        y: size.height * 0.2 + _rng.nextDouble() * size.height * 0.5,
        radius: 1.5 + _rng.nextDouble() * 3.5,
        speed: 0.3 + _rng.nextDouble() * 0.7,
        phase: _rng.nextDouble() * math.pi * 2,
        color: colors[_rng.nextInt(colors.length)],
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _loopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cons) {
      final size = Size(cons.maxWidth, cons.maxHeight);
      _initOrbs(size);

      final fontSize = (size.height * 0.12).clamp(36.0, 80.0);

      return AnimatedBuilder(
        animation: Listenable.merge([_ctrl, _loopCtrl]),
        builder: (_, __) {
          final av = _auroraAnim.value;
          final tv = _textAnim.value;
          final sv = _shimmerAnim.value;
          final ov = _orbAnim.value;
          final stv = _subAnim.value;
          final loop = _loopCtrl.value;

          return Stack(
            children: [
              // ── Aurora wave gradient mesh ─────────────────────────────────
              CustomPaint(
                size: size,
                painter: _AuroraWavePainter(
                  progress: av,
                  loopPhase: loop,
                ),
              ),

              // ── Floating constellation orbs ──────────────────────────────
              if (ov > 0)
                CustomPaint(
                  size: size,
                  painter: _OrbPainter(
                    orbs: _orbs,
                    opacity: ov,
                    loopPhase: loop,
                  ),
                ),

              // ── "REYNA AI" text with shimmer ─────────────────────────────
              if (tv > 0)
                Positioned(
                  top: size.height * 0.40 - fontSize * 0.55,
                  left: 0,
                  right: 0,
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      final shimmerX = -0.5 + sv * 2.0;
                      return LinearGradient(
                        begin: Alignment(shimmerX - 0.3, 0),
                        end: Alignment(shimmerX + 0.3, 0),
                        colors: [
                          Colors.white.withOpacity(tv * 0.7),
                          Colors.white.withOpacity(tv),
                          Colors.white.withOpacity(tv * 0.7),
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.modulate,
                    child: Text(
                      'REYNA AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: _kIndigo.withOpacity(0.90),
                              blurRadius: 24),
                          Shadow(
                              color: _kSky.withOpacity(0.40),
                              blurRadius: 50),
                          Shadow(
                              color: _kBlush.withOpacity(0.20),
                              blurRadius: 80),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Subtext ──────────────────────────────────────────────────
              if (stv > 0)
                Positioned(
                  top: size.height * 0.40 + fontSize * 0.55 + 14,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: stv,
                    child: const Text(
                      'YOUR PERSONAL AI TUTOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 5,
                        color: Color(0xFF7A7890),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aurora Wave Painter — flowing gradient ribbons
// ─────────────────────────────────────────────────────────────────────────────
class _AuroraWavePainter extends CustomPainter {
  final double progress;
  final double loopPhase;
  const _AuroraWavePainter({required this.progress, required this.loopPhase});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final w = size.width;
    final h = size.height;

    // Draw 3 flowing aurora ribbons
    _drawRibbon(canvas, size, 
      yCenter: h * 0.30, amplitude: h * 0.08, 
      phaseOffset: 0.0, 
      color1: _kIndigo.withOpacity(0.25 * progress),
      color2: _kDeep.withOpacity(0.15 * progress),
      thickness: h * 0.18,
    );

    _drawRibbon(canvas, size,
      yCenter: h * 0.45, amplitude: h * 0.06,
      phaseOffset: 2.0,
      color1: _kSky.withOpacity(0.18 * progress),
      color2: _kIndigo.withOpacity(0.10 * progress),
      thickness: h * 0.14,
    );

    _drawRibbon(canvas, size,
      yCenter: h * 0.55, amplitude: h * 0.05,
      phaseOffset: 4.0,
      color1: _kBlush.withOpacity(0.15 * progress),
      color2: _kSky.withOpacity(0.08 * progress),
      thickness: h * 0.12,
    );

    // Central glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 0.8,
        colors: [
          _kIndigo.withOpacity(0.12 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);
  }

  void _drawRibbon(Canvas canvas, Size size, {
    required double yCenter,
    required double amplitude,
    required double phaseOffset,
    required Color color1,
    required Color color2,
    required double thickness,
  }) {
    final path = Path();
    final w = size.width;
    final phase = loopPhase * math.pi * 2 + phaseOffset;

    path.moveTo(0, yCenter + math.sin(phase) * amplitude);
    for (double x = 0; x <= w; x += 4) {
      final t = x / w;
      final y = yCenter +
          math.sin(phase + t * math.pi * 3) * amplitude +
          math.sin(phase * 1.3 + t * math.pi * 5) * amplitude * 0.3;
      path.lineTo(x, y);
    }

    // Close path to form a filled ribbon
    for (double x = w; x >= 0; x -= 4) {
      final t = x / w;
      final y = yCenter + thickness +
          math.sin(phase + t * math.pi * 3 + 0.5) * amplitude * 0.5;
      path.lineTo(x, y);
    }
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [color1, color2, color1],
      ).createShader(Rect.fromLTWH(0, yCenter - amplitude, w, thickness + amplitude * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AuroraWavePainter old) =>
      old.progress != progress || old.loopPhase != loopPhase;
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Orb Painter — constellation dots
// ─────────────────────────────────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  final List<_FloatingOrb> orbs;
  final double opacity;
  final double loopPhase;
  const _OrbPainter({
    required this.orbs,
    required this.opacity,
    required this.loopPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final phase = loopPhase * math.pi * 2 + orb.phase;
      final dx = math.sin(phase * orb.speed) * 12;
      final dy = math.cos(phase * orb.speed * 0.7) * 8;
      final pos = Offset(orb.x + dx, orb.y + dy);

      // Glow halo
      canvas.drawCircle(
        pos,
        orb.radius * 3,
        Paint()
          ..color = orb.color.withOpacity(0.08 * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, orb.radius * 2.5),
      );

      // Core dot
      canvas.drawCircle(
        pos,
        orb.radius,
        Paint()..color = orb.color.withOpacity(0.5 * opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.opacity != opacity || old.loopPhase != loopPhase;
}
