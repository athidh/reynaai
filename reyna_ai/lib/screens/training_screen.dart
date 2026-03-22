// lib/screens/training_screen.dart
//
// Training Arena — Automated Flow with ML Integration
// - Search: Calls /scraper/fetch-content and caches transcript for flashcard generation.
// - Heartbeat: Pings /tracker/log-event every 30 seconds with sum_click: 5.
// - Video End: Stores transcript → triggers /tutor/generate-cards automatically.
// - Success Probability: ML prediction with IRON→RADIANT rank animation.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  final _queryCtrl = TextEditingController();
  YoutubePlayerController? _ytCtrl;
  String? _videoId;
  String? _errorMsg;
  bool _loading = false;
  bool _wasPlaying = false;

  // Heartbeat tracking
  Timer? _heartbeatTimer;
  int _heartbeatCount = 0;
  final Stopwatch _sessionWatch = Stopwatch();

  // Current transcript from fetch-content
  String _currentTranscript = '';

  // Success probability & rank animation
  double? _successProbability;
  String? _previousRank;
  bool _showLevelUpAnimation = false;
  late AnimationController _levelUpController;
  late Animation<double> _levelUpAnimation;

  @override
  void initState() {
    super.initState();
    _levelUpController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _levelUpAnimation = CurvedAnimation(
      parent: _levelUpController,
      curve: Curves.elasticOut,
    );

    // Load initial success probability
    _loadSuccessProbability();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _ytCtrl?.dispose();
    _queryCtrl.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  // ── Load success probability from ML model ────────────────────────────────
  Future<void> _loadSuccessProbability() async {
    final state = context.read<AppState>();
    if (state.token == null || state.token == 'mock_token') return;

    try {
      final response = await ApiService.getSuccessProbability(state.token!);
      final newProb = (response['success_probability'] as num?)?.toDouble();
      final features = response['features'] as Map<String, dynamic>?;

      if (newProb != null && mounted) {
        final oldProb = _successProbability;
        setState(() => _successProbability = newProb);

        if (oldProb != null && features != null) {
          final newRank = _probabilityToRank(newProb);
          final oldRank = _previousRank ?? _probabilityToRank(oldProb);

          if (_rankValue(newRank) > _rankValue(oldRank)) {
            _triggerLevelUpAnimation(newRank);
          }
          _previousRank = newRank;
        } else if (features != null) {
          _previousRank = _probabilityToRank(newProb);
        }
      }
    } catch (e) {
      debugPrint('[TrainingScreen] Failed to load success probability: $e');
    }
  }

  String _probabilityToRank(double prob) {
    if (prob >= 0.8) return 'RADIANT';
    if (prob >= 0.6) return 'DIAMOND';
    if (prob >= 0.4) return 'PLATINUM';
    if (prob >= 0.2) return 'GOLD';
    return 'IRON';
  }

  int _rankValue(String rank) {
    const ranks = {'IRON': 1, 'GOLD': 2, 'PLATINUM': 3, 'DIAMOND': 4, 'RADIANT': 5};
    return ranks[rank] ?? 0;
  }

  void _triggerLevelUpAnimation(String newRank) {
    setState(() => _showLevelUpAnimation = true);
    _levelUpController.forward(from: 0.0);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showLevelUpAnimation = false);
    });
  }

  // ── Load a video by ID or URL ─────────────────────────────────────────────
  void _loadVideo(String input) {
    final id = YoutubePlayer.convertUrlToId(input) ?? input.trim();
    if (id.isEmpty) {
      setState(() => _errorMsg = 'Invalid YouTube URL or video ID.');
      return;
    }
    _initPlayer(id);
  }

  void _initPlayer(String id) {
    _ytCtrl?.dispose();
    _stopHeartbeat();

    setState(() {
      _videoId = id;
      _errorMsg = null;
      _ytCtrl = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      )..addListener(_onPlayerStateChange);
      _sessionWatch.reset();
      _sessionWatch.start();
      _heartbeatCount = 0;
    });

    _startHeartbeat();
  }

  void _onPlayerStateChange() {
    final c = _ytCtrl;
    if (c == null) return;

    final isPlaying = c.value.isPlaying;
    final hasEnded = c.value.position >= c.metadata.duration;

    if (hasEnded && !_wasPlaying) {
      _onVideoEnded();
    }

    if (_wasPlaying && !isPlaying && !hasEnded) {
      _logPauseEvent();
    }

    _wasPlaying = isPlaying;
  }

  // ── Heartbeat: Send event every 30 seconds ───────────────────────────────
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_ytCtrl?.value.isPlaying == true) {
        _sendHeartbeat();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    _heartbeatCount++;
    final state = context.read<AppState>();
    debugPrint('[Heartbeat] Sending ping #$_heartbeatCount (sum_click: 5)');
    await state.logEvent(
      contentId: _videoId,
      activityType: 'video',
      sumClick: 5,
      timeSpentSeconds: 30.0,
      eventType: 'heartbeat',
    );
  }

  Future<void> _logPauseEvent() async {
    _sessionWatch.stop();
    final secs = _sessionWatch.elapsed.inSeconds.toDouble();
    _sessionWatch.reset();
    final state = context.read<AppState>();
    await state.logEvent(
      contentId: _videoId,
      activityType: 'video',
      eventType: 'pause',
      timeSpentSeconds: secs,
      sumClick: 1,
    );
  }

  // ── Mission Update: Called when video ends ───────────────────────────────
  Future<void> _onVideoEnded() async {
    debugPrint('[TrainingScreen] Video ended - generating flashcards');
    _stopHeartbeat();
    _sessionWatch.stop();

    final state = context.read<AppState>();

    // Log completion event
    await state.logEvent(
      contentId: _videoId,
      activityType: 'video',
      eventType: 'complete',
      timeSpentSeconds: _sessionWatch.elapsed.inSeconds.toDouble(),
      sumClick: 1,
    );

    // Auto-generate flashcards from transcript (non-blocking)
    if (_currentTranscript.isNotEmpty) {
      state.generateCardsFromTranscript(
        transcriptText: _currentTranscript,
        domain: state.domainInterest,
      );
    }

    // Reload study plan and success probability
    await Future.wait([
      state.loadStudyPlan(),
      _loadSuccessProbability(),
    ]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ Mission Complete! Flashcards generating in Arena...',
            style: TextStyle(fontFamily: 'Space Grotesk'),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Fetch video from backend scraper ─────────────────────────────────────
  Future<void> _searchVideo() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final state = context.read<AppState>();
      final token = state.token;

      if (token != null && token != 'mock_token') {
        debugPrint('[TrainingScreen] Fetching content for: $q');
        final data = await ApiService.fetchContent(token, q);

        final videoId = data['video_id'] as String?;
        final url = data['url'] as String?;
        final error = data['error'] as String?;
        final transcript = data['transcript_text'] as String? ?? '';

        // Store transcript for card generation & chat context
        _currentTranscript = transcript;
        state.lastVideoTranscript = transcript;
        state.lastVideoId = videoId;

        if (error != null && error.isNotEmpty) {
          setState(() => _errorMsg = error);
        } else if (videoId != null && videoId.isNotEmpty) {
          _loadVideo(videoId);
        } else if (url != null) {
          _loadVideo(url);
        } else {
          _loadVideo(q);
        }
      } else {
        // Offline mode: treat as direct URL/ID
        _loadVideo(q);
      }
    } catch (e) {
      debugPrint('[TrainingScreen] Search failed: $e');
      _loadVideo(_queryCtrl.text.trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(width: 4, height: 52, color: AppColors.primary),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TRAINING ARENA',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    color: AppColors.onSurface)),
                            Text('NEURAL VIDEO IMMERSION',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 8,
                                    letterSpacing: 2,
                                    color: AppColors.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Success Probability Display ──────────────────────────────
                if (_successProbability != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SuccessProbabilityBar(
                      probability: _successProbability!,
                      rank: _previousRank ?? _probabilityToRank(_successProbability!),
                    ),
                  ),

                if (_successProbability != null) const SizedBox(height: 12),

                // ── Search bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      border: Border.all(
                          color: AppColors.primaryContainer, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _queryCtrl,
                            style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: AppColors.onSurface,
                                fontSize: 13,
                                letterSpacing: 0.5),
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              hintText: 'Enter topic or paste YouTube URL...',
                              hintStyle: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: AppColors.outlineVariant,
                                  fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: (_) => _searchVideo(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _loading ? null : _searchVideo,
                          child: Container(
                            width: 50,
                            height: 50,
                            color: AppColors.primary,
                            child: _loading
                                ? const Center(
                                    child: SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    ))
                                : const Icon(Icons.bolt,
                                    color: AppColors.onPrimary, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 11,
                            color: AppColors.error)),
                  ),

                const SizedBox(height: 16),

                // ── Player or empty state ─────────────────────────────────────
                Expanded(
                  child: _ytCtrl == null
                      ? _EmptyState()
                      : Column(
                          children: [
                            YoutubePlayerBuilder(
                              player: YoutubePlayer(
                                controller: _ytCtrl!,
                                showVideoProgressIndicator: true,
                                progressIndicatorColor: AppColors.primary,
                                progressColors: const ProgressBarColors(
                                  playedColor: AppColors.primary,
                                  handleColor: AppColors.primary,
                                  bufferedColor: AppColors.primaryContainer,
                                  backgroundColor:
                                      AppColors.surfaceContainerHighest,
                                ),
                              ),
                              builder: (ctx, player) => player,
                            ),

                            const SizedBox(height: 16),

                            _EventBar(
                              videoId: _videoId ?? '',
                              heartbeatCount: _heartbeatCount,
                              hasTranscript: _currentTranscript.isNotEmpty,
                            ),
                          ],
                        ),
                ),
              ],
            ),

            // ── Level Up Animation Overlay ────────────────────────────────
            if (_showLevelUpAnimation)
              _LevelUpOverlay(
                animation: _levelUpAnimation,
                rank: _previousRank ?? 'RADIANT',
              ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state placeholder ────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryContainer, width: 2),
            ),
            child: const Icon(Icons.play_arrow_outlined,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('AWAITING TARGET',
              style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 12,
                  letterSpacing: 3,
                  color: AppColors.outline)),
          const SizedBox(height: 6),
          const Text('Enter a topic or paste YouTube URL above',
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: AppColors.outlineVariant)),
        ],
      ),
    );
  }
}

