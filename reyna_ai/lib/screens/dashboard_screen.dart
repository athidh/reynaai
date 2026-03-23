// lib/screens/dashboard_screen.dart
//
// Combat Dashboard — Live YouTube GridView + In-App Player + Language Filter
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _selectedLang = 'en';     // language filter
  Mission? _playingMission;        // currently open player

  static const _languages = {
    'en': '🇬🇧 English',
    'hi': '🇮🇳 Hindi',
    'ta': '🇮🇳 Tamil',
    'es': '🇪🇸 Spanish',
    'fr': '🇫🇷 French',
    'de': '🇩🇪 German',
    'ja': '🇯🇵 Japanese',
    'zh': '🇨🇳 Chinese',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.loadEngagementProfile();
      state.loadStudyPlan();
      state.loadSuccessProbability();
      final domain = state.domainInterest;
      if (domain != null && domain.isNotEmpty && state.dynamicMissions.isEmpty) {
        state.loadDynamicMissions(domain, language: _selectedLang);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Detect whether the text is a YouTube URL ─────────────────────────────
  String? _extractVideoId(String text) {
    // youtu.be/VIDEO_ID or youtube.com/watch?v=VIDEO_ID
    final short = RegExp(r'youtu\.be/([A-Za-z0-9_-]{11})').firstMatch(text);
    if (short != null) return short.group(1);
    final full  = RegExp(r'[?&]v=([A-Za-z0-9_-]{11})').firstMatch(text);
    if (full  != null) return full.group(1);
    return null;
  }

  Future<void> _searchMissions() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;

    // If it's a YouTube URL → direct fetch → show player immediately
    final videoId = _extractVideoId(q);
    if (videoId != null) {
      final fakeMission = Mission(
        id: videoId,
        title: 'Direct Link',
        subtitle: q,
        progress: 0,
        rank: 'ELITE',
        cardCount: 5,
        videoId: videoId,
        thumbnail: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      );
      setState(() => _playingMission = fakeMission);
      return;
    }

    // Otherwise do a normal search
    setState(() => _searching = true);
    await context.read<AppState>().loadDynamicMissions(q, language: _selectedLang);
    if (mounted) setState(() => _searching = false);
  }

  void _openPlayer(Mission mission) {
    if (mission.videoId == null) return;
    setState(() => _playingMission = mission);
  }

  void _closePlayer() => setState(() => _playingMission = null);

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('CONFIRM LOGOUT',
            style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurface,
                letterSpacing: 1)),
        content: const Text('Are you sure you want to end your combat session?',
            style: TextStyle(
                fontFamily: 'Manrope', fontSize: 14, color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL',
                style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 1)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AppState>().logout();
              Navigator.of(context).pushReplacementNamed('/landing');
            },
            child: const Text('LOGOUT',
                style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // ── Fullscreen player overlay ───────────────────────────────────────────
    if (_playingMission != null) {
      return _VideoPlayerPage(
        mission: _playingMission!,
        onClose: _closePlayer,
        selectedLang: _selectedLang,
      );
    }

    final username = state.username ?? 'OPERATIVE';
    final missions = state.allMissions;
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(children: [
                      const Flexible(
                        child: Text('WELCOME BACK,',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 11,
                                letterSpacing: 3,
                                color: AppColors.outline),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const Spacer(),
                      if (state.successProbability != null)
                        _BattleReadinessBadge(state: state),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showLogoutDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            border: Border.all(color: AppColors.outline.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.logout, size: 12, color: AppColors.outline),
                            const SizedBox(width: 4),
                            const Text('LOGOUT',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 8,
                                    letterSpacing: 1.5,
                                    color: AppColors.outline,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(username,
                          style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              color: AppColors.onSurface)),
                    ),
                    const SizedBox(height: 24),

                    _StatsBar(state: state),
                    const SizedBox(height: 20),

                    // ── Search Bar + Paste URL ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        border: Border.all(color: AppColors.primaryContainer, width: 1.5),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: AppColors.onSurface,
                                fontSize: 13,
                                letterSpacing: 0.5),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              hintText: state.domainInterest != null
                                  ? 'Search or paste YouTube link...'
                                  : 'Search YouTube or paste a link...',
                              hintStyle: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: AppColors.outlineVariant,
                                  fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            onSubmitted: (_) => _searchMissions(),
                          ),
                        ),
                        // Paste button
                        GestureDetector(
                          onTap: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              _searchCtrl.text = data!.text!;
                              _searchMissions();
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 48,
                            color: AppColors.surfaceContainerHighest,
                            child: const Icon(Icons.content_paste,
                                color: AppColors.outline, size: 18),
                          ),
                        ),
                        // Search button
                        GestureDetector(
                          onTap: _searching ? null : _searchMissions,
                          child: Container(
                            width: 48,
                            height: 48,
                            color: AppColors.primary,
                            child: _searching
                                ? const Center(
                                    child: SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    ))
                                : const Icon(Icons.search,
                                    color: AppColors.onPrimary, size: 20),
                          ),
                        ),
                      ]),
                    ),

                    // ── Language Filter Chips ────────────────────────────────
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _languages.entries.map((e) {
                          final selected = _selectedLang == e.key;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedLang = e.key);
                              // Re-search with new language if there's a query
                              if (_searchCtrl.text.trim().isNotEmpty) {
                                _searchMissions();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withOpacity(0.15)
                                    : AppColors.surfaceContainerHigh,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.outlineVariant,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(e.value,
                                  style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontSize: 10,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.onSurfaceVariant)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section label
                    Row(children: [
                      const Text('⚡ COMBAT MISSIONS',
                          style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: AppColors.onSurface)),
                      const Spacer(),
                      if (state.missionsLoading)
                        const SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.primary),
                        )
                      else
                        Text('${missions.length} ACTIVE',
                            style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 9,
                                letterSpacing: 1.5,
                                color: AppColors.outline)),
                    ]),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Mission grid ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MissionCard(
                    mission: missions[i],
                    onTap: () => _openPlayer(missions[i]),
                  ),
                  childCount: missions.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 0.95 : 0.82,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// In-App Video Player Page
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _VideoPlayerPage extends StatefulWidget {
  final Mission mission;
  final VoidCallback onClose;
  final String selectedLang;
  const _VideoPlayerPage({
    required this.mission,
    required this.onClose,
    required this.selectedLang,
  });

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late YoutubePlayerController _ctrl;
  bool _fetchingTranscript = false;
  bool _transcriptDone = false;

  @override
  void initState() {
    super.initState();
    _ctrl = YoutubePlayerController(
      initialVideoId: widget.mission.videoId!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    );
    _ctrl.addListener(_onPlayerUpdate);
  }

  void _onPlayerUpdate() {
    // When video ends, fetch transcript + generate cards
    if (_ctrl.value.playerState == PlayerState.ended && !_fetchingTranscript) {
      _fetchTranscriptAndGenerateCards();
    }
  }

  Future<void> _fetchTranscriptAndGenerateCards() async {
    if (_fetchingTranscript || _transcriptDone) return;
    setState(() => _fetchingTranscript = true);

    final state = context.read<AppState>();
    try {
      final data = await state.fetchVideoContent(
        widget.mission.videoId!,
        language: widget.selectedLang,
      );
      if (data != null) {
        // Transcript saved in AppState; generate flashcards
        await state.generateCardsFromTranscript(
          transcriptText: state.lastVideoTranscript,
          domain: state.domainInterest,
        );
      }
    } catch (_) {}

    if (mounted) setState(() {
      _fetchingTranscript = false;
      _transcriptDone = true;
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onPlayerUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ctrl,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primary,
        onEnded: (_) => _fetchTranscriptAndGenerateCards(),
      ),
      builder: (ctx, player) => Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.mission.title,
                      style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // YouTube player
              player,

              // Status bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _transcriptDone
                          ? '✅ TRANSCRIPT SAVED — Flashcards generated in Arena!'
                          : _fetchingTranscript
                              ? '⏳ Saving transcript & generating flashcards...'
                              : 'Watch till the end to generate Arena flashcards',
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: _transcriptDone
                              ? const Color(0xFF4CAF50)
                              : AppColors.outline),
                    ),
                  ),
                ]),
              ),

              // "Go to Arena" button after transcript is done
              if (_transcriptDone)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () {
                      widget.onClose();
                      // Navigate to Arena tab (index 1)
                      DefaultTabController.maybeOf(context)?.animateTo(1);
                      // Use the AppShell tab switch
                      final shell = context
                          .findAncestorStateOfType<_DashboardScreenState>();
                      if (shell == null) {
                        // fallback: pop and navigate
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                      ),
                      child: const Center(
                        child: Text('⚔️  GO TO ARENA →',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Battle Readiness Badge ──────────────────────────────────────────────────
class _BattleReadinessBadge extends StatelessWidget {
  final AppState state;
  const _BattleReadinessBadge({required this.state});

  static const _rankColors = {
    'RADIANT': Color(0xFFFF6D8D),
    'DIAMOND': Color(0xFF81D4FA),
    'PLATINUM': Color(0xFF80CBC4),
    'GOLD': Color(0xFFFFD54F),
    'IRON': Color(0xFF73757D),
  };

  @override
  Widget build(BuildContext context) {
    final rank = state.battleReadinessRank;
    final color = _rankColors[rank] ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('${state.battleReadinessPercent} READY',
            style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 8,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

// ── Stats Bar ───────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final AppState state;
  const _StatsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceContainerHigh,
      child: Row(children: [
        Expanded(child: _Stat('${state.powerLevel}', 'POW LEVEL', AppColors.primary)),
        Container(width: 1, height: 40, color: AppColors.outlineVariant),
        Expanded(child: _Stat('${state.streak}', 'DAY STREAK', AppColors.onSurface)),
        Container(width: 1, height: 40, color: AppColors.outlineVariant),
        Expanded(
          child: _Stat('${(state.xpGained / 1000).toStringAsFixed(1)}k',
              'XP GAINED', AppColors.tertiary),
        ),
        if (state.successProbability != null) ...[
          Container(width: 1, height: 40, color: AppColors.outlineVariant),
          Expanded(
            child: _Stat(state.battleReadinessPercent, 'BATTLE READY',
                _rankToColor(state.battleReadinessRank)),
          ),
        ],
      ]),
    );
  }

  Color _rankToColor(String rank) {
    const c = {
      'RADIANT': Color(0xFFFF6D8D),
      'DIAMOND': Color(0xFF81D4FA),
      'PLATINUM': Color(0xFF80CBC4),
      'GOLD': Color(0xFFFFD54F),
      'IRON': Color(0xFF73757D),
    };
    return c[rank] ?? AppColors.primary;
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      FittedBox(
        child: Text(value,
            style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color)),
      ),
      Text(label,
          style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 7,
              letterSpacing: 1.5,
              color: AppColors.outline)),
    ]);
  }
}

