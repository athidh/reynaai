// lib/screens/onboarding_screen.dart
//
// Multi-step Onboarding — 3 steps: Name → Age → Domain
// Receives email+password from signup_screen via Navigator arguments.
// On INITIALIZE → calls AppState.signup() with all collected data.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // Received from signup_screen via arguments
  String _email = '';
  String _password = '';

  int _step = 0; // 0 = Name, 1 = Age, 2 = Education, 3 = Domain
  final _nameCtrl = TextEditingController();
  String? _ageBand;
  String? _education;
  String? _domain;
  String? _gender;

  late final AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  // OULAD-compatible categories
  static const _ageBands = ['0-35', '35-55', '55+'];
  static const _educationLevels = [
    'Lower Than A Level',
    'A Level or Equivalent', 
    'HE Qualification',
    'Post Graduate Qualification'
  ];
  static const _domains = ['MEDICO', 'DATA SCIENTIST', 'CUSTOM'];
  static const _domainIcons = [
    Icons.local_hospital_outlined,
    Icons.bar_chart_outlined,
    Icons.tune_outlined,
  ];
  static const _genders = ['M', 'F', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, String>) {
      _email = args['email'] ?? '';
      _password = args['password'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && _nameCtrl.text.trim().isEmpty) return;
    if (_step < 3) {
      _slideCtrl.reset();
      setState(() => _step++);
      _slideCtrl.forward();
    } else {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final state = context.read<AppState>();
    await state.signup(
      name: _nameCtrl.text.trim(),
      email: _email,
      password: _password,
      ageBand: _ageBand!,
      education: _education!,
      domain: _domain ?? 'Custom',
      gender: _gender == 'Prefer not to say' ? null : _gender,
    );
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
    final state = context.watch<AppState>();
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top progress strip ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step dots
                  Row(
                    children: List.generate(4, (i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: i == _step ? 28 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? AppColors.primary
                              : AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                    mainAxisAlignment: MainAxisAlignment.start,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _step == 0
                        ? 'OPERATIVE\nDESIGNATION'
                        : _step == 1
                            ? 'AGE\nBRACKET'
                            : _step == 2
                                ? 'EDUCATION\nLEVEL'
                                : 'SELECT\nDOMAIN',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: sw < 380 ? 28 : 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 0.95,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _step == 0
                        ? 'What should Reyna call you?'
                        : _step == 1
                            ? 'Select your age bracket for personalized learning.'
                            : _step == 2
                                ? 'Your highest education level helps tailor content.'
                                : 'Choose your primary study domain.',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Step content ──────────────────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _step == 0
                      ? _nameStep()
                      : _step == 1
                          ? _ageBandStep()
                          : _step == 2
                              ? _educationStep()
                              : _domainStep(),
                ),
              ),
            ),

            // ── CTA button ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6A49FA), Color(0xFFC6E6FF)]),
                  ),
                  child: TextButton(
                    onPressed: state.isLoading ? null : _nextStep,
                    child: state.isLoading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ))
                        : Text(
                            _step < 3 ? 'NEXT →' : 'INITIALIZE PROTOCOL',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Color(0xFF0D0B1A),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YOUR NAME', style: TextStyle(
            fontFamily: 'Space Grotesk', fontSize: 9,
            letterSpacing: 3, color: AppColors.primary,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            border: Border.all(color: AppColors.primaryContainer, width: 1.5),
          ),
          child: TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
                fontFamily: 'Space Grotesk', fontSize: 22,
                fontWeight: FontWeight.w800, color: AppColors.onSurface,
                letterSpacing: -0.5),
            cursorColor: AppColors.primary,
            decoration: const InputDecoration(
              hintText: 'e.g. ATHIDH',
              hintStyle: TextStyle(
                  fontFamily: 'Space Grotesk', fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.outlineVariant, letterSpacing: -0.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(20),
            ),
            onSubmitted: (_) => _nextStep(),
          ),
        ),
      ],
    );
  }

  Widget _ageBandStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AGE BRACKET', style: TextStyle(
            fontFamily: 'Space Grotesk', fontSize: 9,
            letterSpacing: 3, color: AppColors.primary,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ..._ageBands.map((band) {
          final selected = _ageBand == band;
          return GestureDetector(
            onTap: () => setState(() => _ageBand = band),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.10)
                    : AppColors.surfaceContainerHigh,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline,
                      color: selected ? AppColors.primary : AppColors.outline,
                      size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(band,
                        style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: selected
                                ? AppColors.primary
                                : AppColors.onSurface)),
                  ),
                  if (selected)
                    const Icon(Icons.check, color: AppColors.primary, size: 18),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _nextStep,
          child: const Text('SKIP →',
              style: TextStyle(fontFamily: 'Space Grotesk',
                  fontSize: 10, letterSpacing: 2,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _educationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EDUCATION LEVEL', style: TextStyle(
            fontFamily: 'Space Grotesk', fontSize: 9,
            letterSpacing: 3, color: AppColors.primary,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ..._educationLevels.map((level) {
          final selected = _education == level;
          return GestureDetector(
            onTap: () => setState(() => _education = level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.10)
                    : AppColors.surfaceContainerHigh,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.school_outlined,
                      color: selected ? AppColors.primary : AppColors.outline,
                      size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(level,
                        style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: selected
                                ? AppColors.primary
                                : AppColors.onSurface)),
                  ),
                  if (selected)
                    const Icon(Icons.check, color: AppColors.primary, size: 16),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _nextStep,
          child: const Text('SKIP →',
              style: TextStyle(fontFamily: 'Space Grotesk',
                  fontSize: 10, letterSpacing: 2,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _domainStep() {
    return Column(
      children: List.generate(_domains.length, (i) {
        final selected = _domain == _domains[i];
        return GestureDetector(
          onTap: () => setState(() => _domain = _domains[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.10)
                  : AppColors.surfaceContainerHigh,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(_domainIcons[i],
                    color: selected ? AppColors.primary : AppColors.outline,
                    size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(_domains[i],
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: selected
                              ? AppColors.primary
                              : AppColors.onSurface)),
                ),
                if (selected)
                  const Icon(Icons.check, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        );
      }),
    );
  }
}
