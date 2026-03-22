// lib/services/api_service.dart
//
// Central API client for the Reyna AI backend.
// All endpoints map 1:1 to the FastAPI routes in backend/app/api/.

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Base URL — change to deployed URL in production ─────────────────────────
  static const String baseUrl = 'https://reyna-ai-c0d7a6cmh7dugbh6.centralindia-01.azurewebsites.net';

  // ── Shared timeout for all requests ─────────────────────────────────────────
  static const _timeout    = Duration(seconds: 15);
  // Extended timeout for LLM/NIM calls (card generation, chat) — Llama takes 15–25s
  static const _llmTimeout = Duration(seconds: 60);

  // ── Internal helpers ─────────────────────────────────────────────────────────
  static Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
      };

  // Timeout-wrapped GET
  static Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) =>
      http.get(uri, headers: headers).timeout(_timeout);

  // Timeout-wrapped POST (standard)
  static Future<http.Response> _post(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      http.post(uri, headers: headers, body: body).timeout(_timeout);

  // Timeout-wrapped POST for LLM calls (longer)
  static Future<http.Response> _postLLM(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      http.post(uri, headers: headers, body: body).timeout(_llmTimeout);

  static Map<String, dynamic> _decode(http.Response r) {
    final body = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw Exception((body as Map)['detail'] ?? 'Request failed (${r.statusCode})');
  }

  static List<Map<String, dynamic>> _decodeList(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final body = jsonDecode(r.body) as List;
      return body.cast<Map<String, dynamic>>();
    }
    final err = jsonDecode(r.body);
    throw Exception((err as Map)['detail'] ?? 'Request failed (${r.statusCode})');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH  (/auth/*)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Register a new user. Returns { access_token, user_id, name, domain_interest }
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String ageBand,
    required String education,
    required String domainInterest,
    String? gender,
  }) async {
    final r = await _post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'age_band': ageBand,
        'education': education,
        'domain_interest': domainInterest,
        'gender': gender ?? 'M',
        'disability': 'N',
      }),
    );
    return _decode(r);
  }

  /// Login with email + password (form-encoded as required by OAuth2PasswordRequestForm).
  /// Returns { access_token, user_id, name, domain_interest }
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final r = await _post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );
    return _decode(r);
  }

  /// Get current user's profile.
  static Future<Map<String, dynamic>> getMe(String token) async {
    final r = await _get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _authHeaders(token),
    );
    return _decode(r);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTENT  (/scraper/*)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Search YouTube for [query] and return cleaned transcript + video metadata.
  /// Returns { video_id, url, transcript_text, word_count, error }
  static Future<Map<String, dynamic>> fetchContent(
      String token, String query) async {
    final r = await _get(
      Uri.parse('$baseUrl/scraper/fetch-content?query=${Uri.encodeComponent(query)}'),
      headers: _authHeaders(token),
    );
    return _decode(r);
  }

  /// Search YouTube for [query] and return a list of video results for the dashboard grid.
  /// Returns List<{ video_id, title, url, thumbnail, duration }>
  static Future<List<Map<String, dynamic>>> searchVideos(
      String token, String query, {int count = 6, String language = 'en'}) async {
    final r = await _get(
      Uri.parse(
          '$baseUrl/scraper/search-videos?query=${Uri.encodeComponent(query)}&count=$count&language=${Uri.encodeComponent(language)}'),
      headers: _authHeaders(token),
    );
    return _decodeList(r);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRACKER  (/tracker/*)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Log a heartbeat event from the YouTube player.
  /// Call this every time the user pauses, seeks, or completes a video.
  ///
  /// [eventType] — "pause" | "seek" | "complete" | "open" | "heartbeat"
  /// [activityType] — "video" | "flashcard" | "quiz"
  static Future<Map<String, dynamic>> logEvent(
    String token, {
    String? contentId,
    String activityType = 'video',
    int sumClick = 1,
    double timeSpentSeconds = 0.0,
    String? eventType,
    String? domain,
  }) async {
    final r = await _post(
      Uri.parse('$baseUrl/tracker/log-event'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'content_id': contentId,
        'activity_type': activityType,
        'sum_click': sumClick,
        'time_spent_seconds': timeSpentSeconds,
        'event_type': eventType,
        'domain': domain,
      }),
    );
    return _decode(r);
  }

  /// Fetch recent engagement events for the current user.
  static Future<List<Map<String, dynamic>>> getEventHistory(
      String token, {int limit = 100}) async {
    final r = await _get(
      Uri.parse('$baseUrl/tracker/history?limit=$limit'),
      headers: _authHeaders(token),
    );
    return _decodeList(r);
  }

  /// Log flashcard session performance (avg recognition time + correct answers).
  /// Returns { combat_proficiency, avg_recognition_time, event_id }
  static Future<Map<String, dynamic>> logFlashcardStats(
    String token, {
    required double avgRecognitionTime,
    required int correctAnswers,
    required int totalCards,
    String? domain,
    String? contentId,
  }) async {
    final r = await _post(
      Uri.parse('$baseUrl/tracker/flashcard-stats'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'avg_recognition_time': avgRecognitionTime,
        'correct_answers': correctAnswers,
        'total_cards': totalCards,
        'domain': domain,
        'content_id': contentId,
      }),
    );
    return _decode(r);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TUTOR  (/tutor/*)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the student's OULAD engagement profile (8 features + score + rank).
  /// Returns { user_id, features: { total_interactions, days_active, ... } }
  static Future<Map<String, dynamic>> getEngagementProfile(
      String token) async {
    final r = await _get(
      Uri.parse('$baseUrl/tutor/profile'),
      headers: _authHeaders(token),
    );
    return _decode(r);
  }

  /// Get ML success probability prediction.
  /// Returns { user_id, success_probability, features, demographics, model_available }
  static Future<Map<String, dynamic>> getSuccessProbability(
      String token) async {
    final r = await _get(
      Uri.parse('$baseUrl/tutor/predict'),
      headers: _authHeaders(token),
    );
    return _decode(r);
  }

  /// Get the 7-day study plan generated by the real OULAD model.
  /// Returns { user_id, daily_minutes, days: [{day, focus, tasks, tip}], success_probability }
  static Future<Map<String, dynamic>> getStudyPlan(String token) async {
    final r = await _get(
      Uri.parse('$baseUrl/tutor/study-plan'),
      headers: _authHeaders(token),
    );
    return _decode(r);
  }

  /// Get Reyna's Socratic dialogue + flashcards via Llama 3 / NVIDIA NIM.
  /// Returns { reyna: { greeting, socratic_question, flashcards, motivation } }
  static Future<Map<String, dynamic>> getReynaResponse(
    String token, {
    String transcriptExcerpt = '',
    String provider = 'nim',
  }) async {
    final r = await _post(
      Uri.parse('$baseUrl/tutor/reyna-response'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'transcript_excerpt': transcriptExcerpt,
        'provider': provider,
      }),
    );
    return _decode(r);
  }

  /// Generate 5 Socratic flashcards from a video transcript using Llama 3.
  /// Returns { flashcards, greeting, socratic_question, motivation, combat_status }
  static Future<Map<String, dynamic>> generateCards(
    String token, {
    required String transcriptText,
    String domain = '',
    String provider = 'nim',
  }) async {
    final r = await _postLLM(   // 60s timeout for LLM
      Uri.parse('$baseUrl/tutor/generate-cards'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'transcript_text': transcriptText,
        'domain': domain,
        'provider': provider,
      }),
    );
    return _decode(r);
  }

  /// Real-time chat with Reyna using transcript + domain for Socratic context.
  /// Returns { reply, combat_status }
  static Future<Map<String, dynamic>> chatWithReyna(
    String token, {
    required String message,
    String transcriptContext = '',
    String domain = '',
    List<Map<String, String>> history = const [],
  }) async {
    final r = await _postLLM(   // 60s timeout for LLM
      Uri.parse('$baseUrl/tutor/chat'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'message': message,
        'transcript_context': transcriptContext,
        'domain': domain,
        'history': history,
      }),
    );
    return _decode(r);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEALTH
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> isBackendAlive() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
