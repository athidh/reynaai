// lib/screens/landing_screen.dart
//
// Landing Screen — Aurora Wave with Glassmorphism UI
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
  late final Animation<Offset> _btnSlide;
  bool _showButtons = false;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOutCubic));

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
    final padH = sw < 400 ? 24.0 : 36.0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Full-screen aurora hero ─────────────────────────────────────
            const Positioned.fill(child: ParticleHero()),

            // ── Top status bar ──────────────────────────────────────────────
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

            // ── Pulsing Soul Orb ────────────────────────────────────────────
            Positioned(
              top: mq.size.height * 0.22,
              left: 0,
              right: 0,
              child: const Center(child: _SoulOrbIcon()),
            ),

            // ── Corner accent brackets ──────────────────────────────────────
            ..._corners(),

            // ── CTA buttons ─────────────────────────────────────────────────
            if (_showButtons)
              Positioned(
                bottom: math.max(mq.padding.bottom + 8, 24),
                left: padH,
                right: padH,
                child: SlideTransition(
                  position: _btnSlide,
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
              ),

            // ── Bottom HUD ──────────────────────────────────────────────────
            if (!_showButtons)
              const Positioned(
                bottom: 8,
                left: 20,
                child: _HudLabel('AURORA_WAVE [ ACTIVE ]'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const s = 44.0;
    final c = AppColors.primary.withOpacity(0.20);
    Widget mk(Alignment a) => Positioned.fill(
          child: Align(
            alignment: a,
            child: SizedBox(
              width: s,
              height: s,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: (a == Alignment.topLeft || a == Alignment.topRight)
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
// Pulsing Soul Orb icon
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
    _c = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePulseSpeed();
  }

  void _updatePulseSpeed() {
    final state = Provider.of<AppState>(context, listen: false);
    final successProb = state.engagementScore;
    final duration = 2.0 - (1.5 * successProb);
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
    final intensity = 0.15 + (0.35 * state.engagementScore);
    
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(intensity + 0.2 * _c.value),
              blurRadius: 14 + (18 * _c.value) + (10 * state.engagementScore),
            ),
            BoxShadow(
              color: const Color(0xFFC6E6FF).withOpacity(0.1 * _c.value),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
              colors: [Color(0xFF6A49FA), Color(0xFFC6E6FF)]),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A49FA).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
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
                    color: Color(0xFF0D0B1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: const Color(0xFF0D0B1A), size: 18),
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
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(
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
            color: AppColors.outlineVariant),
      );
}
