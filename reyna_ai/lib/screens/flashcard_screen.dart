// lib/screens/flashcard_screen.dart
//
// Arena — Fill-in-the-blank flashcard system.
// Cards are sourced from the last watched video (via generateCardsFromTranscript).
// If no transcript exists yet, shows a locked empty state.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final _answerCtrl = TextEditingController();
  final _focusNode  = FocusNode();

  bool _showAnswer   = false;
  bool _answered     = false;
  bool _fetchingCards = false;
  String _feedback   = '';
  String? _selectedOption;
  List<FlashcardModel> _mixedDeck = [];
  // Track the identity of the last source list so we can detect changes
  int _lastKnownCardCount = -1;

  final Stopwatch _cardStopwatch = Stopwatch();
  double _totalRecognitionTime = 0.0;
  int _cardsAnswered = 0;
  int _correctCount  = 0;

  @override
  void initState() {
    super.initState();
    _cardStopwatch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCardsIfNeeded();
    });
  }

  // ── Sync _mixedDeck whenever AppState.dynamicFlashcards changes ──────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Actual rebuild happens in build() failsafe via post-frame callback
    // This just ensures we pick up changes even if build() hasn't run yet
    final count = context.read<AppState>().dynamicFlashcards.length;
    if (count > 0 && count != _lastKnownCardCount) {
      _lastKnownCardCount = -1; // force the build() failsafe to catch it
    }
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Build mixed MCQ + fill-in-blank deck ──────────────────────────────────
  List<FlashcardModel> _buildMixedDeck(List<FlashcardModel> source) {
    if (source.length < 3) return source;
    // Collect short answers (≤4 words) as MCQ distractor pool
    final pool = source
        .map((c) => c.answer.split(RegExp(r'[\n.;]')).first.trim())
        .where((a) => a.split(' ').length <= 6)
        .toList();

    return source.asMap().entries.map((entry) {
      final i = entry.key;
      final card = entry.value;
      // Make every 2nd card an MCQ
      if (i % 2 == 0 && pool.length >= 3) {
        final correct = card.answer.split(RegExp(r'[\n.;]')).first.trim();
        // Pick 3 distractors that aren't the correct answer
        final distractors = pool
            .where((a) => a != correct)
            .toList()
          ..shuffle();
        final opts = ([correct, ...distractors.take(3)])..shuffle();
        return FlashcardModel(
          id: card.id,
          question: card.question,
          answer: correct,
          difficulty: card.difficulty,
          options: opts,
        );
      }
      return card;
    }).toList();
  }

  Future<void> _loadCardsIfNeeded() async {
    final state = context.read<AppState>();
    if (state.dynamicFlashcards.isNotEmpty) {
      setState(() => _mixedDeck = _buildMixedDeck(state.dynamicFlashcards));
      return;
    }
    if (state.token == null || state.token == 'mock_token') return;
    if (state.lastVideoTranscript.isNotEmpty) {
      setState(() => _fetchingCards = true);
      await state.generateCardsFromTranscript(
        transcriptText: state.lastVideoTranscript,
        domain: state.domainInterest,
      );
      if (mounted) {
        setState(() {
          _fetchingCards = false;
          _mixedDeck = _buildMixedDeck(state.dynamicFlashcards);
        });
      }
    }
  }

  Future<void> _forceRefresh() async {
    final state = context.read<AppState>();
    if (state.lastVideoTranscript.isEmpty) return;
    setState(() => _fetchingCards = true);
    state.resetCards();
    await state.generateCardsFromTranscript(
      transcriptText: state.lastVideoTranscript,
      domain: state.domainInterest,
    );
    if (mounted) {
      setState(() {
        _fetchingCards = false;
        _mixedDeck = _buildMixedDeck(state.dynamicFlashcards);
      });
    }
  }

  // ── Submit answer (works for both MCQ and fill-in-blank) ────────────────────
  void _submitAnswer(AppState state) {
    if (_answered) return;
    final card = _currentCard(state);
    final correctAnswer = card.answer.toLowerCase().trim();
    bool correct;
    String feedback;

    if (card.options != null) {
      // MCQ: check selected option
      if (_selectedOption == null) {
        setState(() => _feedback = '❓ Select an option first.');
        return;
      }
      correct = _selectedOption!.toLowerCase().trim() == correctAnswer;
      feedback = correct ? '✅ CORRECT!' : '❌ INCORRECT — see the right answer.';
    } else {
      // Fill-in-blank: keyword match
      final userAnswer = _answerCtrl.text.trim().toLowerCase();
      final keyWords = correctAnswer
          .split(RegExp(r'[\s,.\n]+'))
          .where((w) => w.length > 4)
          .toSet();
      final matched = keyWords.where((w) => userAnswer.contains(w)).length;
      final score = keyWords.isEmpty ? 0.0 : matched / keyWords.length;
      if (score >= 0.6) {
        feedback = '✅ CORRECT! Great recall.';
        correct = true;
      } else if (score >= 0.25) {
        feedback = '⚡ PARTIAL — you got some key concepts.';
        correct = false;
      } else if (userAnswer.isEmpty) {
        feedback = '❓ No answer — tap REVEAL for the answer.';
        correct = false;
      } else {
        feedback = '❌ INCORRECT — review the answer.';
        correct = false;
      }
    }

    final elapsed = _cardStopwatch.elapsedMilliseconds / 1000.0;
    _totalRecognitionTime += elapsed;
    _cardsAnswered++;
    if (correct) _correctCount++;

    setState(() {
      _answered   = true;
      _showAnswer = true;
      _feedback   = feedback;
    });
  }

  // ── Move to next card ──────────────────────────────────────────────────────
  void _nextCard(AppState state) {
    _cardStopwatch.reset();
    _cardStopwatch.start();
    _answerCtrl.clear();
    _focusNode.unfocus();
    setState(() {
      _answered       = false;
      _showAnswer     = false;
      _feedback       = '';
      _selectedOption = null;
    });
    state.nextCard();
  }

  // Get card from mixed deck (falls back to state.currentCard)
  FlashcardModel _currentCard(AppState state) {
    final idx = state.currentCardIndex;
    if (_mixedDeck.isNotEmpty && idx < _mixedDeck.length) {
      return _mixedDeck[idx];
    }
    return state.currentCard;
  }


  // ── Post stats to backend ──────────────────────────────────────────────────
  Future<void> _postStats() async {
    final state = context.read<AppState>();
    if (state.token == null || state.token == 'mock_token') return;
    if (_cardsAnswered == 0) return;
    final avg = _totalRecognitionTime / _cardsAnswered;
    try {
      await ApiService.logFlashcardStats(
        state.token!,
        avgRecognitionTime: avg,
        correctAnswers: _correctCount,
        totalCards: _cardsAnswered,
        domain: state.domainInterest,
        contentId: state.lastVideoId,
      );
    } catch (_) {}
  }

  double get _combatProficiency =>
      _cardsAnswered > 0 ? _correctCount / _cardsAnswered : 0.0;

  double get _avgRecognitionTime =>
      _cardsAnswered > 0 ? _totalRecognitionTime / _cardsAnswered : 0.0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // ── Failsafe: sync _mixedDeck if dynamicFlashcards populated but deck is stale ──
    final dynamic = state.dynamicFlashcards;
    if (dynamic.isNotEmpty && dynamic.length != _lastKnownCardCount) {
      _lastKnownCardCount = dynamic.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        state.resetCards();
        setState(() => _mixedDeck = _buildMixedDeck(dynamic));
      });
    }

    // ── Empty state ──────────────────────────────────────────────────────────
    if (!state.hasVideoPlayed) {
      return _LockedState();
    }

    // ── Loading state (generating cards from transcript) ──────────────────────
    if (_fetchingCards || (state.isGeneratingCards && state.dynamicFlashcards.isEmpty)) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ),
            const SizedBox(height: 20),
            const Text('GENERATING ARENA CARDS…',
                style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: AppColors.outline)),
            const SizedBox(height: 8),
            const Text('Reyna is synthesizing Socratic questions from your video.',
                style: TextStyle(
                    fontFamily: 'Manrope', fontSize: 12,
                    color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    // ── Session complete ──────────────────────────────────────────────────────
    if (state.isDone) {
      _postStats();
      return _SessionComplete(
        onReset: () {
          state.resetCards();
          setState(() {
            _totalRecognitionTime = 0;
            _cardsAnswered = 0;
            _correctCount  = 0;
            _answered      = false;
            _showAnswer    = false;
            _feedback      = '';
          });
          _cardStopwatch.reset();
          _cardStopwatch.start();
        },
        correctCount: _correctCount,
        totalAnswered: _cardsAnswered,
        avgTime: _avgRecognitionTime,
        combatProficiency: _combatProficiency,
      );
    }

    final card  = _currentCard(state);
    final total = _mixedDeck.isNotEmpty ? _mixedDeck.length : state.flashcards.length;
    final done  = total - state.remaining;
    final progress = total > 0 ? done / total : 0.0;
    final isMCQ = card.options != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => _focusNode.unfocus(),
          child: Column(children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('FLASHCARD\nARENA',
                          style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1.0,
                              color: AppColors.onSurface)),
                      if (state.dynamicFlashcards.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Text('FROM YOUR VIDEO',
                              style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 7,
                                  letterSpacing: 1.5,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ),
                  // remaining counter
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    RichText(text: TextSpan(
                      style: const TextStyle(fontFamily: 'Space Grotesk',
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: AppColors.primary),
                      children: [
                        TextSpan(text: '${state.remaining}'),
                        TextSpan(text: '/$total', style: const TextStyle(
                            fontSize: 14, color: AppColors.outline)),
                      ],
                    )),
                    const Text('REMAINING', style: TextStyle(
                        fontFamily: 'Space Grotesk', fontSize: 8,
                        letterSpacing: 2, color: AppColors.outline)),
                  ]),
                  const SizedBox(width: 10),
                  // refresh button
                  GestureDetector(
                    onTap: _fetchingCards ? null : _forceRefresh,
                    child: Container(
                      width: 36, height: 36,
                      color: AppColors.surfaceContainerHigh,
                      child: _fetchingCards
                          ? const Center(child: SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: AppColors.primary)))
                          : const Icon(Icons.refresh,
                              color: AppColors.primary, size: 18),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _HudBar(progress: progress),
              ]),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [

                  // ── Question card ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest.withOpacity(0.35),
                      border: Border.all(color: AppColors.primaryContainer, width: 1.5),
                      boxShadow: [BoxShadow(
                        color: AppColors.primary.withOpacity(0.08), blurRadius: 30)],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(card.id,
                            style: const TextStyle(
                                fontFamily: 'Space Grotesk', fontSize: 9,
                                letterSpacing: 2, color: AppColors.outlineVariant)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: AppColors.primary.withOpacity(0.12),
                          child: Text(card.difficulty,
                              style: const TextStyle(
                                  fontFamily: 'Space Grotesk', fontSize: 7,
                                  letterSpacing: 1.5, color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      const Text('QUESTION',
                          style: TextStyle(
                              fontFamily: 'Space Grotesk', fontSize: 8,
                              letterSpacing: 2, color: AppColors.outline)),
                      const SizedBox(height: 8),
                      Text(card.question,
                          style: const TextStyle(
                              fontFamily: 'Manrope', fontSize: 15,
                              height: 1.5, color: AppColors.onSurface)),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Fill-in-the-blank input ───────────────────────────────
                  // ── Answer area: MCQ buttons OR text input ──────────────
                  if (isMCQ)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('CHOOSE AN ANSWER',
                              style: TextStyle(
                                  fontFamily: 'Space Grotesk', fontSize: 8,
                                  letterSpacing: 2, color: AppColors.outline)),
                        ),
                        ...card.options!.asMap().entries.map((e) {
                          final idx   = e.key;
                          final opt   = e.value;
                          final label = String.fromCharCode(65 + idx); // A B C D
                          final isSelected = _selectedOption == opt;
                          final isCorrect  = _answered && opt.toLowerCase().trim() == card.answer.toLowerCase().trim();
                          final isWrong    = _answered && isSelected && !isCorrect;

                          Color bg = AppColors.surfaceContainerHigh;
                          Color border = AppColors.primaryContainer;
                          Color fg = AppColors.onSurface;
                          if (isCorrect && _answered) {
                            bg = const Color(0xFF4CAF50).withOpacity(0.1);
                            border = const Color(0xFF4CAF50);
                            fg = const Color(0xFF4CAF50);
                          } else if (isWrong) {
                            bg = AppColors.error.withOpacity(0.1);
                            border = AppColors.error;
                            fg = AppColors.error;
                          } else if (isSelected) {
                            bg = AppColors.primary.withOpacity(0.1);
                            border = AppColors.primary;
                            fg = AppColors.primary;
                          }

                          return GestureDetector(
                            onTap: _answered ? null : () {
                              setState(() => _selectedOption = opt);
                              // Auto-submit on tap
                              Future.microtask(() => _submitAnswer(state));
                            },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: bg,
                                border: Border.all(color: border, width: 1.5),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 24, height: 24,
                                  color: border.withOpacity(0.15),
                                  child: Center(child: Text(label,
                                      style: TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontSize: 11, fontWeight: FontWeight.w900,
                                          color: fg))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(opt,
                                    style: TextStyle(
                                        fontFamily: 'Manrope', fontSize: 13,
                                        height: 1.4, color: fg))),
                              ]),
                            ),
                          );
                        }),
                      ],
                    )
                  else
                    Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      border: Border.all(
                        color: _answered
                            ? (_feedback.startsWith('✅')
                                ? const Color(0xFF4CAF50)
                                : _feedback.startsWith('⚡')
                                    ? const Color(0xFFFFC107)
                                    : AppColors.error)
                            : AppColors.primaryContainer,
                        width: 1.5,
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: const Text('YOUR ANSWER',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk', fontSize: 8,
                                letterSpacing: 2, color: AppColors.outline)),
                      ),
                      TextField(
                        controller: _answerCtrl,
                        focusNode: _focusNode,
                        enabled: !_answered,
                        maxLines: 4,
                        minLines: 3,
                        style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: AppColors.onSurface,
                            height: 1.5),
                        cursorColor: AppColors.primary,
                        decoration: const InputDecoration(
                          hintText: 'Type your answer here…',
                          hintStyle: TextStyle(
                              fontFamily: 'Manrope',
                              color: AppColors.outlineVariant,
                              fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: (_) => _submitAnswer(state),
                      ),
                    ]),
                  ),

                  // ── Feedback banner ───────────────────────────────────────
                  if (_answered) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      color: _feedback.startsWith('✅')
                          ? const Color(0xFF4CAF50).withOpacity(0.12)
                          : _feedback.startsWith('⚡')
                              ? const Color(0xFFFFC107).withOpacity(0.12)
                              : AppColors.error.withOpacity(0.12),
                      child: Text(_feedback,
                          style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _feedback.startsWith('✅')
                                  ? const Color(0xFF4CAF50)
                                  : _feedback.startsWith('⚡')
                                      ? const Color(0xFFFFC107)
                                      : AppColors.error)),
                    ),
                  ],

                  // ── Answer reveal ─────────────────────────────────────────
                  if (_showAnswer) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3), width: 1),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('CORRECT ANSWER',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk', fontSize: 8,
                                letterSpacing: 2, color: AppColors.primary)),
                        const SizedBox(height: 8),
                        Text(card.answer,
                            style: const TextStyle(
                                fontFamily: 'Manrope', fontSize: 14,
                                height: 1.5, color: AppColors.onSurface)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Action buttons ────────────────────────────────────────
                  if (!_answered) ...[
                    Row(children: [
                      // Reveal without submitting
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showAnswer = !_showAnswer),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              border: Border.all(
                                  color: AppColors.outlineVariant, width: 1),
                            ),
                            child: Center(child: Text(
                              _showAnswer ? 'HIDE ANSWER' : 'REVEAL ANSWER',
                              style: const TextStyle(
                                  fontFamily: 'Space Grotesk', fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1, color: AppColors.outline),
                            )),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Submit answer
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _submitAnswer(state),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.primary, AppColors.tertiary]),
                            ),
                            child: const Center(child: Text('SUBMIT ANSWER',
                                style: TextStyle(
                                    fontFamily: 'Space Grotesk', fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1, color: Colors.white))),
                          ),
                        ),
                      ),
                    ]),
                  ] else ...[
                    // Next card button
                    GestureDetector(
                      onTap: () => _nextCard(state),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary, AppColors.tertiary]),
                        ),
                        child: const Center(child: Text('NEXT CARD  →',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk', fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2, color: Colors.white))),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Stats bento ───────────────────────────────────────────
                  Row(children: [
                    Expanded(child: _StatTile(
                        label: 'AVG TIME',
                        value: '${_avgRecognitionTime.toStringAsFixed(1)}s')),
                    const SizedBox(width: 6),
                    Expanded(child: _StatTile(
                        label: 'DIFFICULTY',
                        value: card.difficulty,
                        color: AppColors.tertiary)),
                    const SizedBox(width: 6),
                    Expanded(child: _StatTile(
                        label: 'DONE', value: '$done/$total')),
                    const SizedBox(width: 6),
                    Expanded(child: _StatTile(
                        label: 'PROFICIENCY',
                        value: '${(_combatProficiency * 100).round()}%',
                        color: _proficiencyColor)),
                  ]),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Color get _proficiencyColor {
    if (_combatProficiency >= 0.7) return const Color(0xFF4CAF50);
    if (_combatProficiency >= 0.4) return const Color(0xFFFFC107);
    return AppColors.error;
  }
}

// ── Locked empty state ────────────────────────────────────────────────────────
class _LockedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3), width: 2),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: const Icon(Icons.style,
                              color: AppColors.primary, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text('ARENA LOCKED',
                  style: TextStyle(
                      fontFamily: 'Space Grotesk', fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: 2,
                      color: AppColors.onSurface)),
              const SizedBox(height: 8),
              const Text(
                'Watch a video in the COMMAND tab.\nReyna generates flashcards from your video the moment it ends.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Manrope', fontSize: 13,
                    height: 1.6, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Builder(builder: (ctx) => GestureDetector(
                onTap: () {
                  final shell = ctx.findAncestorStateOfType<AppShellState>();
                  shell?.switchTab(0);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.tertiary]),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('GO TO COMMAND TAB',
                        style: TextStyle(
                            fontFamily: 'Space Grotesk', fontSize: 12,
                            fontWeight: FontWeight.w900, letterSpacing: 2,
                            color: Colors.white)),
                  ]),
                ),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── HUD bar ───────────────────────────────────────────────────────────────────
