// lib/screens/progress_screen.dart
//
// Tactical Roadmap — Week 1-4 Stepper + Soul Orb + Battle Readiness gauge
// Falls back to static offline data immediately; real plan loads in background.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
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
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TACTICAL',
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
                    SizedBox(height: 20),

                    // ── Soul Orb + Battle Readiness (R6) ─────────────────────
                    _SoulOrbCard(
                      animation: _orbPulse,
                      probability: prob,
                      rank: state.battleRankBadge, // R8 Badge
                      rankColor: rankColor,
                      streakDays: state.streak,
                      xpGained: state.xpGained,
                      isLive: plan != null,
                    ),

                    SizedBox(height: 24),
                    
                    // ── Analytics Dashboard Chart (R8) ────────────────────────
                    if (state.engagementTrendData.isNotEmpty) ...[
                      Text('ENGAGEMENT TREND (7 DAYS)',
                          style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: AppColors.onSurface)),
                      SizedBox(height: 16),
                      Container(
                        height: 200,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: _EngagementChart(trendData: state.engagementTrendData),
                      ),
                      SizedBox(height: 24),
                    ],


                    Row(
                      children: [
                        Text('⚡ WEEK MILESTONES',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppColors.onSurface)),
                        const Spacer(),
                        if (!state.hasVideoPlayed)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: AppColors.surfaceContainerHigh,
                            child: Text('WATCH A VIDEO TO UNLOCK',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 7,
                                    letterSpacing: 1.2,
                                    color: AppColors.outline)),
                          )
                        else if (plan != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: AppColors.primary.withOpacity(0.1),
                            child: Text('AI GENERATED FROM YOUR VIDEO',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 7,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          )
                        else
                          Text('OFFLINE MODE',
                              style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                  color: AppColors.outline)),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── 7-Day Study Planner ───────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
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
                      margin: EdgeInsets.only(bottom: 10),
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
                              padding: EdgeInsets.all(16),
                              child: Row(children: [
                                Container(
                                  width: 36, height: 36,
                                  color: AppColors.surfaceContainerHighest,
                                  child: Center(child: Text('D$dayNum',
                                      style: TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontSize: 10, fontWeight: FontWeight.w900,
                                          color: AppColors.outlineVariant))),
                                ),
                                SizedBox(width: 12),
                                Expanded(child: Text('Watch a video to unlock',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontFamily: 'Manrope', fontSize: 12,
                                        color: AppColors.outlineVariant))),
                                SizedBox(width: 8),
                                Icon(Icons.lock_outline,
                                    color: AppColors.outlineVariant, size: 16),
                              ]),
                            )
                          : Padding(
                              padding: EdgeInsets.all(16),
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
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(child: Text(focus,
                                              style: TextStyle(
                                                  fontFamily: 'Space Grotesk',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.onSurface))),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            color: AppColors.primary.withOpacity(0.1),
                                            child: Text('${mins}min',
                                                style: TextStyle(
                                                    fontFamily: 'Space Grotesk',
                                                    fontSize: 8,
                                                    letterSpacing: 1,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary)),
                                          ),
                                        ]),
                                        if (tip.isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          Text(tip,
                                              style: TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 11,
                                                  height: 1.4,
                                                  color: AppColors.onSurfaceVariant),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                        if (isToday) ...[
                                          SizedBox(height: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(
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
    
    // R6 Probability Thresholds
    final Color orbColor = probability > 0.75 
        ? Colors.green 
        : (probability < 0.50 ? Colors.amber : rankColor);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        border: Border(left: BorderSide(color: orbColor, width: 4)),
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
                  color: orbColor.withOpacity(0.15),
                  border: Border.all(color: orbColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: orbColor.withOpacity(0.4 * animation.value),
                      blurRadius: 20 * animation.value,
                      spreadRadius: 4 * animation.value,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(rank[0].toUpperCase(),
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: orbColor)),
                ),
              ),
            ),
          ),
          SizedBox(width: 20),
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
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      color: AppColors.primary.withOpacity(0.1),
                      child: Text('LIVE',
                          style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 7,
                              letterSpacing: 1,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                SizedBox(height: 4),
                Text('BATTLE READINESS',
                    style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 8,
                        letterSpacing: 2,
                        color: AppColors.outline)),
                SizedBox(height: 6),
                // Progress bar
                ClipRect(
                  child: SizedBox(
                    height: 6,
                    child: Row(children: [
                      Flexible(flex: pct,       child: Container(color: orbColor)),
                      Flexible(flex: 100 - pct, child: Container(color: AppColors.surfaceContainerHighest)),
                    ]),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                   '$pct% promotion chance  •  ${streakDays}d streak',
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                   style: TextStyle(
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
                        ? Icon(Icons.check, color: Colors.white, size: 16)
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
                      margin: EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted
                          ? const Color(0xFF4CAF50)
                          : AppColors.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12),
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
                  SizedBox(height: 4),
                  Text(goal,
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                  if (isActive && days.isNotEmpty) ...[
                    SizedBox(height: 12),
                    ...days.take(2).map((day) => _DayTile(day: day)),
                  ],
                  SizedBox(height: 4),
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
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.all(10),
      color: AppColors.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('DAY ${day['day'] ?? '—'}',
                style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 8,
                    letterSpacing: 1.5,
                    color: AppColors.outline)),
            const Spacer(),
            Text('${day['daily_minutes'] ?? 0} min',
                style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 8,
                    letterSpacing: 1,
                    color: AppColors.primary)),
          ]),
          SizedBox(height: 4),
          Text(day['focus'] ?? '',
              style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          if (day['tip'] != null) ...[
            SizedBox(height: 2),
            Text('💡 ${day['tip']}',
                style: TextStyle(
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

// ── Engagement Chart (R8) ──────────────────────────────────────────────────
class _EngagementChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  const _EngagementChart({required this.trendData});

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) return const SizedBox.shrink();

    final maxScore = trendData
        .map((e) => (e['score'] as num?)?.toDouble() ?? 0.0)
        .fold<double>(0.0, (m, v) => v > m ? v : m);
    
    final maxY = maxScore > 10 ? maxScore * 1.2 : 10.0;

    final spots = trendData.asMap().entries.map((e) {
      final score = (e.value['score'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), score);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.outlineVariant.withOpacity(0.5),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trendData.length) return const SizedBox.shrink();
                final dateStr = trendData[idx]['date'] as String?;
                if (dateStr == null || dateStr.length < 10) return const SizedBox.shrink();
                // Extract "MM-DD" from "YYYY-MM-DD"
                final display = dateStr.substring(5, 10);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(display,
                      style: TextStyle(
                          color: AppColors.outline,
                          fontSize: 9,
                          fontFamily: 'Space Grotesk')),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 4,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(),
                    style: TextStyle(
                        color: AppColors.outline,
                        fontSize: 9,
                        fontFamily: 'Space Grotesk'));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (trendData.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            tooltipBorder: BorderSide(color: AppColors.outlineVariant),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Space Grotesk',
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}