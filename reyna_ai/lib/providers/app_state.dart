// lib/providers/app_state.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class Mission {
  final String id;
  final String title;
  final String subtitle;
  final double progress;
  final String rank;
  final int cardCount;
  final String? videoId;
  final String? thumbnail;

  const Mission({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.rank,
    required this.cardCount,
    this.videoId,
    this.thumbnail,
  });
}

class FlashcardModel {
  final String id;
  final String question;
  final String answer;
  final String difficulty;
  final List<String>? options; // null = fill-in-blank, non-null = MCQ

  const FlashcardModel({
    required this.id,
    required this.question,
    required this.answer,
    required this.difficulty,
    this.options,
  });
}

class AppState extends ChangeNotifier {
  // ── Real Auth State ────────────────────────────────────────────────────────
  String? token;
  String? userId;
  String? username;
  String? domainInterest;
  bool get isLoggedIn => token != null;

  // ── Engagement / Rank ──────────────────────────────────────────────────────
  double engagementScore = 0.0;
  String engagementLevel = 'iron'; // iron, gold, radiant

  // ── ML Success Probability & Battle Readiness ──────────────────────────────
  double? successProbability;  // 0.0–1.0 from /tutor/predict
  String get battleReadinessPercent {
    // Before first video: everyone is IRON 0%
    if (!hasVideoPlayed) return '0%';
    if (successProbability == null) return '0%';
    return '${(successProbability! * 100).round()}%';
  }
  String get battleReadinessRank {
    if (!hasVideoPlayed) return 'IRON';
    if (successProbability == null) return 'IRON';
    if (successProbability! >= 0.8) return 'RADIANT';
    if (successProbability! >= 0.6) return 'DIAMOND';
    if (successProbability! >= 0.4) return 'PLATINUM';
    if (successProbability! >= 0.2) return 'GOLD';
    return 'IRON';
  }

  // ── Derived stats shown in dashboard stats bar ──────────────────────────────
  int get powerLevel => (engagementScore * 100).round();
  int get streak => studyPlan == null ? 0 : ((engagementScore * 20).round());
  int get xpGained => (engagementScore * 5000).round();
  Map<String, dynamic>? studyPlan;
  Map<String, dynamic>? reynaResponse;

  // ── Last video transcript (set by in-app player after fetch) ───────────────
  String lastVideoTranscript = '';
  String? lastVideoId;
  bool hasVideoPlayed = false;   // true the instant ANY video ends
  bool isGeneratingCards = false; // true while LLM generates video flashcards

  // ── Dynamic Missions (from live YouTube search) ──────────────────────────────
  List<Mission> dynamicMissions = [];
  bool missionsLoading = false;

  // ── Dynamic Flashcards (generated from transcript) ──────────────────────────
  List<FlashcardModel> dynamicFlashcards = [];
  bool flashcardsReady = false;  // true when new cards generated from video

  // ── Loading/Error flags ────────────────────────────────────────────────────
  bool isLoading = false;
  String? errorMessage;

  // ── Auth: Real login via backend ───────────────────────────────────────────
  Future<void> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final data = await ApiService.login(email, password);
      _setAuth(data);
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Auth: Real signup via backend ──────────────────────────────────────────
  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String ageBand,
    required String education,
    required String domain,
    String? gender,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final data = await ApiService.signup(
        name: name,
        email: email,
        password: password,
        ageBand: ageBand,
        education: education,
        domainInterest: domain,
        gender: gender,
      );
      _setAuth(data);