// ── Mission Card ─────────────────────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;
  const _MissionCard({required this.mission, required this.onTap});

  static const _rankColors = {
    'RADIANT': Color(0xFFFF6D8D),
    'ELITE': Color(0xFF6A49FA),
    'DIAMOND': Color(0xFF81D4FA),
    'PLATINUM': Color(0xFF80CBC4),
    'GOLD': Color(0xFFFFD54F),
    'IRON': Color(0xFF73757D),
  };

  @override
  Widget build(BuildContext context) {
    final accentColor = _rankColors[mission.rank] ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          border: Border(left: BorderSide(color: accentColor, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          if (mission.thumbnail != null)
            Expanded(
              flex: 3,
              child: Stack(fit: StackFit.expand, children: [
                Image.network(
                  mission.thumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceContainerHighest,
                    child: const Icon(Icons.play_circle_outline,
                        color: AppColors.primary, size: 28),
                  ),
                ),
                // Play icon overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    color: AppColors.surface.withOpacity(0.8),
                    child: Text(mission.rank,
                        style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 7,
                            letterSpacing: 1.5,
                            color: accentColor,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: accentColor.withOpacity(0.12),
                  child: Text(mission.rank,
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 8,
                          letterSpacing: 1.5,
                          color: accentColor,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Text('${mission.cardCount}',
                    style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.outlineVariant)),
              ]),
            ),

          // Title & subtitle
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(mission.title,
                      style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          height: 1.2),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(mission.subtitle,
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9,
                        color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(children: [
              ClipRect(
                child: SizedBox(
                  height: 3,
                  child: Row(children: [
                    Flexible(
                      flex: (mission.progress * 100).toInt(),
                      child: Container(color: accentColor),
                    ),
                    Flexible(
                      flex: 100 - (mission.progress * 100).toInt(),
                      child: Container(color: AppColors.surfaceContainerHighest),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Flexible(
                  child: Text('${(mission.progress * 100).toInt()}%',
                      style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 9,
                          color: AppColors.onSurface),
                      overflow: TextOverflow.ellipsis),
                ),
                const Spacer(),
                Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      border: Border.all(color: accentColor, width: 1),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
