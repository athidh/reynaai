// lib/widgets/particle_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Particle {
  Offset position;
  Offset velocity;
  Offset target;
  double opacity;
  double radius;

  Particle({
    required this.position,
    required this.velocity,
    required this.target,
    required this.opacity,
    required this.radius,
  });
}

/// Renders purple particles that scatter and then coalesce into "REYNA AI"
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress; // 0..1: 0=scattered, 1=coalesced into logo
  final double textOpacity;

  ParticlePainter({
    required this.particles,
    required this.progress,
    required this.textOpacity,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final currentPos = Offset.lerp(p.position, p.target, progress)!;
      final color = Color.lerp(
        AppColors.primary.withOpacity(0.6),
        AppColors.primary,
        progress,
      )!;
      particlePaint.color = color.withOpacity(p.opacity);
      canvas.drawCircle(currentPos, p.radius, particlePaint);

      // Glow halo
      final glowPaint = Paint()
        ..color = AppColors.primary.withOpacity(0.12 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(currentPos, p.radius * 2.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) =>
      old.progress != progress || old.textOpacity != textOpacity;
}

/// Full landing hero animation widget
class ParticleLogoAnimation extends StatefulWidget {
  const ParticleLogoAnimation({super.key});

  @override
  State<ParticleLogoAnimation> createState() => _ParticleLogoAnimationState();
}

class _ParticleLogoAnimationState extends State<ParticleLogoAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final Animation<double> _textFade;
  final List<Particle> _particles = [];
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: Curves.easeInOut),
    );

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    // Init particles — targets set lazily after first layout
    for (int i = 0; i < 220; i++) {
      _particles.add(Particle(
        position: Offset.zero,
        velocity: Offset.zero,
        target: Offset.zero,
        opacity: 0.5 + _rng.nextDouble() * 0.5,
        radius: 1.5 + _rng.nextDouble() * 2.5,
      ));
    }

    // Start after a brief delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  void _initParticles(Size size) {
    // Scatter positions: random across screen
    // Target positions: clustered around center
    final cx = size.width / 2;
    final cy = size.height / 2 - 24;

    // Distribute targets in a grid pattern simulating text
    final cols = 15;
    final rows = 10;
    final spacingX = 20.0;
    final spacingY = 14.0;
    final startX = cx - (cols * spacingX) / 2;
    final startY = cy - (rows * spacingY) / 2;

    for (int i = 0; i < _particles.length; i++) {
      if (_particles[i].position == Offset.zero) {
        // Scatter: random
        _particles[i].position = Offset(
          _rng.nextDouble() * size.width,
          _rng.nextDouble() * size.height,
        );
        // Target: grid positions creating text shape
        final col = i % cols;
        final row = (i ~/ cols) % rows;
        _particles[i].target = Offset(
          startX + col * spacingX + _rng.nextDouble() * 6 - 3,
          startY + row * spacingY + _rng.nextDouble() * 4 - 2,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      _initParticles(size);

      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Particle canvas
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: ParticlePainter(
                    particles: _particles,
                    progress: _progress.value,
                    textOpacity: _textFade.value,
                    repaint: _controller,
                  ),
                ),
              ),

              // Emerging logo text
              Opacity(
                opacity: _textFade.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Soul Orb icon
                    Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.primary, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -math.pi / 4,
                            child: Container(
                              width: 22,
                              height: 22,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // "REYNA AI"
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'REYNA AI',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtext
                    Text(
                      'YOUR PERSONAL AI TUTOR',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    });
  }
}