// ── Success Probability Bar ───────────────────────────────────────────────────
class _SuccessProbabilityBar extends StatelessWidget {
  final double probability;
  final String rank;

  const _SuccessProbabilityBar({
    required this.probability,
    required this.rank,
  });

  Color get _barColor {
    if (probability >= 0.7) return const Color(0xFF4CAF50);
    if (probability >= 0.4) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  Color get _rankColor {
    const rankColors = {
      'RADIANT': Color(0xFFFF6D8D),
      'DIAMOND': Color(0xFF81D4FA),
      'PLATINUM': Color(0xFF80CBC4),
      'GOLD': Color(0xFFFFD54F),
      'IRON': Color(0xFF73757D),
    };
    return rankColors[rank] ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (probability * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        border: Border(left: BorderSide(color: _barColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('BATTLE READINESS',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 8,
                    letterSpacing: 2,
                    color: AppColors.outline,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: _rankColor.withOpacity(0.12),
                child: Text(rank,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 8,
                      letterSpacing: 1.5,
                      color: _rankColor,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage% Chance of Promotion',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _barColor,
            ),
          ),
          const SizedBox(height: 8),
          ClipRect(
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Flexible(
                    flex: percentage,
                    child: Container(color: _barColor),
                  ),
                  Flexible(
                    flex: 100 - percentage,
                    child: Container(color: AppColors.surfaceContainerHighest),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Event log strip ────────────────────────────────────────────────────────────
class _EventBar extends StatelessWidget {
  final String videoId;
  final int heartbeatCount;
  final bool hasTranscript;

  const _EventBar({
    required this.videoId,
    required this.heartbeatCount,
    this.hasTranscript = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          border: Border(
            left: BorderSide(color: AppColors.primary, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('ENGAGEMENT TRACKER',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 8,
                      letterSpacing: 2,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    )),
                const Spacer(),
                if (hasTranscript)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    color: AppColors.primary.withOpacity(0.1),
                    child: const Text('TRANSCRIPT READY',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 7,
                          letterSpacing: 1,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'VIDEO ID: ${videoId.isEmpty ? '—' : videoId}',
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Heartbeats sent: $heartbeatCount (every 30s, sum_click: 5)',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                color: AppColors.outlineVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Events auto-logged to Reyna for ML analysis. Flashcards generated on video end.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                color: AppColors.outlineVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Level Up Animation Overlay ─────────────────────────────────────────────────
class _LevelUpOverlay extends StatelessWidget {
  final Animation<double> animation;
  final String rank;

  const _LevelUpOverlay({
    required this.animation,
    required this.rank,
  });

  Color get _rankColor {
    const rankColors = {
      'RADIANT': Color(0xFFFF6D8D),
      'DIAMOND': Color(0xFF81D4FA),
      'PLATINUM': Color(0xFF80CBC4),
      'GOLD': Color(0xFFFFD54F),
      'IRON': Color(0xFF73757D),
    };
    return rankColors[rank] ?? const Color(0xFFC428FF);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.7 * animation.value),
          child: Center(
            child: Transform.scale(
              scale: animation.value,
              child: Opacity(
                opacity: animation.value,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    border: Border.all(color: _rankColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _rankColor.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward_rounded, color: _rankColor, size: 48),
                      const SizedBox(height: 16),
                      const Text('RANK UP!',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: AppColors.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Text(rank,
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: _rankColor,
                          )),
                      const SizedBox(height: 16),
                      const Text('Your performance is improving!',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
