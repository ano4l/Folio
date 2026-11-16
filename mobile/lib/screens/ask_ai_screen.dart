import 'package:share_plus/share_plus.dart';
import '../services/study_export.dart';
import 'document_reader_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/share_text.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/document.dart';
import '../models/study.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_content.dart';
import '../widgets/folio_motion.dart';

class DocumentChatPage extends StatelessWidget {
  const DocumentChatPage({
    super.key,
    this.document,
    this.studySpaceId,
    this.studyMode = false,
  });
  final Document? document;
  final String? studySpaceId;
  final bool studyMode;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        studyMode
            ? 'Study · ${document?.title ?? ''}'
            : document?.title ?? 'Compare documents',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: AskAiScreen(
            documentId: document?.id,
            conversation: true,
            studySpaceId: studySpaceId,
            studyMode: studyMode,
          ),
        ),
      ),
    ),
  );
}

/// Rebuilds one chat bubble when its own message object changes. Streaming
/// replaces only the last message, so earlier answers keep their layout and
/// parsed Markdown instead of re-rendering on every token batch.
class _LiveMessage extends StatelessWidget {
  const _LiveMessage({
    super.key,
    required this.id,
    required this.documentId,
    required this.builder,
  });
  final String id;
  final String? documentId;
  final Widget Function(ChatMessage message, AppState state) builder;

