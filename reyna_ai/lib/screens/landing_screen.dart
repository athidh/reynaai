// lib/screens/landing_screen.dart
//
// Landing Screen — Layout & Overflow Fix
// ──────────────────────────────────────────────────────────────────────────────
//  • SafeArea → no notch/system-bar overflow
//  • Stack-based layout — particle hero fills entire screen
//  • No Column wrapping the whole screen (avoids vertical constraint fights)
//  • CTA buttons pinned to bottom via Positioned with MediaQuery-aware padding
//  • "REYNA AI" + subtext are inside ParticleHero itself (perfectly co-located)
// ──────────────────────────────────────────────────────────────────────────────
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../widgets/particle_hero.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnFade;
  bool _showButtons = false;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    // Buttons appear after particle animation completes (4 000ms + 200ms delay)
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) {
        setState(() => _showButtons = true);
        _btnCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final padH = sw < 400 ? 24.0 : 36.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Dot-mesh background ────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _DotMesh()),
            ),

            // ── Corner accent brackets ─────────────────────────────────────
            ..._corners(),

            // ── Full-screen particle hero ──────────────────────────────────
            // ParticleHero draws particles + neon "REYNA AI" + subtext itself.
            // The text is placed at 42% height to leave room above and below.
            const Positioned.fill(child: ParticleHero()),

            // ── Top status bar ─────────────────────────────────────────────
            Positioned(
              top: 12,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Text(
                    'REYNA_AI',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: sw < 360 ? 14 : 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  const _HudLabel('SYSTEM: ACTIVE'),
                ],
              ),
            ),

            // ── Soul Orb icon centred above particle zone ──────────────────
            Positioned(
              top: sh * 0.22,
              left: 0,
              right: 0,
              child: const Center(child: _SoulOrbIcon()),
            ),

            // ── CTA buttons — fixed to bottom, never overflow ──────────────
            if (_showButtons)
              Positioned(
                bottom: math.max(mq.padding.bottom + 8, 24),
                left: padH,
                right: padH,
                child: FadeTransition(
                  opacity: _btnFade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GradientBtn(
                        label: 'GET STARTED',
                        icon: Icons.bolt,
                        onTap: () =>
                            Navigator.pushNamed(context, '/signup'),
                      ),
                      const SizedBox(height: 12),
                      _OutlineBtn(
                        label: 'LOGIN',
                        onTap: () =>
                            Navigator.pushNamed(context, '/login'),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Bottom status HUD — hidden once buttons appear (avoids 16px overlap) ──
            if (!_showButtons)
              Positioned(
                bottom: 8,
                left: 20,
                child: const _HudLabel('NEURAL_PARTICLES [ 400 ]'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const s = 44.0;
    final c = AppColors.primary.withOpacity(0.30);
    Widget mk(Alignment a) => Positioned.fill(
          child: Align(
            alignment: a,
            child: SizedBox(
              width: s,
              height: s,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: (a == Alignment.topLeft ||
                            a == Alignment.topRight)
                        ? BorderSide(color: c, width: 2)
                        : BorderSide.none,
                    bottom: (a == Alignment.bottomLeft ||
                            a == Alignment.bottomRight)
                        ? BorderSide(color: c, width: 2)
                        : BorderSide.none,
                    left: (a == Alignment.topLeft ||
                            a == Alignment.bottomLeft)
                        ? BorderSide(color: c, width: 2)
                        : BorderSide.none,
                    right: (a == Alignment.topRight ||
                            a == Alignment.bottomRight)
                        ? BorderSide(color: c, width: 2)
                        : BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        );
    return [
      mk(Alignment.topLeft),
      mk(Alignment.topRight),
      mk(Alignment.bottomLeft),
      mk(Alignment.bottomRight),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Soul Orb icon - pulses faster based on ML Success Probability
// ─────────────────────────────────────────────────────────────────────────────
class _SoulOrbIcon extends StatefulWidget {
  const _SoulOrbIcon();
  @override
  State<_SoulOrbIcon> createState() => _SoulOrbIconState();
}

class _SoulOrbIconState extends State<_SoulOrbIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  
  @override
  void initState() {
    super.initState();
    // Initialize with default 2-second duration
    _c = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update pulse speed based on engagement score
    _updatePulseSpeed();
  }

  void _updatePulseSpeed() {
    final state = Provider.of<AppState>(context, listen: false);
    // Base duration: 2 seconds, faster as success probability increases
    // 0.0 probability = 2.0 seconds, 1.0 probability = 0.5 seconds
    final successProb = state.engagementScore; // This represents success probability
    final duration = 2.0 - (1.5 * successProb); // 2.0s -> 0.5s
    
    // Update existing controller's duration instead of creating new one
    _c.duration = Duration(milliseconds: (duration * 1000).round());
    if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final intensity = 0.15 + (0.35 * state.engagementScore); // More intense glow with higher success
    
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(intensity + 0.2 * _c.value),
                blurRadius: 14 + (18 * _c.value) + (10 * state.engagementScore),
              ),
            ],
          ),
          child: Center(
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 11,
                height: 11,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA buttons
// ─────────────────────────────────────────────────────────────────────────────
class _GradientBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFC428FF), Color(0xFFFF6D8D)]),
        ),
        child: TextButton(
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Color(0xFF4F006D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: const Color(0xFF4F006D), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary, width: 1.5),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD label
// ─────────────────────────────────────────────────────────────────────────────
class _HudLabel extends StatelessWidget {
  final String text;
  const _HudLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 8,
            letterSpacing: 2,
            color: Color(0xFF45484F)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot mesh background painter
// ─────────────────────────────────────────────────────────────────────────────
class _DotMesh extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFC428FF).withOpacity(0.06);
    const spacing = 26.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotMesh _) => false;
}
