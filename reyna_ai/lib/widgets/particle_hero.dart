// lib/widgets/particle_hero.dart
//
// 🌀 SOUL-TO-TEXT HERO — v3
// ──────────────────────────────────────────────────────────────────────────────
// Uses bitmap glyph maps (no dart:ui text-path APIs) for cross-platform safety.
//
// Animation timeline (4 000 ms controller):
//   Interval 0.00–0.15  Orb phase: particles float in chaos
//   Interval 0.15–0.78  Lerp phase: easeInOutCubic moves each → target point
//   Interval 0.72–0.90  Glow text fades in over settled particles
//   Interval 0.88–1.00  Subtext "YOUR PERSONAL AI TUTOR" fades in
// ──────────────────────────────────────────────────────────────────────────────
import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color _kParticle = Color(0xFFC428FF);

// ─────────────────────────────────────────────────────────────────────────────
// 5×7 bitmap glyphs for "REYNA AI" (columns × rows)
// 1 = particle, 0 = empty
// ─────────────────────────────────────────────────────────────────────────────
const _glyphs = <String, List<List<int>>>{
  'R': [
    [1, 1, 1, 1, 0, 0, 0],
    [1, 0, 0, 0, 1, 0, 0],
    [1, 0, 0, 0, 1, 0, 0],
    [1, 1, 1, 1, 0, 0, 0],
    [1, 0, 1, 0, 0, 0, 0],
    [1, 0, 0, 1, 0, 0, 0],
    [1, 0, 0, 0, 1, 0, 0],
  ],
  'E': [
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 0],
    [1, 1, 1, 1, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 0],
    [1, 1, 1, 1, 1, 1, 1],
  ],
  'Y': [
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [0, 1, 0, 0, 0, 1, 0],
    [0, 0, 1, 0, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
  ],
  'N': [
    [1, 1, 0, 0, 0, 0, 1],
    [1, 0, 1, 0, 0, 0, 1],
    [1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 0, 1, 0, 1],
    [1, 0, 0, 0, 0, 1, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
  ],
  'A': [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 0, 1, 0, 0],
    [0, 1, 0, 0, 0, 1, 0],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
  ],
  ' ': [],
  'I': [
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Single particle
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final Offset orb;
  final Offset target;
  final double r;
  final double alpha;
  const _Particle(
      {required this.orb,
      required this.target,
      required this.r,
      required this.alpha});
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _lerpAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _subAnim;

  final _rng = math.Random(42);
  final List<_Particle> _particles = [];
  bool _ready = false;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000));

    _lerpAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.78, curve: Curves.easeInOutCubic),
    );
    _glowAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.72, 0.90, curve: Curves.easeOut),
    );
    _subAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
    );

    Future.delayed(const Duration(milliseconds: 200),
        () { if (mounted) _ctrl.forward(); });
  }

  // ── Build target list from glyph bitmaps ──────────────────────────────────
  List<Offset> _buildTargets(Size size) {
    const text = 'REYNA AI';
    const rows = 7;

    // Pixel size scales with screen: 9px on a ~400px wide screen
    final pixSize = (size.width / 46.0).clamp(7.0, 13.0);
    final gapBetween = pixSize * 0.7;

    // Compute total width for centering
    double totalW = 0;
    for (final ch in text.split('')) {
      final g = _glyphs[ch];
      if (g == null || g.isEmpty) {
        totalW += pixSize * 1.6;
      } else {
        totalW += g.length * pixSize + gapBetween;
      }
    }

    // Place text at 42% from top (matches neon text label in build())
    final startX = (size.width - totalW) / 2;
    final startY = size.height * 0.42 - (rows * pixSize) / 2;

    final targets = <Offset>[];
    double cx = startX;

    for (final ch in text.split('')) {
      final g = _glyphs[ch];
      if (g == null || g.isEmpty) {
        cx += pixSize * 1.6;
        continue;
      }
      for (int col = 0; col < g.length; col++) {
        for (int row = 0; row < rows; row++) {
          if (g[col][row] == 1) {
            targets.add(Offset(cx + col * pixSize, startY + row * pixSize));
          }
        }
      }
      cx += g.length * pixSize + gapBetween;
    }
    return targets;
  }

  // ── Initialise / re-initialise particles when size changes ────────────────
  void _init(Size size) {
    if (_ready && _lastSize == size) return;
    _ready = true;
    _lastSize = size;

    final targets = _buildTargets(size);
    final cx = size.width / 2;
    final cy = size.height * 0.42; // matches text vertical center

    _particles.clear();
    const count = 400;
    for (int i = 0; i < count; i++) {
      // Orb: organic polar spread
      final angle = _rng.nextDouble() * 2 * math.pi;
      final dist = 24 + _rng.nextDouble() * (size.width * 0.10);
      final ox =
          cx + math.cos(angle) * dist * (0.55 + _rng.nextDouble() * 0.9);
      final oy =
          cy + math.sin(angle) * dist * (0.45 + _rng.nextDouble() * 0.55);

      // Target: cycle through glyph bitmap points + tiny sub-pixel jitter
      final Offset tgt;
      if (targets.isEmpty) {
        tgt = Offset(cx, cy);
      } else {
        final base = targets[i % targets.length];
        tgt = Offset(
          base.dx + _rng.nextDouble() * 1.4 - 0.7,
          base.dy + _rng.nextDouble() * 1.4 - 0.7,
        );
      }

      _particles.add(_Particle(
        orb: Offset(ox, oy),
        target: tgt,
        r: 1.1 + _rng.nextDouble() * 1.7,
        alpha: 0.5 + _rng.nextDouble() * 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    // Font size for neon text overlay — 12% of height, capped 36–80
    final fontSize = (mq.height * 0.12).clamp(36.0, 80.0);

    return LayoutBuilder(builder: (ctx, cons) {
      final size = Size(cons.maxWidth, cons.maxHeight);
      _init(size);

      return AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final lv = _lerpAnim.value;
          final gv = _glowAnim.value;
          final sv = _subAnim.value;

          return Stack(
            children: [
              // ── 400 particles on canvas ─────────────────────────────────
              CustomPaint(
                size: size,
                painter: _PPainter(particles: _particles, lerp: lv),
              ),

              // ── Neon text fades in as particles settle ──────────────────
              if (gv > 0)
                Positioned(
                  // vertically centred at 42% (same as glyph target zone)
                  top: size.height * 0.42 - fontSize * 0.55,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: gv,
                    child: Text(
                      'REYNA AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: _kParticle,
                        shadows: [
                          Shadow(
                              color: _kParticle.withOpacity(0.95),
                              blurRadius: 20),
                          Shadow(
                              color: _kParticle.withOpacity(0.55),
                              blurRadius: 44),
                          Shadow(
                              color: _kParticle.withOpacity(0.20),
                              blurRadius: 88),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Subtext: 10px SizedBox below neon text ──────────────────
              if (sv > 0)
                Positioned(
                  // 42% center + half font height + 10px gap
                  top: size.height * 0.42 + fontSize * 0.55 + 10,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: sv,
                    child: const Text(
                      'YOUR PERSONAL AI TUTOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 5,
                        color: Color(0xFF73757D),
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
// CustomPainter
// ─────────────────────────────────────────────────────────────────────────────
class _PPainter extends CustomPainter {
  final List<_Particle> particles;
  final double lerp;
  const _PPainter({required this.particles, required this.lerp});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final pos = Offset.lerp(p.orb, p.target, lerp)!;

      // Glow halo
      canvas.drawCircle(
        pos,
        p.r * 3.2,
        Paint()
          ..color = _kParticle.withOpacity(
              p.alpha * (0.09 + 0.07 * (1 - lerp)))
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, p.r * 2.8),
      );

      // Core dot
      canvas.drawCircle(
        pos,
        p.r,
        Paint()
          ..color = _kParticle.withOpacity(p.alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_PPainter old) => old.lerp != lerp;
}
