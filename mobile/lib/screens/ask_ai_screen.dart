import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/share_text.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/document.dart';
import '../services/app_state.dart';
import '../widgets/ai_content.dart';
import '../widgets/folio_motion.dart';

class DocumentChatPage extends StatelessWidget {
  const DocumentChatPage({super.key, this.document});
  final Document? document;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        document?.title ?? 'Compare documents',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: AskAiScreen(documentId: document?.id, conversation: true),
        ),
      ),
    ),
  );
}

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key, this.documentId, this.conversation = false});
  final String? documentId;
  final bool conversation;
  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _composerFocus = FocusNode();
  AppState? _state;
  bool _follow = true;
  bool _savedOnly = false;
  String _revision = '';
  @override
  void initState() {
    super.initState();
    _composerFocus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  SpeechToText? _speech;
  FlutterTts? _tts;
  bool _listening = false;
  String? _speaking;

  Future<void> _dictate() async {
    try {
      if (_listening) {
        await _speech?.stop();
        if (mounted) setState(() => _listening = false);
        return;
      }
      final speech = _speech ??= SpeechToText();
      final available = await speech.initialize(
        onStatus: (status) {
          if (mounted && status != 'listening') {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (!mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is unavailable. You can still type your question.',
            ),
          ),
        );
        return;
      }
      setState(() => _listening = true);
      await speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _input.text = result.recognizedWords;
          _input.selection = TextSelection.collapsed(
            offset: _input.text.length,
          );
          _state!.setDraft(widget.documentId, _input.text);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _readAloud(ChatMessage message) async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      if (!mounted) return;
      if (_speaking == message.id) {
        setState(() => _speaking = null);
        return;
      }
      tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = null);
      });
      tts.setErrorHandler((_) {
        if (mounted) setState(() => _speaking = null);
      });
      setState(() => _speaking = message.id);
      await tts.speak(AiContent.plainText(message.text));
    } catch (_) {
      if (mounted) {
        setState(() => _speaking = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Read aloud is unavailable on this device.'),
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (identical(_state, state)) return;
    _state?.removeListener(_changed);
    _state = state;
    _input.text = state.draftFor(widget.documentId);
    state.addListener(_changed);
    _changed();
  }

  void _changed() {
    final messages = _state!.messagesFor(widget.documentId);
    final revision =
        '${messages.length}:${messages.lastOrNull?.text.length}:${_state!.isChatBusy(widget.documentId)}';
    if (_revision == revision) return;
    _revision = revision;
    if (_follow) _toBottom();
  }

  void _toBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  void _send() {
    final question = _input.text.trim();
    if (question.isEmpty ||
        question.length > 2000 ||
        _state!.isChatBusy(widget.documentId)) {
      return;
    }
    _follow = true;
    _speech?.stop();
    unawaited(_state!.sendChat(question, documentId: widget.documentId));
    _input.clear();
    HapticFeedback.selectionClick();
    _toBottom(animate: true);
  }

  @override
  void dispose() {
    _composerFocus.removeListener(_focusChanged);
    _composerFocus.dispose();
    _speech?.stop();
    _tts?.stop();
    _state?.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!widget.conversation) return _hub(state);
    final colors = Theme.of(context).colorScheme;
    final doc =
        state.documents.where((d) => d.id == widget.documentId).firstOrNull;
    final available =
        widget.documentId == null
            ? state.documents.any((d) => d.status == 'Ready')
            : doc?.status == 'Ready';
    final busy = state.isChatBusy(widget.documentId);
    final all = state.messagesFor(widget.documentId);
    final messages = _savedOnly ? all.where((m) => m.saved).toList() : all;
    final error = state.chatError(widget.documentId);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.documentId == null
                      ? 'All ready documents • separate conversation'
                      : 'Only this document • saved on this device',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton(
                tooltip: _savedOnly ? 'Show all answers' : 'Saved answers',
                isSelected: _savedOnly,
                onPressed: () => setState(() => _savedOnly = !_savedOnly),
                icon: const Icon(Icons.bookmarks_outlined),
              ),
              IconButton(
                tooltip: 'Clear conversation',
                onPressed:
                    all.isEmpty
                        ? null
                        : () async {
                          final clear = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Clear this conversation?'),
                                  content: const Text(
                                    'This removes its saved answers and messages from this device. Your document is kept.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('Keep'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text('Clear'),
                                    ),
                                  ],
                                ),
                          );
                          if (clear == true) state.clearChat(widget.documentId);
                        },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        if (state.cacheError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              state.cacheError,
              style: TextStyle(color: colors.error),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification &&
                      notification.dragDetails != null) {
                    final follow = notification.metrics.extentAfter < 100;
                    if (follow != _follow) setState(() => _follow = follow);
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  itemCount: messages.isEmpty ? 1 : messages.length,
                  itemBuilder:
                      (context, index) =>
                          messages.isEmpty
                              ? _welcome(available)
                              : _message(messages[index], state),
                ),
              ),
              if (!_follow)
                Positioned(
                  bottom: 8,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Jump to latest answer',
                    onPressed: () {
                      setState(() => _follow = true);
                      _toBottom(animate: true);
                    },
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
            ],
          ),
        ),
        if (error.isNotEmpty && !_savedOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    error,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed:
                      busy || !available
                          ? null
                          : () => state.retryChat(widget.documentId),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: AnimatedContainer(
            duration: FolioMotion.duration(context),
            curve: FolioMotion.curve,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color:
                    _composerFocus.hasFocus
                        ? colors.primary
                        : colors.outlineVariant,
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: _listening ? 'Stop dictation' : 'Dictate question',
                    onPressed: available && !busy ? _dictate : null,
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                  ),
                  Expanded(
                    child: TextField(
                      focusNode: _composerFocus,
                      controller: _input,
                      enabled: available,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged:
                          (value) => state.setDraft(widget.documentId, value),
                      decoration: InputDecoration(
                        filled: false,
                        hintText:
                            available
                                ? 'Ask about ${widget.documentId == null ? 'your documents' : 'this document'}…'
                                : 'A ready document is needed',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder:
                          (context, value, child) => IconButton.filled(
                            tooltip: busy ? 'Stop response' : 'Send question',
                            onPressed:
                                busy
                                    ? () => state.stopChat(widget.documentId)
                                    : available && value.text.trim().isNotEmpty
                                    ? _send
                                    : null,
                            icon: Icon(
                              busy
                                  ? Icons.stop_rounded
                                  : Icons.arrow_upward_rounded,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _welcome(bool available) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 32),
      Text(
        _savedOnly ? 'Your saved answers' : 'Make sense of your documents.',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        _savedOnly
            ? 'Bookmark a useful answer to find it here.'
            : 'Ask a question in your own words. Check important details against the source before acting.',
      ),
      if (!_savedOnly && available) ...[
        const SizedBox(height: 24),
        for (final suggestion in [
          'Explain this in plain language',
          'What do I need to do next?',
          'Find important dates and requirements',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionChip(
              label: Text(suggestion),
              onPressed: () {
                _input.text = suggestion;
                _send();
              },
            ),
          ),
      ],
    ],
  );

  Widget _message(ChatMessage message, AppState state) {
    final theme = Theme.of(context);
    if (message.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.only(left: 32, bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: SelectableText(
            message.text,
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.text.isEmpty && message.role == 'streaming')
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Reading your sources…'),
              ],
            )
          else
            AiContent(
              text: message.text,
              streaming: message.role == 'streaming',
              sourceNumbers:
                  message.sources.map((s) => s['number'] ?? '').toList(),
              onSource:
                  (number) => _source(
                    message.sources.firstWhere((s) => s['number'] == number),
                    state,
                  ),
            ),
          if (message.incomplete)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Partial answer',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          if (message.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in message.sources)
                    ActionChip(
                      avatar: const Icon(Icons.description_outlined, size: 16),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          '${source['doc']} · ${source['detail']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: () => _source(source, state),
                    ),
                ],
              ),
            ),
          if (message.role != 'streaming' && message.text.isNotEmpty)
            Wrap(
              children: [
                IconButton(
                  tooltip:
                      _speaking == message.id
                          ? 'Stop reading'
                          : 'Read answer aloud',
                  onPressed: () => _readAloud(message),
                  icon: Icon(
                    _speaking == message.id
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_outlined,
                    size: 18,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy answer',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: AiContent.plainText(message.text)),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Answer copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                ),
                IconButton(
                  tooltip: message.saved ? 'Unsave answer' : 'Save answer',
                  onPressed:
                      () => state.toggleSaved(widget.documentId, message.id),
                  icon: Icon(
                    message.saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                  ),
                ),
                IconButton(
                  tooltip: 'Share answer',
                  onPressed:
                      () => ShareText.show(
                        context,
                        AiContent.plainText(message.text),
                      ),
                  icon: const Icon(Icons.ios_share, size: 18),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _source(Map<String, String> source, AppState state) {
    final doc =
        state.documents.where((d) => d.id == source['documentId']).firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .65,
            minChildSize: .35,
            maxChildSize: .95,
            builder:
                (context, controller) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      source['doc'] ?? 'Source',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(source['detail'] ?? 'Source document'),
                    const SizedBox(height: 20),
                    SelectableText(
                      source['excerpt']?.isNotEmpty == true
                          ? source['excerpt']!
                          : doc?.rawText.isNotEmpty == true
                          ? doc!.rawText
                          : 'Source text is not available on this device. Open the document in your vault.',
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _hub(AppState state) => ListView(
    key: const PageStorageKey('chat-hub-scroll'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: [
      Text('Ask Folio', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text(
        'A conversation for every document. Pick up where you left off.',
      ),
      const SizedBox(height: 24),
      if (state.documents.isEmpty) ...[
        const Text('Add a document to get started.'),
        TextButton(
          onPressed: () => state.navigate(1),
          child: const Text('Open documents'),
        ),
      ],
      for (final doc in state.documents)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(doc.title),
            subtitle: Text(
              doc.status == 'Ready'
                  ? '${state.messagesFor(doc.id).where((m) => m.role == 'user').length} questions · saved on this device'
                  : doc.status,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DocumentChatPage(document: doc),
                  ),
                ),
          ),
        ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed:
            state.documents.isEmpty
                ? null
                : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DocumentChatPage(),
                  ),
                ),
        icon: const Icon(Icons.library_books_outlined),
        label: const Text('Compare across all documents'),
      ),
    ],
  );
}
