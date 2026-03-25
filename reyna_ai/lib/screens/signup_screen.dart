// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../widgets/glass_field.dart';
import '../widgets/gradient_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _customDomainCtrl = TextEditingController();
  
  bool _obscure = true;
  String? _ageBand;
  String? _education;
  String? _selectedDomain;
  bool _showCustomDomain = false;

  // Staggered entrance animations
  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final AnimationController _glowCtrl;

  // OULAD-compatible categories
  static const _ageBands = ['0-35', '35-55', '55+'];
  static const _educationLevels = [
    'Lower Than A Level',
    'A Level', 
    'HE',
    'Post Grad'
  ];

  // 20+ Tactical Domains
  static const Map<String, List<String>> _domainCategories = {
    'TECH': ['Data Science', 'Software Dev', 'CyberSec', 'AI/ML', 'DevOps'],
    'HEALTH': ['Medico', 'Nursing', 'Pharmacy', 'Radiology', 'Biotech'],
    'BUSINESS': ['MBA/Finance', 'Marketing', 'HR', 'Law', 'Consulting'],
    'ENGINEERING': ['Civil Engineering', 'Mechanical', 'Electrical', 'Chemical'],
    'CREATIVE': ['Digital Arts', 'Design', 'Music', 'Writing', 'Photography'],
    'SCIENCE': ['Physics', 'Chemistry', 'Biology', 'Mathematics', 'Psychology'],
  };

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _headerFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    ));

    _formFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);

    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _customDomainCtrl.dispose();
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email required';
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_ageBand == null) { _showError('Please select your age bracket'); return; }
    if (_education == null) { _showError('Please select your education level'); return; }
    if (_selectedDomain == null && !_showCustomDomain) { _showError('Please select a domain'); return; }
    if (_showCustomDomain && _customDomainCtrl.text.trim().isEmpty) { _showError('Please enter your custom domain'); return; }

    final state = context.read<AppState>();
    await state.signup(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      ageBand: _ageBand!,
      education: _education!,
      domain: _showCustomDomain ? _customDomainCtrl.text.trim() : _selectedDomain!,
    );

    if (!mounted) return;
    if (state.errorMessage != null) {
      _showError(state.errorMessage!);
    } else {
      Navigator.pushReplacementNamed(context, '/app');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: 'Space Grotesk')),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Ambient glow ─────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => Positioned(
                top: -40,
                left: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.primary.withOpacity(0.05 + 0.03 * _glowCtrl.value),
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
                          child: Icon(Icons.arrow_back,
                              color: AppColors.primary, size: 20),
                        ),
                      ),
                      SizedBox(height: 32),

                      // ── Header with stagger ──────────────────────────────
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerFade,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(colors: [
                                    AppColors.primary,
                                    Color(0xFFFEDADA),
                                  ]),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Create\nAccount',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                  height: 1.0,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Join Reyna AI and start your learning journey',
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
                      SizedBox(height: 32),

                      // ── Form with stagger ─────────────────────────────────
                      SlideTransition(
                        position: _formSlide,
                        child: FadeTransition(
                          opacity: _formFade,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GlassField(
                                label: 'YOUR NAME',
                                controller: _nameCtrl,
                                validator: (v) => (v == null || v.length < 2) ? 'Name required' : null,
                              ),
                              SizedBox(height: 14),
                              GlassField(
                                label: 'EMAIL',
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              SizedBox(height: 14),
                              GlassField(
                                label: 'PASSWORD',
                                controller: _passCtrl,
                                obscure: _obscure,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                    color: AppColors.outlineVariant, size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                              ),
                              SizedBox(height: 14),
                              GlassField(
                                label: 'CONFIRM PASSWORD',
                                controller: _confirmCtrl,
                                obscure: _obscure,
                                validator: (v) => v != _passCtrl.text ? 'Passwords must match' : null,
                              ),
                              SizedBox(height: 24),

                              // Age Band
                              _buildSectionHeader('AGE BRACKET'),
                              SizedBox(height: 12),
                              _buildAgeBandSelector(),
                              SizedBox(height: 24),

                              // Education
                              _buildSectionHeader('EDUCATION LEVEL'),
                              SizedBox(height: 12),
                              _buildEducationSelector(),
                              SizedBox(height: 24),

                              // Domain
                              _buildSectionHeader('YOUR DOMAIN'),
                              SizedBox(height: 12),
                              _buildDomainGrid(),
                              SizedBox(height: 36),

                              // Submit
                              GradientButton(
                                text: 'Create Profile',
                                isLoading: state.isLoading,
                                onTap: _submit,
                              ),
                              SizedBox(height: 20),
                              
                              // Login Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 12,
        letterSpacing: 2,
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildAgeBandSelector() {
    return Wrap(
      spacing: 8,
      children: _ageBands.map((band) {
        final selected = _ageBand == band;
        return GestureDetector(
          onTap: () => setState(() => _ageBand = band),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected 
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.surfaceContainerHigh,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              band,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEducationSelector() {
    return Column(
      children: _educationLevels.map((level) {
        final selected = _education == level;
        return GestureDetector(
          onTap: () => setState(() => _education = level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
                Icon(
                  Icons.school_outlined,
                  color: selected ? AppColors.primary : AppColors.outline,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    level,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check, color: AppColors.primary, size: 16),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDomainGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._domainCategories.entries.map((category) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                category.key,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 10,
                  letterSpacing: 2,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: category.value.map((domain) {
                final selected = _selectedDomain == domain;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDomain = domain;
                    _showCustomDomain = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: selected
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.surfaceContainerHigh,
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      domain,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
          ],
        )),
        
        // Custom Domain
        GestureDetector(
          onTap: () => setState(() {
            _showCustomDomain = !_showCustomDomain;
            if (_showCustomDomain) _selectedDomain = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _showCustomDomain
                ? AppColors.primary.withOpacity(0.10)
                : AppColors.surfaceContainerHigh,
              border: Border.all(
                color: _showCustomDomain ? AppColors.primary : AppColors.outlineVariant,
                width: _showCustomDomain ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  color: _showCustomDomain ? AppColors.primary : AppColors.outline,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CUSTOM DOMAIN',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _showCustomDomain ? AppColors.primary : AppColors.onSurface,
                    ),
                  ),
                ),
                if (_showCustomDomain)
                  Icon(Icons.check, color: AppColors.primary, size: 16),
              ],
            ),
          ),
        ),
        
        if (_showCustomDomain) ...[
          SizedBox(height: 12),
          GlassField(
            label: 'ENTER YOUR DOMAIN',
            controller: _customDomainCtrl,
            validator: _showCustomDomain 
              ? (v) => (v == null || v.trim().isEmpty) ? 'Custom domain required' : null
              : null,
          ),
        ],
      ],
    );
  }
}