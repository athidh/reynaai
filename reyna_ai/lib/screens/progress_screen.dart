// lib/screens/progress_screen.dart
//
// Tactical Roadmap — Week 1-4 Stepper + Soul Orb + Battle Readiness gauge
// Falls back to static offline data immediately; real plan loads in background.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbCtrl;
  late Animation<double> _orbPulse;

  /// Static fallback days used when the backend study plan hasn't loaded yet
  static const List<Map<String, dynamic>> _staticDays = [
    {'day': 1, 'focus': 'Foundation Concepts',   'tip': 'Review core material',                        'daily_minutes': 45},
    {'day': 2, 'focus': 'Active Recall Practice', 'tip': 'Test yourself without notes',                'daily_minutes': 40},
    {'day': 3, 'focus': 'Spaced Repetition',      'tip': 'Revisit yesterday\'s content',               'daily_minutes': 35},
    {'day': 4, 'focus': 'Deep Dive Session',      'tip': 'Pick the hardest concept and master it',    'daily_minutes': 60},
    {'day': 5, 'focus': 'Practice Problems',      'tip': 'Apply knowledge to real problems',          'daily_minutes': 50},
    {'day': 6, 'focus': 'Weak Area Focus',        'tip': 'Identify and attack gaps',                  'daily_minutes': 45},
    {'day': 7, 'focus': 'Full Review',            'tip': 'Synthesise all week\'s learning',           'daily_minutes': 30},
  ];

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _orbPulse = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));

    // Load API data in background — UI shows static fallback immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.loadStudyPlan();
      state.loadSuccessProbability();
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  /// Groups day list into 4 week milestone buckets
  List<Map<String, dynamic>> _buildWeekMilestones(
      List<dynamic> days, double successProb) {
    const weekTitles = [
      'WEEK 1 — RECON',
      'WEEK 2 — ADVANCE',
      'WEEK 3 — STRIKE',
      'WEEK 4 — DOMINATE',
    ];
    const weekGoals = [
      'Establish foundations and daily study rhythm.',
      'Deepen understanding through active recall.',
      'Master concepts with spaced repetition.',
      'Elite performance through exam simulations.',
    ];

    final milestones = <Map<String, dynamic>>[];
    for (int w = 0; w < 4; w++) {
      final start = (w * days.length / 4).round();
      final end = ((w + 1) * days.length / 4).round().clamp(0, days.length);
      final weekDays = days.sublist(start, end);

      final weekThreshold = w / 3;
      final completed = successProb >= weekThreshold + 0.25;
      final active = !completed && successProb >= weekThreshold;

      milestones.add({
        'label': weekTitles[w],
        'goal': weekGoals[w],
        'days': weekDays,
        'completed': completed,
        'active': active,
      });
    }
    return milestones;
  }

  Color _rankToColor(String rank) {
    const c = {
      'RADIANT': Color(0xFFFF6D8D),
      'DIAMOND': Color(0xFF81D4FA),
      'PLATINUM': Color(0xFF80CBC4),
      'GOLD':    Color(0xFFFFD54F),
      'IRON':    Color(0xFF73757D),
    };
    return c[rank] ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.studyPlan;
    final prob = state.successProbability ?? 0.0;
    final rank = state.battleReadinessRank;
    final rankColor = _rankToColor(rank);

    // Use live API days when available, fall back to static immediately
    final days = plan != null
        ? ((plan['days'] as List?) ?? [])
        : _staticDays;

    final milestones = _buildWeekMilestones(days, prob);

    // Pulse speed tied to success probability
    _orbCtrl.duration =
        Duration(milliseconds: (2000 - (prob * 1200)).round().clamp(800, 2000));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TACTICAL',
                        style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            height: 0.9,
                            color: AppColors.onSurface)),
                    Text('ROADMAP',
                        style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            height: 0.9,
                            color: rankColor)),
                    const SizedBox(height: 20),

                    // ── Soul Orb + Battle Readiness ─────────────────────
                    _SoulOrbCard(
                      animation: _orbPulse,
                      probability: prob,
                      rank: rank,
                      rankColor: rankColor,
                      streakDays: state.streak,
                      xpGained: state.xpGained,
                      isLive: plan != null,
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text('⚡ WEEK MILESTONES',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppColors.onSurface)),
                        const Spacer(),
                        if (!state.hasVideoPlayed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: AppColors.surfaceContainerHigh,
                            child: const Text('WATCH A VIDEO TO UNLOCK',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 7,
                                    letterSpacing: 1.2,
                                    color: AppColors.outline)),
                          )
                        else if (plan != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: AppColors.primary.withOpacity(0.1),
                            child: const Text('AI GENERATED FROM YOUR VIDEO',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 7,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          )
                        else
                          const Text('OFFLINE MODE',
                              style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                  color: AppColors.outline)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── 7-Day Study Planner ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i >= days.length) return null;
                    final day = days[i] as Map<String, dynamic>;
                    final dayNum = (day['day'] as num?)?.toInt() ?? (i + 1);
                    final focus = day['focus'] as String? ?? 'Study Session';
                    final tip = day['tip'] as String? ??
                        (day['tasks'] is List && (day['tasks'] as List).isNotEmpty
                            ? (day['tasks'] as List).first.toString()
                            : '');
                    // API returns 'recommended_minutes'; static fallback uses 'daily_minutes'
                    final mins = ((day['recommended_minutes'] ?? day['daily_minutes']) as num?)?.toInt() ?? 45;
                    final isToday = i == 0;
                    final locked = !state.hasVideoPlayed;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isToday
                            ? rankColor.withOpacity(0.07)
                            : AppColors.surfaceContainerHigh,
                        border: Border.all(
                          color: isToday ? rankColor : AppColors.primaryContainer,
                          width: isToday ? 1.5 : 1,
                        ),
                      ),
                      child: locked
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Container(
                                  width: 36, height: 36,
                                  color: AppColors.surfaceContainerHighest,
                                  child: Center(child: Text('D$dayNum',
                                      style: const TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontSize: 10, fontWeight: FontWeight.w900,
                                          color: AppColors.outlineVariant))),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(child: Text('Watch a video to unlock',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontFamily: 'Manrope', fontSize: 12,
                                        color: AppColors.outlineVariant))),
                                const SizedBox(width: 8),
                                const Icon(Icons.lock_outline,
                                    color: AppColors.outlineVariant, size: 16),
                              ]),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Day badge
                                  Container(
                                    width: 36, height: 36,
                                    color: isToday
                                        ? rankColor
                                        : AppColors.surfaceContainerHighest,
                                    child: Center(child: Text('D$dayNum',
                                        style: TextStyle(
                                            fontFamily: 'Space Grotesk',
                                            fontSize: 10, fontWeight: FontWeight.w900,
                                            color: isToday ? Colors.white : AppColors.onSurface))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(child: Text(focus,
                                              style: const TextStyle(
                                                  fontFamily: 'Space Grotesk',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.onSurface))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            color: AppColors.primary.withOpacity(0.1),
                                            child: Text('${mins}min',
                                                style: const TextStyle(
                                                    fontFamily: 'Space Grotesk',
                                                    fontSize: 8,
                                                    letterSpacing: 1,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary)),
                                          ),
                                        ]),
                                        if (tip.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(tip,
                                              style: const TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 11,
                                                  height: 1.4,
                                                  color: AppColors.onSurfaceVariant),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                        if (isToday) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            color: rankColor.withOpacity(0.15),
                                            child: Text('TODAY',
                                                style: TextStyle(
                                                    fontFamily: 'Space Grotesk',
                                                    fontSize: 7,
                                                    letterSpacing: 1.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: rankColor)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    );
                  },
                  childCount: days.length.clamp(1, 7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Soul Orb Card ─────────────────────────────────────────────────────────────
class _SoulOrbCard extends StatelessWidget {
  final Animation<double> animation;
  final double probability;
  final String rank;
  final Color rankColor;
  final int streakDays;
  final int xpGained;
  final bool isLive;

  const _SoulOrbCard({
    required this.animation,
    required this.probability,
    required this.rank,
    required this.rankColor,
    required this.streakDays,
    required this.xpGained,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (probability * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        border: Border(left: BorderSide(color: rankColor, width: 4)),
      ),
      child: Row(
        children: [
          // Pulsing Soul Orb
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Transform.scale(
              scale: animation.value,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rankColor.withOpacity(0.15),
                  border: Border.all(color: rankColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withOpacity(0.4 * animation.value),
                      blurRadius: 20 * animation.value,
                      spreadRadius: 4 * animation.value,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(rank[0],
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: rankColor)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(rank,
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 11,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                          color: rankColor)),
                  if (isLive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Text('LIVE',
                          style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 7,
                              letterSpacing: 1,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                const Text('BATTLE READINESS',
                    style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 8,
                        letterSpacing: 2,
                        color: AppColors.outline)),
                const SizedBox(height: 6),
                // Progress bar
                ClipRect(
                  child: SizedBox(
                    height: 6,
                    child: Row(children: [
                      Flexible(flex: pct,       child: Container(color: rankColor)),
                      Flexible(flex: 100 - pct, child: Container(color: AppColors.surfaceContainerHighest)),
                    ]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                   '$pct% promotion chance  •  ${streakDays}d streak',
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                   style: const TextStyle(
                       fontFamily: 'Manrope',
                       fontSize: 10,
                       height: 1.4,
                       color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week Milestone ────────────────────────────────────────────────────────────
class _WeekMilestone extends StatelessWidget {
  final int index;
  final String label;
  final String goal;
  final List<Map<String, dynamic>> days;
  final bool isCompleted;
  final bool isActive;
  final Color rankColor;
  final bool isLast;

  const _WeekMilestone({
    required this.index,
    required this.label,
    required this.goal,
    required this.days,
    required this.isCompleted,
    required this.isActive,
    required this.rankColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isCompleted
        ? const Color(0xFF4CAF50)
        : isActive
            ? rankColor
            : AppColors.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stepper indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF4CAF50)
                        : isActive
                            ? rankColor
                            : AppColors.surfaceContainerHigh,
                    border: Border.all(color: accentColor, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text('${index + 1}',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isActive ? Colors.white : AppColors.outline)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted
                          ? const Color(0xFF4CAF50)
                          : AppColors.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: accentColor)),
                  const SizedBox(height: 4),
                  Text(goal,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                  if (isActive && days.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...days.take(2).map((day) => _DayTile(day: day)),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final Map<String, dynamic> day;
  const _DayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      color: AppColors.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('DAY ${day['day'] ?? '—'}',
                style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 8,
                    letterSpacing: 1.5,
                    color: AppColors.outline)),
            const Spacer(),
            Text('${day['daily_minutes'] ?? 0} min',
                style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 8,
                    letterSpacing: 1,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 4),
          Text(day['focus'] ?? '',
              style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          if (day['tip'] != null) ...[
            const SizedBox(height: 2),
            Text('💡 ${day['tip']}',
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
