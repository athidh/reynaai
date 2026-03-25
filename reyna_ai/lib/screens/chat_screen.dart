// lib/screens/chat_screen.dart
//
// Command Center — Real-time Reyna chatroom with Sentience Voice Layer
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';

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
  final List<Map<String, String>> _history = [];
  bool _isTyping = false;

  // ── Sentience Layer (Voice) State ──
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  WebSocketChannel? _channel;
  bool _isRecording = false;
  final BytesBuilder _ttsBuffer = BytesBuilder();  // Buffer for TTS audio chunks
  int? _pendingVoiceBubbleIndex;  // Index of the user's voice placeholder bubble

  @override
  void initState() {
    super.initState();
    _messages.add(const _Msg(
      isReyna: true,
      text: 'OPERATIVE — I am REYNA. Your combat AI instructor.\n\n'
          'Use text or VOICE transmission. I analyze latency, context, and combat readiness to customize your Socratic feedback.\n\n'
          'What is your mission today?',
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  // ── Text Input ────────────────────────────────────────────────────────────
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
        _simulatedFallback(text);
        return;
      }

      _history.add({'role': 'user', 'content': text});

      final data = await ApiService.chatWithReyna(
        token,
        message: text,
        transcriptContext: state.lastVideoTranscript,
        domain: state.domainInterest ?? '',
        history: List.from(_history),
      );

      final reply = (data['reply'] as String?) ?? 'Processing...';
      final combatStatus = data['combat_status'] as String?;

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
      _handleNetError();
    }
  }

  // ── Voice Input (Sentience Layer) ──────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop and Send
      setState(() => _isRecording = false);
      final path = await _audioRecorder.stop();
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        _sendVoiceMessage(bytes);
      }
    } else {
      // Start
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/reyna_mic.wav';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: path,
        );
        setState(() => _isRecording = true);
      }
    }
  }

  void _sendVoiceMessage(Uint8List audioBytes) {
    final state = context.read<AppState>();
    final token = state.token ?? '';
    
    if (token.isEmpty || token == 'mock_token') {
      _simulatedFallback("Voice transmission captured.");
      return;
    }

    // Add a placeholder bubble for the user's voice message immediately
    setState(() {
      _messages.add(const _Msg(isReyna: false, text: 'Transmitting voice...', isVoice: true));
      _pendingVoiceBubbleIndex = _messages.length - 1;
      _isTyping = true;
    });
    _scrollToBottom();

    // Reset TTS audio buffer
    _ttsBuffer.clear();

    final wsUrl = ApiService.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    _channel?.sink.close();
    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/reyna/chat?token=$token'));

    _channel!.stream.listen(
      (message) {
        if (message is String) {
          try {
            final data = jsonDecode(message);
            final event = data['event'];
            
            if (event == 'transcription') {
              final text = data['text'] as String;
              setState(() {
                // Update the placeholder bubble with the real transcription
                if (_pendingVoiceBubbleIndex != null && _pendingVoiceBubbleIndex! < _messages.length) {
                  _messages[_pendingVoiceBubbleIndex!] = _Msg(isReyna: false, text: text, isVoice: true);
                }
                _pendingVoiceBubbleIndex = null;
                _history.add({'role': 'user', 'content': text});
              });
              _scrollToBottom();
            } else if (event == 'reyna_response') {
              final text = data['text'] as String;
              setState(() {
                _messages.add(_Msg(isReyna: true, text: text, isVoice: true));
                _history.add({'role': 'assistant', 'content': text});
                _isTyping = false;
              });
              _scrollToBottom();
            } else if (event == 'audio_done') {
              // Play all buffered TTS audio at once — prevents stutter
              final fullAudio = _ttsBuffer.takeBytes();
              if (fullAudio.isNotEmpty) {
                _audioPlayer.play(BytesSource(fullAudio));
              }
              _channel?.sink.close();
            }
          } catch (e) {
            debugPrint('WS Parse Error: $e');
          }
        } else if (message is Uint8List) {
          // Buffer incoming TTS audio chunks instead of playing each one
          _ttsBuffer.add(message);
        }
      },
      onError: (e) {
        debugPrint('WS Error: $e');
        _handleNetError();
      },
      onDone: () {
        if (mounted) setState(() => _isTyping = false);
      }
    );

    // Stream out binary microphone capture then notify EOF
    _channel!.sink.add(audioBytes);
    _channel!.sink.add(jsonEncode({"event": "end_of_speech"}));
  }

  // ── Utils ───────────────────────────────────────────────────────────────────
  Future<void> _simulatedFallback(String text) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _messages.add(_Msg(
          isReyna: true,
          text: 'Authenticate with the backend to receive full combat intelligence, operative. '
                'For now: "${text.length > 30 ? text.substring(0, 30) : text}..." — stay focused on fundamentals.',
        ));
        _isTyping = false;
      });
    }
  }

  void _handleNetError() {
    if (mounted) {
      setState(() {
        _messages.add(const _Msg(
          isReyna: true,
          text: 'Signal disrupted. Retry your transmission, operative.',
        ));
        _isTyping = false;
      });
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
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                border: Border(bottom: BorderSide(color: AppColors.primaryContainer, width: 1)),
              ),
              child: Row(
                children: [
                  Container(width: 4, height: 44, color: AppColors.primary),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('COMMAND CENTER',
                            style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppColors.onSurface)),
                        Text('REYNA AI  •  $domain',
                            style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 8, letterSpacing: 2, color: AppColors.outline)),
                      ],
                    ),
                  ),
                  if (hasTranscript)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                          SizedBox(width: 4),
                          Text('LIVE CONTEXT',
                              style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 7, letterSpacing: 1, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (_isTyping && i == _messages.length) return _TypingBubble(isVoice: _isRecording);
                  return _ChatBubble(msg: _messages[i]);
                },
              ),
            ),

            // Input Bar
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                border: Border(top: BorderSide(color: AppColors.primaryContainer, width: 1)),
              ),
              child: Row(
                children: [
                  // Mic Button
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red.withOpacity(0.15) : AppColors.primary.withOpacity(0.08),
                        border: Border.all(color: _isRecording ? Colors.red : AppColors.primary.withOpacity(0.4), width: _isRecording ? 2 : 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: _isRecording ? Colors.red : AppColors.primary,
                        size: 20
                      ),
                    ),
                  ),
                  SizedBox(width: 8),

                  // Text Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.outline.withOpacity(0.3), width: 1.5),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: TextStyle(fontFamily: 'Space Grotesk', color: AppColors.onSurface, fontSize: 13),
                        cursorColor: AppColors.primary,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: _isRecording ? 'Listening...' : (hasTranscript ? 'Ask Reyna about the video...' : 'Ask Reyna anything...'),
                          hintStyle: TextStyle(fontFamily: 'Space Grotesk', color: _isRecording ? Colors.red : AppColors.onSurfaceVariant, fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),

                  // Send Button
                  GestureDetector(
                    onTap: _isTyping ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isTyping ? AppColors.primaryDim : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isTyping
                          ? Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : Icon(Icons.send, color: AppColors.onPrimary, size: 20),
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

// ── Message Model ─────────────────────────────────────────────────────────────
class _Msg {
  final bool isReyna;
  final String text;
  final String? combatStatus;
  final bool isVoice;
  const _Msg({
    required this.isReyna,
    required this.text,
    this.combatStatus,
    this.isVoice = false,
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

// ── Chat Bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final accentColor = msg.isReyna ? _combatStatusColor(msg.combatStatus) : AppColors.tertiary;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: msg.isReyna ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (msg.isReyna) ...[
            Container(
              width: 32, height: 32,
              color: accentColor.withOpacity(0.15),
              child: Center(child: Text('R', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 14, fontWeight: FontWeight.w900, color: accentColor))),
            ),
            SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isReyna ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                if (msg.isReyna && msg.combatStatus != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(msg.combatStatus!, style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 7, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: accentColor)),
                  ),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: msg.isReyna ? AppColors.surfaceContainerHigh : AppColors.primary.withOpacity(0.12),
                    border: msg.isReyna ? Border(left: BorderSide(color: accentColor, width: 3)) : Border.all(color: AppColors.tertiary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.isVoice)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic, size: 12, color: msg.isReyna ? accentColor : AppColors.tertiary),
                              SizedBox(width: 4),
                              Text('VOICE TRANSMISSION', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 7, letterSpacing: 1, color: msg.isReyna ? accentColor : AppColors.tertiary, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      Text(
                        msg.text,
                        style: TextStyle(fontFamily: msg.isReyna ? 'Manrope' : 'Space Grotesk', fontSize: 13, height: 1.5, fontWeight: msg.isReyna ? FontWeight.w400 : FontWeight.w600, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!msg.isReyna) ...[
            SizedBox(width: 10),
            Container(
              width: 32, height: 32,
              color: AppColors.tertiary.withOpacity(0.1),
              child: Icon(Icons.person_outline, color: AppColors.tertiary, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  final bool isVoice;
  const _TypingBubble({this.isVoice = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            color: AppColors.primary.withOpacity(0.15),
            child: Center(child: Text('R', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary))),
          ),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isVoice ? 'TRANSCRIBING/THINKING' : 'ANALYZING', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 9, letterSpacing: 2, color: AppColors.outline)),
                SizedBox(width: 8),
                SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