      // Trigger instant mission population after successful signup
      await loadDynamicMissions(domain);
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Dynamic Missions: load from YouTube search ─────────────────────────────
  Future<void> loadDynamicMissions(String query, {String language = 'en'}) async {
    if (token == null || token == 'mock_token') return;
    missionsLoading = true;
    notifyListeners();

    try {
      final results = await ApiService.searchVideos(token!, query,
          count: 6, language: language);
      final rankCycle = ['IRON', 'GOLD', 'PLATINUM', 'DIAMOND', 'ELITE', 'RADIANT'];
      dynamicMissions = results.asMap().entries.map((e) {
        final i = e.key;
        final v = e.value;
        final title = (v['title'] as String? ?? 'Mission ${i + 1}')
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .trim();
        return Mission(
          id: 'DM${i + 1}',
          title: title.length > 40 ? '${title.substring(0, 40)}...' : title,
          subtitle: query,
          progress: 0.0,
          rank: rankCycle[i % rankCycle.length],
          cardCount: (5 + (i * 3)).toInt(),
          videoId: v['video_id'] as String?,
          thumbnail: v['thumbnail'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[loadDynamicMissions] Failed: $e');
    } finally {
      missionsLoading = false;
      notifyListeners();
    }
  }

  // ── Fetch single video content (transcript) for the in-app player ──────────
  Future<Map<String, dynamic>?> fetchVideoContent(String videoId,
      {String language = 'en'}) async {
    // Mark video as played immediately — unlocks Arena & sets rank to IRON
    hasVideoPlayed = true;
    lastVideoId = videoId;
    notifyListeners();

    if (token == null || !isLoggedIn) return null;
    try {
      // Pass bare videoId — backend detects it as a direct ID and skips search
      final data = await ApiService.fetchContent(token!, videoId);
      final transcript = data['transcript_text'] as String? ?? '';
      if (transcript.isNotEmpty) {
        lastVideoTranscript = transcript;
        isGeneratingCards = true;
        notifyListeners();
        // Await card generation so arena gets real cards, not static fallback
        await generateCardsFromTranscript(
          transcriptText: transcript,
          domain: domainInterest,
        );
        isGeneratingCards = false;
        // Refresh study plan + rank after watching a video (non-blocking)
        Future.wait([
          loadStudyPlan(),
          loadSuccessProbability(),
          loadEngagementProfile(),
        ]);
      }
      notifyListeners();
      return data;
    } catch (e) {
      isGeneratingCards = false;
      debugPrint('[fetchVideoContent] Failed: $e');
      notifyListeners();
      return null;
    }
  }

  // ── Success Probability: load from ML model ────────────────────────────────
  Future<void> loadSuccessProbability() async {
    if (token == null || token == 'mock_token' || !isLoggedIn) return;
    try {
      final response = await ApiService.getSuccessProbability(token!);
      final prob = (response['success_probability'] as num?)?.toDouble();
      if (prob != null) {
        successProbability = prob;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[loadSuccessProbability] Failed: $e');
    }
  }

  // ── Generate Flashcards from transcript ───────────────────────────────────
  Future<void> generateCardsFromTranscript({
    required String transcriptText,
    String? domain,
  }) async {
    if (token == null || token == 'mock_token' || !isLoggedIn) return;
    if (transcriptText.isEmpty) return;

    try {
      final response = await ApiService.generateCards(
        token!,
        transcriptText: transcriptText,
        domain: domain ?? domainInterest ?? '',
      );
      final cards = response['flashcards'] as List?;
      if (cards != null && cards.isNotEmpty) {
        dynamicFlashcards = cards.asMap().entries.map((e) {
          final c = e.value as Map<String, dynamic>;
          return FlashcardModel(
            id: 'GC-${800 + e.key}',
            question: c['front'] as String? ?? '',
            answer: c['back'] as String? ?? '',
            difficulty: 'ELITE',
          );
        }).toList();
        flashcardsReady = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[generateCardsFromTranscript] Failed: $e');
    }
  }

  // ── Token persistence (shared_preferences) ───────────────────────────────
  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) await prefs.setString('token', token!);
    if (userId != null) await prefs.setString('userId', userId!);
    if (username != null) await prefs.setString('username', username!);
    if (domainInterest != null) await prefs.setString('domain', domainInterest!);
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getString('userId');
    username = prefs.getString('username');
    domainInterest = prefs.getString('domain');
    if (token != null) {
      notifyListeners();
      await Future.wait([
        loadEngagementProfile(),
        loadStudyPlan(),
        loadSuccessProbability(),
      ]);
      // Load domain missions on session restore
      if (domainInterest != null && domainInterest!.isNotEmpty) {
        loadDynamicMissions(domainInterest!);
      }
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _setAuth(Map<String, dynamic> data) {
    token = data['access_token'] as String?;
    userId = data['user_id']?.toString();
    username = (data['name'] as String?)?.toUpperCase() ?? 'OPERATIVE';
    domainInterest = data['domain_interest'] as String?;
    notifyListeners();
    saveSession(); // persist token immediately
  }

  // Keep mockLogin for offline testing
  void mockLogin(String name) {
    username = name.isEmpty ? 'OPERATIVE' : name.toUpperCase();
    token = 'mock_token';
    notifyListeners();
  }

  void logout() {
    token = null;
    userId = null;
    username = null;
    domainInterest = null;
    engagementScore = 0.0;
    studyPlan = null;
    reynaResponse = null;
    successProbability = null;
    dynamicMissions = [];
    dynamicFlashcards = [];
    lastVideoTranscript = '';
    lastVideoId = null;
    clearSession();
    notifyListeners();
  }

  // ── Tracker: Log event ─────────────────────────────────────────────────────
  Future<void> logEvent({
    String? contentId,
    String activityType = 'video',
    int sumClick = 1,
    double timeSpentSeconds = 0.0,
    String? eventType,
  }) async {
    // Only log events if user is properly authenticated with a real token
    if (token == null || token == 'mock_token' || !isLoggedIn) {
      debugPrint('[logEvent] Skipping - user not authenticated');
      return;
    }
    try {
      await ApiService.logEvent(
        token!,
        contentId: contentId,
        activityType: activityType,
        sumClick: sumClick,
        timeSpentSeconds: timeSpentSeconds,
        eventType: eventType,
        domain: domainInterest,
      );
    } catch (e) {
      debugPrint('[logEvent] Failed: $e');
      // Silently ignore heartbeat failures
    }
  }

  // ── Tutor: Load engagement profile + study plan ────────────────────────────
  Future<void> loadEngagementProfile() async {
    // Only load if user is properly authenticated with a real token
    if (token == null || token == 'mock_token' || !isLoggedIn) {
      debugPrint('[loadEngagementProfile] Skipping - user not authenticated');
      return;
    }
    try {
      final data = await ApiService.getEngagementProfile(token!);
      final features = data['features'] as Map<String, dynamic>? ?? {};
      engagementScore = (features['engagement_score'] as num?)?.toDouble() ?? 0.0;
      engagementLevel = _scoreToRank(engagementScore);
      notifyListeners();
    } catch (e) {
      debugPrint('[loadEngagementProfile] Failed: $e');
    }
  }

  Future<void> loadStudyPlan() async {
    // Only load if user is properly authenticated with a real token
    if (token == null || token == 'mock_token' || !isLoggedIn) {
      debugPrint('[loadStudyPlan] Skipping - user not authenticated');
      return;
    }
    try {
      studyPlan = await ApiService.getStudyPlan(token!);
      notifyListeners();
    } catch (e) {
      debugPrint('[loadStudyPlan] Failed: $e');
    }
  }

  Future<void> loadReynaResponse({String transcriptExcerpt = ''}) async {
    // Only load if user is properly authenticated with a real token
    if (token == null || token == 'mock_token' || !isLoggedIn) {
      debugPrint('[loadReynaResponse] Skipping - user not authenticated');
      return;
    }
    try {
      final data = await ApiService.getReynaResponse(
        token!,
        transcriptExcerpt: transcriptExcerpt,
      );
      reynaResponse = data['reyna'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (e) {
      debugPrint('[loadReynaResponse] Failed: $e');
    }
  }

  String _scoreToRank(double score) {
    if (score >= 0.66) return 'radiant';
    if (score >= 0.33) return 'gold';
    return 'iron';
  }

  // ── Missions: prefer dynamic, fall back to static ──────────────────────────
  List<Mission> get allMissions =>
      dynamicMissions.isNotEmpty ? dynamicMissions : _staticMissions;

  static const List<Mission> _staticMissions = [
    Mission(id: 'M01', title: 'Neural Language\nWarfare', subtitle: 'NLP & Transformers', progress: 0.65, rank: 'ELITE', cardCount: 42),
    Mission(id: 'M02', title: 'Quantum\nComputing Core', subtitle: 'Superposition & Entanglement', progress: 0.20, rank: 'RADIANT', cardCount: 28),
    Mission(id: 'M03', title: 'Vector Calculus\nBlitz', subtitle: 'Gradients & Divergence', progress: 0.90, rank: 'DIAMOND', cardCount: 36),
    Mission(id: 'M04', title: 'Data Structures\nProtocol', subtitle: 'Trees, Graphs & DP', progress: 0.45, rank: 'PLATINUM', cardCount: 55),
    Mission(id: 'M05', title: 'Cybersecurity\nOps', subtitle: 'Cryptography & Networks', progress: 0.10, rank: 'IRON', cardCount: 31),
    Mission(id: 'M06', title: 'Machine Learning\nDomain', subtitle: 'Loss Functions & Backprop', progress: 0.78, rank: 'ELITE', cardCount: 48),
  ];

  // Alias for backward compat with existing static references
  static List<Mission> get missions => _staticMissions;

  // ── Flashcards: prefer dynamic (from transcript), else from reynaResponse ───
  List<FlashcardModel> get flashcards {
    // 1. Freshly generated from a video transcript
    if (dynamicFlashcards.isNotEmpty) return dynamicFlashcards;
    // 2. Loaded from /tutor/reyna-response
    final cards = reynaResponse?['flashcards'] as List?;
    if (cards != null && cards.isNotEmpty) {
      return cards.asMap().entries.map((e) {
        final c = e.value as Map<String, dynamic>;
        return FlashcardModel(
          id: 'AX-${800 + e.key}',
          question: c['front'] as String? ?? '',
          answer: c['back'] as String? ?? '',
          difficulty: 'ELITE',
        );
      }).toList();
    }
    return _staticFlashcards;
  }

  static const List<FlashcardModel> _staticFlashcards = [
    FlashcardModel(id: 'AX-772', question: 'What is the Attention mechanism in Transformers?', answer: 'Attention(Q, K, V) = softmax(QKᵀ / √dₖ)V\n\nMaps queries and key-value pairs to an output via scaled dot-product attention.', difficulty: 'ELITE'),
    FlashcardModel(id: 'AX-773', question: 'Define Self-Attention.', answer: 'A mechanism that relates different positions of a single sequence to compute a representation. Each token attends to every other token simultaneously.', difficulty: 'RADIANT'),
    FlashcardModel(id: 'AX-774', question: 'What is the scaling factor √dₖ for?', answer: 'Without it, dot products grow large in magnitude, pushing softmax into vanishingly small gradient regions, causing training instability.', difficulty: 'DIAMOND'),
    FlashcardModel(id: 'AX-775', question: 'What is Positional Encoding?', answer: 'Sinusoidal or learned vectors added to input embeddings to inject token position information — needed because attention is permutation-invariant.', difficulty: 'ELITE'),
    FlashcardModel(id: 'AX-776', question: 'What is Layer Normalization?', answer: 'Stabilizes training by normalizing inputs across features (not the batch), reducing internal covariate shift.', difficulty: 'DIAMOND'),
  ];

  int _currentCardIndex = 0;
  int get currentCardIndex => _currentCardIndex;
  FlashcardModel get currentCard => flashcards[_currentCardIndex];
  int get remaining => flashcards.length - _currentCardIndex;
  bool get isDone => _currentCardIndex >= flashcards.length;

  void nextCard() {
    if (_currentCardIndex < flashcards.length) {
      _currentCardIndex++;
      notifyListeners();
    }
  }

  void resetCards() {
    _currentCardIndex = 0;
    flashcardsReady = false;
    dynamicFlashcards = [];
    notifyListeners();
  }
}
