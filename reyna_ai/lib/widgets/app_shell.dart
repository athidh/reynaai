// lib/widgets/app_shell.dart
//
// 4-tab app shell:
//   0 — COMMAND  (Dashboard + in-app YouTube player)
//   1 — ARENA    (Flashcards)
//   2 — ROADMAP  (Tactical progress stepper)
//   3 — CHAT     (Reyna Command Center)
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/flashcard_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/chat_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _tab = 0;

  /// Called from child screens (e.g. video player → Arena)
  void switchTab(int index) => setState(() => _tab = index);

  static const _screens = <Widget>[
    DashboardScreen(),
    FlashcardScreen(),
    ProgressScreen(),
    ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: IndexedStack(index: _tab, children: _screens),
        extendBody: true,
        bottomNavigationBar: _NavBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

// ── Glassmorphism nav bar ──────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _NavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard,      'COMMAND'),
    _NavItem(Icons.style_outlined,     Icons.style,          'ARENA'),
    _NavItem(Icons.map_outlined,       Icons.map,            'ROADMAP'),
    _NavItem(Icons.chat_bubble_outline,Icons.chat_bubble,    'CHAT'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
                top: BorderSide(color: AppColors.primaryContainer, width: 1)),
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        size: active ? 22 : 20,
                        color: active ? AppColors.primary : AppColors.outlineVariant,
                      ),
                      SizedBox(height: 3),
                      Text(item.label,
                          style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 7,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.outlineVariant)),
                      SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 16 : 0,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}