  @override
  Widget build(BuildContext context) {
    final message = context.select<AppState, ChatMessage?>(
      (s) => s.messagesFor(documentId).where((m) => m.id == id).lastOrNull,
    );
    if (message == null) return const SizedBox.shrink();
    return RepaintBoundary(child: builder(message, context.read<AppState>()));
  }
}

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({
    super.key,
    this.documentId,
    this.conversation = false,
    this.studySpaceId,
    this.studyMode = false,
  });
  final String? documentId;
  final bool conversation;
  final String? studySpaceId;
  final bool studyMode;
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
      await tts.speak(_messageText(message));
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
    if (!widget.conversation) return;
    final messages = _state!.messagesFor(widget.documentId);
    final revision =
        '${messages.length}:${messages.lastOrNull?.text.length}:${messages.expand((m) => m.quiz?.questions ?? <StudyQuestion>[]).where((q) => q.selectedIndex != null).length}:${_state!.isChatBusy(widget.documentId)}';
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

  void _askStudy(String prompt) {
    _input.text = prompt;
    _send();
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
    context.select<AppState, List<Object?>>(
      (s) =>
          widget.conversation || s.navigationIndex == 2
              ? [
                ...s.documents,
                if (widget.conversation) ...[
                  s.cacheError,
                  s.isChatBusy(widget.documentId),
                  s.chatError(widget.documentId),
                  // Message bodies are observed per message in _LiveMessage so
                  // a streaming token only rebuilds its own bubble.
                  for (final message in s.messagesFor(widget.documentId)) ...[
                    message.id,
                    message.saved,
                  ],
                ] else ...[
                  for (final doc in s.documents)
                    s.messagesFor(doc.id).where((m) => m.role == 'user').length,
                ],
              ]
              : const <Object?>[],
    );
    final state = context.read<AppState>();
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
              _conversationMenu(state, all),
            ],
          ),
        ),
        if (widget.studyMode && widget.documentId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learn and practise from this source',
                  style: TextStyle(fontSize: 12),
                ),
                const Text(
                  'Quiz questions sample readable text; check important points in the original.',
                  style: TextStyle(fontSize: 11, color: AppColors.slate),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.lightbulb_outline, size: 18),
                        label: const Text('Explain simply'),
                        onPressed:
                            busy || !available
                                ? null
                                : () => _askStudy(
                                  'Explain the main ideas in this document in plain language. Cite the source passages you use.',
                                ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(
                          Icons.record_voice_over_outlined,
                          size: 18,
                        ),
                        label: const Text('Teach step by step'),
                        onPressed:
                            busy || !available
                                ? null
                                : () => _askStudy(
                                  'Teach me the most important idea in this document step by step. Ask me a short check-in question before moving on, and cite the source.',
                                ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.summarize_outlined, size: 18),
                        label: const Text('Summarise'),
                        onPressed:
                            busy || !available
                                ? null
                                : () => _askStudy(
                                  'Summarise the key ideas in this document as concise study notes. Cite each source passage.',
                                ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.quiz_outlined, size: 18),
                        label: Text(busy ? 'Working…' : 'Quiz me'),
                        onPressed:
                            busy || !available
                                ? null
                                : () => _configureQuiz(state),
                      ),
                    ],
                  ),
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
                  itemBuilder: (context, index) {
                    if (messages.isEmpty) return _welcome(available);
                    final message = messages[index];
                    if (message.id.isEmpty) return _message(message, state);
                    return _LiveMessage(
                      key: ValueKey(message.id),
                      id: message.id,
                      documentId: widget.documentId,
                      builder: _message,
                    );
                  },
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
          else if (message.quiz != null)
            _quiz(message, state)
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
                if (widget.studyMode &&
                    widget.studySpaceId != null &&
                    message.quiz == null &&
                    message.sources.isNotEmpty)
                  IconButton(
                    tooltip: 'Save as study note',
                    onPressed: () => _saveAsNote(message, state),
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                  ),
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
                      ClipboardData(text: _messageText(message)),
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
                      () => ShareText.show(context, _messageText(message)),
                  icon: const Icon(Icons.ios_share, size: 18),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _quiz(ChatMessage message, AppState state) {
    final quiz = message.quiz!;
    final score =
        quiz.questions
            .where(
              (question) => question.selectedIndex == question.correctIndex,
            )
            .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message.text, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (var qIndex = 0; qIndex < quiz.questions.length; qIndex++)
          _QuizQuestionCard(
            question: quiz.questions[qIndex],
            number: qIndex + 1,
            onSelect:
                (choice) => state.answerStudyQuestion(
                  widget.documentId!,
                  message.id,
                  qIndex,
                  choice,
                ),
            onSource:
                (question) => _source({
                  'documentId': question.sourceDocumentId,
                  'doc': question.sourceTitle,
                  'page': question.sourcePage?.toString() ?? '',
                  'detail':
                      question.sourcePage == null
                          ? 'Source document'
                          : 'Page ${question.sourcePage}',
                  'excerpt': question.sourceExcerpt,
                }, state),
          ),
        if (quiz.completed)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Round complete · $score of ${quiz.questions.length} correct. Revisit any source-linked explanation below.',
                  ),
                ),
              ],
            ),
          ),
        if (quiz.completed)
          Wrap(
            spacing: 8,
            children: [
              if (quiz.questions.any((q) => q.selectedIndex != q.correctIndex))
                TextButton.icon(
                  onPressed:
                      () => state.retryMissedQuiz(widget.documentId!, quiz),
                  icon: const Icon(Icons.replay),
                  label: const Text('Practise missed questions'),
                ),
              TextButton.icon(
                onPressed:
                    state.isChatBusy(widget.documentId)
                        ? null
                        : () => _configureQuiz(state),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('New quiz'),
              ),
              if (widget.studySpaceId != null)
                TextButton.icon(
                  onPressed: () {
                    try {
                      for (final q in quiz.questions) {
                        state.addStudyCard(
                          spaceId: widget.studySpaceId!,
                          front: q.prompt,
                          back:
                              '${q.options[q.correctIndex]}\n\n${q.explanation}',
                          documentId: q.sourceDocumentId,
                          sourcePage: q.sourcePage,
                          sourceExcerpt: q.sourceExcerpt,
                        );
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Quiz questions saved as revision cards.',
                          ),
                        ),
                      );
                    } on FormatException catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Save revision cards'),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _configureQuiz(AppState state) async {
    var count = 5;
    var difficulty = 'standard';
    final focus = TextEditingController();
    final start = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: const Text('Make your quiz'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Length'),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 3, label: Text('3')),
                            ButtonSegment(value: 5, label: Text('5')),
                            ButtonSegment(value: 8, label: Text('8')),
                          ],
                          selected: {count},
                          onSelectionChanged:
                              (v) => update(() => count = v.single),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: difficulty,
                          decoration: const InputDecoration(
                            labelText: 'Difficulty',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'foundation',
                              child: Text('Foundation'),
                            ),
                            DropdownMenuItem(
                              value: 'standard',
                              child: Text('Understanding'),
                            ),
                            DropdownMenuItem(
                              value: 'challenge',
                              child: Text('Application'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) update(() => difficulty = v);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: focus,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Focus topic (optional)',
                            hintText: 'e.g. database normalisation',
                          ),
                        ),
                        const Text(
                          'Uses sampled readable passages. Check source explanations before treating answers as exam guidance.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Start quiz'),
                    ),
                  ],
                ),
          ),
    );
    if (start == true && mounted) {
      state.generateQuiz(
        widget.documentId!,
        count: count,
        difficulty: difficulty,
        focus: focus.text.trim(),
      );
    }
    Future<void>.delayed(const Duration(milliseconds: 400), focus.dispose);
  }

  void _saveAsNote(ChatMessage message, AppState state) {
    final source = message.sources.first;
    final text = _messageText(message).trim();
    final firstLine = text.split('\n').first.trim();
    try {
      state.saveStudyNote(
        spaceId: widget.studySpaceId!,
        title:
            firstLine.length > 80
                ? '${firstLine.substring(0, 77)}…'
                : firstLine,
        body: text,
        documentId: source['documentId'] ?? widget.documentId!,
        sourcePage: int.tryParse(source['page'] ?? ''),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to study notes with its source.')),
      );
    } on FormatException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
                    if (doc != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            this.context,
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => DocumentReaderScreen(
                                    document: doc,
                                    initialPage: int.tryParse(
                                      source['page'] ?? '',
                                    ),
                                    studySpaceId: widget.studySpaceId,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Read in context'),
                      ),
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

  String _messageText(ChatMessage message) {
    if (message.quiz == null) return AiContent.plainText(message.text);
    final out = StringBuffer('${message.text}\n\n');
    for (final q in message.quiz!.questions) {
      out.writeln(q.prompt);
      for (var i = 0; i < q.options.length; i++) {
        out.writeln('${String.fromCharCode(65 + i)}. ${q.options[i]}');
      }
      if (q.selectedIndex != null) {
        out.writeln(
          'Your answer: ${q.options[q.selectedIndex!]}\nCorrect answer: ${q.options[q.correctIndex]}\n${q.explanation}',
        );
      }
      out.writeln(
        'Source: ${q.sourceTitle}${q.sourcePage == null ? '' : ' · page ${q.sourcePage}'}\n',
      );
    }
    return out.toString();
  }

  Widget _conversationMenu(
    AppState state,
    List<ChatMessage> messages,
  ) => PopupMenuButton<String>(
    tooltip: 'Conversation actions',
    enabled: messages.isNotEmpty,
    itemBuilder:
        (_) => const [
          PopupMenuItem(value: 'export', child: Text('Export conversation')),
          PopupMenuItem(value: 'clear', child: Text('Clear conversation')),
        ],
    onSelected: (action) async {
      if (action == 'clear') {
        final owner = state.user?.id;
        final clear = await showDialog<bool>(
          context: context,
          builder:
              (dialog) => AlertDialog(
                title: const Text('Clear this conversation?'),
                content: const Text(
                  'This removes its saved answers, quizzes and messages from this device. Your document and study notes are kept.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Keep'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Clear'),
                  ),
                ],
              ),
        );
        if (clear == true && mounted && state.user?.id == owner) {
          state.clearChat(widget.documentId);
        }
      } else {
        final out = StringBuffer('# Folio conversation\n\n');
        for (final message in messages.where((m) => m.role != 'streaming')) {
          out.writeln(
            '## ${message.role == 'user' ? 'You' : 'Folio'}${message.incomplete ? ' (incomplete)' : ''}\n\n${_messageText(message)}\n',
          );
          for (final source in message.sources) {
            out.writeln(
              'Source: ${source['doc']} · ${source['detail']}\n${source['excerpt'] ?? ''}\n',
            );
          }
        }
        try {
          final path = await StudyExport.textFile(out.toString(), 'md');
          if (!mounted) return;
          final box = context.findRenderObject() as RenderBox;
          await Share.shareXFiles(
            [XFile(path, mimeType: 'text/markdown')],
            subject: 'Folio conversation',
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Conversation export could not finish.'),
              ),
            );
          }
        }
      }
    },
  );

  Widget _hub(AppState state) {
    final headers = <Widget>[
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
    ];
    final footer = <Widget>[
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
    ];
    return ListView.builder(
      key: const PageStorageKey('chat-hub-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      itemCount: headers.length + state.documents.length + footer.length,
      itemBuilder: (context, index) {
        if (index < headers.length) return headers[index];
        final rowIndex = index - headers.length;
        if (rowIndex >= state.documents.length) {
          return footer[rowIndex - state.documents.length];
        }
        final doc = state.documents[rowIndex];
        return Padding(
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
        );
      },
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.question,
    required this.number,
    required this.onSelect,
    required this.onSource,
  });
  final StudyQuestion question;
  final int number;
  final ValueChanged<int> onSelect;
  final ValueChanged<StudyQuestion> onSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = question.selectedIndex;
    final correct = selected != null && selected == question.correctIndex;
    final accent =
        selected == null
            ? theme.colorScheme.primary
            : correct
            ? const Color(0xFF16734B)
            : theme.colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION $number',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.teal,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.prompt,
            style: theme.textTheme.titleSmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < question.options.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Material(
                color:
                    selected == null
                        ? theme.colorScheme.surface
                        : index == question.correctIndex
                        ? const Color(0xFFE7F5EF)
                        : index == selected
                        ? theme.colorScheme.errorContainer.withValues(
                          alpha: .65,
                        )
                        : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: selected == null ? () => onSelect(index) : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color:
                            selected == null
                                ? theme.colorScheme.outlineVariant
                                : index == question.correctIndex
                                ? const Color(0xFF90C9AC)
                                : index == selected
                                ? theme.colorScheme.error.withValues(alpha: .45)
                                : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                selected != null &&
                                        index == question.correctIndex
                                    ? const Color(0xFF16734B)
                                    : selected == index
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.surfaceContainerHighest,
                          ),
                          child:
                              selected != null && index == question.correctIndex
                                  ? const Icon(
                                    Icons.check,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                  : selected == index
                                  ? const Icon(
                                    Icons.close,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                  : Text(
                                    String.fromCharCode(65 + index),
                                    style: theme.textTheme.labelSmall,
                                  ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            question.options[index],
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (selected != null) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  correct ? Icons.check_circle_outline : Icons.info_outline,
                  color: accent,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${correct ? 'That’s right.' : 'Not quite.'} ${question.explanation}',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onSource(question),
                icon: const Icon(Icons.menu_book_outlined, size: 17),
                label: Text(
                  question.sourcePage == null
                      ? 'Check source · ${question.sourceTitle}'
                      : 'Check source · page ${question.sourcePage}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
