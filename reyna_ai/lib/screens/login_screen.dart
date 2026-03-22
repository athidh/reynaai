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

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
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
        child: LayoutBuilder(builder: (ctx, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 400 ? 20 : 32,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back arrow
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back,
                          color: AppColors.primary, size: 26),
                    ),

                    const SizedBox(height: 40),

                    // ── Glow blob ───────────────────────────────────────────
                    Container(
                      width: 220, height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.primary.withOpacity(0.10),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Title ───────────────────────────────────────────────
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'INITIALIZE\nSESSION',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1.0,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'PROTOCOL: SECURE AUTHENTICATION',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 9,
                        letterSpacing: 3,
                        color: AppColors.outline,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Fields ──────────────────────────────────────────────
                    GlassField(
                      label: 'EMAIL',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Valid email required' : null,
                    ),
                    const SizedBox(height: 16),
                    GlassField(
                      label: 'PASSWORD',
                      controller: _passCtrl,
                      obscure: _obscure,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.outlineVariant, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Password required' : null,
                    ),

                    const SizedBox(height: 36),

                    // ── Submit ──────────────────────────────────────────────
                    GradientButton(label: 'DEVOUR', onTap: _submit),

                    const SizedBox(height: 20),

                    // ── Nav link ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('NEW OPERATIVE? ',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 11,
                                letterSpacing: 1.5,
                                color: AppColors.outline)),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                              context, '/signup'),
                          child: Text('ENLIST',
                              style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Shared gradient submit button ─────────────────────────────────────────────
class _GradientSubmit extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientSubmit({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.tertiary],
          ),
        ),
        child: TextButton(
          onPressed: onTap,
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: AppColors.onPrimary)),
        ),
      ),
    );
  }
}
