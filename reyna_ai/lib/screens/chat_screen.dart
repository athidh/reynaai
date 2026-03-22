// lib/screens/chat_screen.dart
//
// Command Center — Real-time Reyna chatroom
// POSTs to /tutor/chat with the user's last video transcript
// and domain as context for grounded Socratic responses.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll  = ScrollController();
  final List<_Msg> _messages = [];
  // LLM conversation history — sent to backend so Reyna remembers context
  final List<Map<String, String>> _history = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Initial greeting from Reyna
    _messages.add(const _Msg(
      isReyna: true,
      text: 'OPERATIVE — I am REYNA. Your combat AI instructor.\n\n'
          'Watch a video in the Training Arena and I will brief you with '
          'Socratic questions drawn directly from the transcript.\n\n'
          'What is your mission today?',
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final state = context.read<AppState>();

    setState(() {
      _messages.add(_Msg(isReyna: false, text: text));
      _isTyping = true;
      _msgCtrl.clear();
    });

    _scrollToBottom();

    try {
      final token = state.token;
      if (token == null || token == 'mock_token') {
        // Offline fallback
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() {
          _messages.add(_Msg(
            isReyna: true,
            text: 'Authenticate with the backend to receive full combat intelligence, operative. '
                  'For now: "${text.length > 30 ? text.substring(0, 30) : text}..." — stay focused on fundamentals.',
          ));
          _isTyping = false;
        });
        return;
      }

      // Add user turn to history
      _history.add({'role': 'user', 'content': text});

      final data = await ApiService.chatWithReyna(
        token,
        message: text,
        transcriptContext: state.lastVideoTranscript,
        domain: state.domainInterest ?? '',
        history: List.from(_history), // snapshot of history so far
      );

      final reply = (data['reply'] as String?) ?? 'Processing...';
      final combatStatus = data['combat_status'] as String?;

      // Add assistant reply to history for next turn
      _history.add({'role': 'assistant', 'content': reply});

      if (mounted) {
        setState(() {
          _messages.add(_Msg(
            isReyna: true,
            text: reply,
            combatStatus: combatStatus,
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Msg(
            isReyna: true,
            text: 'Signal disrupted. Retry your transmission, operative.',
          ));
          _isTyping = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasTranscript = state.lastVideoTranscript.isNotEmpty;
    final domain = state.domainInterest ?? 'General';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                border: Border(
                    bottom: BorderSide(color: AppColors.primaryContainer, width: 1)),
              ),
              child: Row(
                children: [
                  Container(width: 4, height: 44, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COMMAND CENTER',
                            style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppColors.onSurface)),
                        Text(
                          'REYNA AI  •  $domain',
                          style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 8,
                              letterSpacing: 2,
                              color: AppColors.outline),
                        ),
                      ],
                    ),
                  ),
                  // Transcript context badge
                  if (hasTranscript)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5, height: 5,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          const Text('LIVE CONTEXT',
                              style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 7,
                                  letterSpacing: 1,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Chat messages ────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (_isTyping && i == _messages.length) {
                    return _TypingBubble();
                  }
                  return _ChatBubble(msg: _messages[i]);
                },
              ),
            ),

            // ── Input bar ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                border: Border(
                    top: BorderSide(color: AppColors.primaryContainer, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        border: Border.all(
                            color: AppColors.primaryContainer, width: 1),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: AppColors.onSurface,
                            fontSize: 13),
                        cursorColor: AppColors.primary,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: hasTranscript
                              ? 'Ask Reyna about the video...'
                              : 'Ask Reyna anything...',
                          hintStyle: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              color: AppColors.outlineVariant,
                              fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isTyping ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      color: _isTyping ? AppColors.outline : AppColors.primary,
                      child: _isTyping
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ))
                          : const Icon(Icons.send,
                              color: AppColors.onPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message model ─────────────────────────────────────────────────────────────
class _Msg {
  final bool isReyna;
  final String text;
  final String? combatStatus;
  const _Msg({
    required this.isReyna,
    required this.text,
    this.combatStatus,
  });
}

// ── Combat status colors ───────────────────────────────────────────────────────
Color _combatStatusColor(String? status) {
  switch (status) {
    case 'ELITE_MASTERY':
      return const Color(0xFFFF6D8D);
    case 'STEADY_ADVANCE':
      return AppColors.primary;
    case 'CRITICAL_RECOVERY':
      return AppColors.error;
    default:
      return AppColors.primary;
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final accentColor = msg.isReyna
        ? _combatStatusColor(msg.combatStatus)
        : AppColors.tertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            msg.isReyna ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (msg.isReyna) ...[
            // Avatar
            Container(
              width: 32,
              height: 32,
              color: accentColor.withOpacity(0.15),
              child: Center(
                child: Text('R',
                    style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: accentColor)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isReyna
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                if (msg.isReyna && msg.combatStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(msg.combatStatus!,
                        style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 7,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: accentColor)),
                  ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: msg.isReyna
                        ? AppColors.surfaceContainerHigh
                        : AppColors.primary.withOpacity(0.12),
                    border: msg.isReyna
                        ? Border(
                            left: BorderSide(color: accentColor, width: 3))
                        : Border.all(
                            color: AppColors.tertiary.withOpacity(0.3)),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                        fontFamily: msg.isReyna ? 'Manrope' : 'Space Grotesk',
                        fontSize: 13,
                        height: 1.5,
                        fontWeight:
                            msg.isReyna ? FontWeight.w400 : FontWeight.w600,
                        color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ),
          if (!msg.isReyna) ...[
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              color: AppColors.tertiary.withOpacity(0.1),
              child: const Icon(Icons.person_outline,
                  color: AppColors.tertiary, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            color: AppColors.primary.withOpacity(0.15),
            child: Center(
              child: Text('R',
                  style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ANALYZING',
                    style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.outline)),
                const SizedBox(width: 8),
                SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