class _HudBar extends StatelessWidget {
  final double progress;
  const _HudBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(alignment: Alignment.center, children: [
        Container(height: 2, color: AppColors.surfaceContainerHighest),
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: [BoxShadow(
                  color: AppColors.primary.withOpacity(0.8), blurRadius: 8)],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) => Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 8, height: 8,
              color: i / 4 <= progress
                  ? AppColors.primary
                  : AppColors.surfaceContainerHighest,
            ),
          )),
        ),
      ]),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value,
      this.color = AppColors.onSurface});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surfaceContainerHigh,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        FittedBox(
          child: Text(value,
              style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 16,
                  fontWeight: FontWeight.w900, color: color)),
        ),
        Text(label, style: const TextStyle(
            fontFamily: 'Space Grotesk', fontSize: 6,
            letterSpacing: 1.5, color: AppColors.outline)),
      ]),
    );
  }
}

// ── Session complete ──────────────────────────────────────────────────────────
class _SessionComplete extends StatelessWidget {
  final VoidCallback onReset;
  final int correctCount;
  final int totalAnswered;
  final double avgTime;
  final double combatProficiency;
  const _SessionComplete({
    required this.onReset,
    required this.correctCount,
    required this.totalAnswered,
    required this.avgTime,
    required this.combatProficiency,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (combatProficiency * 100).round();
    final Color rankColor = pct >= 80
        ? const Color(0xFFFF6D8D)
        : pct >= 60
            ? const Color(0xFF81D4FA)
            : pct >= 40
                ? const Color(0xFFFFD54F)
                : const Color(0xFF73757D);
    final String rankLabel = pct >= 80
        ? 'RADIANT'
        : pct >= 60
            ? 'DIAMOND'
            : pct >= 40
                ? 'GOLD'
                : 'IRON';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.1),
                border: Border.all(color: rankColor, width: 2),
              ),
              child: Center(
                child: Text('$pct%',
                    style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 28,
                        fontWeight: FontWeight.w900, color: rankColor)),
              ),
            ),
            const SizedBox(height: 20),
            Text('SESSION COMPLETE — $rankLabel',
                style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 18,
                    fontWeight: FontWeight.w900, letterSpacing: 1,
                    color: rankColor)),
            const SizedBox(height: 6),
            Text('Combat Proficiency: $pct%  •  $correctCount/$totalAnswered correct  •  ${avgTime.toStringAsFixed(1)}s avg',
                style: const TextStyle(fontFamily: 'Manrope', fontSize: 12,
                    color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.tertiary]),
                ),
                child: const Text('REPLAY SESSION',
                    style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 13,
                        fontWeight: FontWeight.w900, letterSpacing: 2,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
