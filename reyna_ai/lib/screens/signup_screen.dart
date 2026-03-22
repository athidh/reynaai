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

class _SignupScreenState extends State<SignupScreen> {
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
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _customDomainCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email required';
    }
    // Improved email validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_ageBand == null) {
      _showError('Please select your age bracket');
      return;
    }
    
    if (_education == null) {
      _showError('Please select your education level');
      return;
    }
    
    if (_selectedDomain == null && !_showCustomDomain) {
      _showError('Please select a domain or choose Custom');
      return;
    }
    
    if (_showCustomDomain && _customDomainCtrl.text.trim().isEmpty) {
      _showError('Please enter your custom domain');
      return;
    }

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
        content: Text(message, style: const TextStyle(fontFamily: 'Space Grotesk')),
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
        child: LayoutBuilder(builder: (ctx, constraints) {
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
                  // Header
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(height: 40),
                  
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'ENLIST\nOPERATIVE',
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
                    'PROTOCOL: COMPLETE OPERATIVE REGISTRATION',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 9,
                      letterSpacing: 3,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Basic Info
                  GlassField(
                    label: 'OPERATIVE NAME',
                    controller: _nameCtrl,
                    validator: (v) => (v == null || v.length < 2) ? 'Name required' : null,
                  ),
                  const SizedBox(height: 14),
                  
                  GlassField(
                    label: 'EMAIL',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 14),
                  
                  GlassField(
                    label: 'PASSWORD',
                    controller: _passCtrl,
                    obscure: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.outlineVariant, 
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 14),
                  
                  GlassField(
                    label: 'CONFIRM PASSWORD',
                    controller: _confirmCtrl,
                    obscure: _obscure,
                    validator: (v) => v != _passCtrl.text ? 'Passwords must match' : null,
                  ),
                  const SizedBox(height: 24),

                  // Age Band Selection
                  _buildSectionHeader('AGE BRACKET'),
                  const SizedBox(height: 12),
                  _buildAgeBandSelector(),
                  const SizedBox(height: 24),

                  // Education Level Selection
                  _buildSectionHeader('EDUCATION LEVEL'),
                  const SizedBox(height: 12),
                  _buildEducationSelector(),
                  const SizedBox(height: 24),

                  // Tactical Domain Grid
                  _buildSectionHeader('TACTICAL DOMAIN'),
                  const SizedBox(height: 12),
                  _buildDomainGrid(),
                  const SizedBox(height: 36),

                  // Submit Button
                  GradientButton(
                    label: 'INITIALIZE PROTOCOL',
                    onTap: state.isLoading ? null : _submit,
                    isLoading: state.isLoading,
                  ),
                  const SizedBox(height: 20),
                  
                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ALREADY ENLISTED? ',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: AppColors.outline,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: Text(
                          'LOGIN',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
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
            margin: const EdgeInsets.only(bottom: 8),
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
                Icon(
                  Icons.school_outlined,
                  color: selected ? AppColors.primary : AppColors.outline,
                  size: 20,
                ),
                const SizedBox(width: 12),
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
                  const Icon(Icons.check, color: AppColors.primary, size: 16),
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                category.key,
                style: const TextStyle(
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
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
            const SizedBox(height: 16),
          ],
        )).toList(),
        
        // Custom Domain Option
        GestureDetector(
          onTap: () => setState(() {
            _showCustomDomain = !_showCustomDomain;
            if (_showCustomDomain) _selectedDomain = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
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
                const SizedBox(width: 12),
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
                  const Icon(Icons.check, color: AppColors.primary, size: 16),
              ],
            ),
          ),
        ),
        
        if (_showCustomDomain) ...[
          const SizedBox(height: 12),
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
