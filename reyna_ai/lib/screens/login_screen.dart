// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../widgets/glass_field.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  // Staggered entrance animations
  late final AnimationController _staggerCtrl;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _fieldsFade;
  late final Animation<Offset> _fieldsSlide;
  late final Animation<double> _btnFade;
  late final Animation<Offset> _btnSlide;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _titleFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    ));

    _fieldsFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );
    _fieldsSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
    ));

    _btnFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    ));

    // Ambient glow animation
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);

    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    await state.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!,
              style: const TextStyle(fontFamily: 'Space Grotesk')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Animated gradient glow background ────────────────────────────
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => Positioned(
                top: -60,
                right: -80,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.primary
                          .withOpacity(0.06 + 0.04 * _glowCtrl.value),
                      const Color(0xFFC6E6FF)
                          .withOpacity(0.03 * _glowCtrl.value),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => Positioned(
                bottom: -40,
                left: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFFEDADA)
                          .withOpacity(0.04 + 0.03 * _glowCtrl.value),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),

            // ── Form content ─────────────────────────────────────────────────
            LayoutBuilder(builder: (ctx, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth < 400 ? 20 : 32,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back arrow
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: AppColors.primary, size: 20),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // ── Title with stagger ──────────────────────────────
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Decorative accent line
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: const LinearGradient(colors: [
                                      AppColors.primary,
                                      Color(0xFFC6E6FF),
                                    ]),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Welcome\nBack',
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    height: 1.0,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sign in to continue your learning journey',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Fields with stagger ─────────────────────────────
                        SlideTransition(
                          position: _fieldsSlide,
                          child: FadeTransition(
                            opacity: _fieldsFade,
                            child: Column(
                              children: [
                                GlassField(
                                  label: 'EMAIL',
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Valid email required'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                GlassField(
                                  label: 'PASSWORD',
                                  controller: _passCtrl,
                                  obscure: _obscure,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppColors.outlineVariant,
                                        size: 20),
                                    onPressed: () => setState(
                                        () => _obscure = !_obscure),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Password required'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Submit with stagger ─────────────────────────────
                        SlideTransition(
                          position: _btnSlide,
                          child: FadeTransition(
                            opacity: _btnFade,
                            child: Column(
                              children: [
                                GradientButton(
                                    label: 'SIGN IN', onTap: _submit),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Don\'t have an account? ',
                                        style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 13,
                                            color: AppColors.outline)),
                                    GestureDetector(
                                      onTap: () =>
                                          Navigator.pushReplacementNamed(
                                              context, '/signup'),
                                      child: const Text('Sign Up',
                                          style: TextStyle(
                                              fontFamily: 'Space Grotesk',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
