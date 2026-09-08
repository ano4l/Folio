import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});
  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _listening = false;

  static const _suggestions = [
    'When is my bursary renewal?',
    'Do I still owe any fees?',
    'What are my funding award conditions?',
    'Draft a summary for my graduate application',
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Speech recognition unavailable on this device.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
      return;
    }
    setState(() => _listening = true);
    _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'en_ZA'),
      onResult: (r) {
        if (r.finalResult) {
          setState(() {
            _inputCtrl.text = r.recognizedWords;
            _listening = false;
          });
        }
      },
    );
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage('en-ZA');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }

  void _send() {
    final q = _inputCtrl.text.trim();
    if (q.isEmpty) return;
    final state = context.read<AppState>();
    if (!state.hasCredits) {
      _showCreditSheet(context);
      return;
    }
    state.sendChat(q);
    _inputCtrl.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _scrollToBottom();

    return Column(
      children: [
        // Frosted Glass Credit Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                const Icon(CupertinoIcons.bolt_fill, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ' free left ·  credits',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => _showCreditSheet(context),
                  child: const Text('Top up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
                ),
              ],
            ),
          ),
        ),

        // Chat log
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // padded for floating bottom dock
            itemCount: state.chatMessages.length + (state.aiTyping ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == state.chatMessages.length) {
                return _Bubble(
                  isUser: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (j) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppColors.slate, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                );
              }
              final msg = state.chatMessages[i];
              final isUser = msg.role == 'user';
              return Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _Bubble(
                    isUser: isUser,
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: isUser ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                  if (!isUser && msg.sources.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: msg.sources.map((s) => ActionChip(
                          avatar: const Icon(CupertinoIcons.doc_text_fill, size: 12, color: AppColors.teal),
                          label: Text(s['doc'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          backgroundColor: AppColors.tealLight,
                          side: BorderSide(color: AppColors.teal.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onPressed: () {
                            final match = state.documents.where((d) => d.title == s['doc']);
                            if (match.isNotEmpty) {
                              state.selectDoc(match.first);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Open "" in Documents tab'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              );
                            }
                          },
                        )).toList(),
                      ),
                    ),
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: IconButton(
                        icon: const Icon(CupertinoIcons.speaker_2, size: 16, color: AppColors.slate),
                        onPressed: () => _speak(msg.text),
                        tooltip: 'Read aloud',
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // Suggestions Pills
        if (state.chatMessages.length <= 1)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_suggestions[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink)),
                backgroundColor: AppColors.card.withValues(alpha: 0.9),
                side: const BorderSide(color: AppColors.line, width: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () {
                  _inputCtrl.text = _suggestions[i];
                  _send();
                },
              ),
            ),
          ),

        // Input bar elevated above glass bottom bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            borderRadius: BorderRadius.circular(28),
            opacity: 0.9,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _listening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                    color: _listening ? AppColors.danger : AppColors.slate,
                    size: 20,
                  ),
                  onPressed: _toggleListen,
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Ask about your documents…',
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 16),
                  ),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCreditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top up AI credits', style: Theme.of(context).textTheme.headlineSmall),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.slate, size: 22),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Your monthly free allowance is exhausted. Purchase credits to keep querying.',
                style: TextStyle(fontSize: 13, color: AppColors.slate)),
            const SizedBox(height: 20),
            ...[10, 25, 50].map((n) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    onTap: () {
                      context.read<AppState>().purchaseCredits(n);
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(' credits added.'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(CupertinoIcons.bolt_fill, color: AppColors.warning, size: 20),
                      ),
                      title: Text(' AI credits', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Text('R.00', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.slate),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool isUser;
  final Widget child;
  const _Bubble({required this.isUser, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? AppColors.teal : AppColors.card,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
          ),
          border: isUser ? null : Border.all(color: AppColors.line, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
