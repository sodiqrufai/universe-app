import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../services/telemetry.dart';
import '../utils/upload_rules.dart';
import '../widgets/state_views.dart';
import '../widgets/app_image.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  final String? avatarUrl;
  final bool isGroup;
  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.avatarUrl,
    this.isGroup = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with WidgetsBindingObserver {
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _hasError = false;
  String? _myUserId;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmojiPicker = false;

  // --- polling -------------------------------------------------------------
  // A single self-rescheduling timer (not Timer.periodic) so requests never
  // pile up, and the delay can change: 3s while the chat is active, slower
  // when nothing has happened for a while, exponential backoff when the
  // server errors or rate-limits us, and no polling at all while the app is
  // in the background.
  static const _activeDelay = Duration(seconds: 3);
  static const _idleDelay = Duration(seconds: 10);
  static const _veryIdleDelay = Duration(seconds: 30);
  static const _maxBackoff = Duration(seconds: 60);
  static const _rateLimitFloor = Duration(seconds: 15);
  Timer? _pollTimer;
  bool _fetching = false;
  bool _appInForeground = true;
  int _consecutiveFailures = 0;
  bool _lastWasRateLimited = false;
  DateTime _lastActivity = DateTime.now();

  // --- sending -------------------------------------------------------------
  bool _sending = false;

  // --- voice notes ---------------------------------------------------------
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  // Whether this device/browser can record at all. Starts optimistic on
  // phones; checked on web (some browsers have no MediaRecorder / opus).
  bool _voiceSupported = true;
  AudioEncoder _voiceEncoder = AudioEncoder.aacLc;

  static const _emojis = [
    '😀', '😂', '😍', '🥲', '😭', '😡', '🙏', '👍', '👎', '❤️',
    '🔥', '🎉', '😴', '🤔', '😅', '😎', '🙄', '😢', '👏', '🥳',
    '🤝', '💯', '😬', '😱', '🤣', '😊', '🙌', '✅', '❌', '⚠️',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _checkVoiceSupport();
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await _fetchMessages();
    _schedulePoll();
  }

  Future<void> _checkVoiceSupport() async {
    if (!kIsWeb) return; // phones: AAC to a temp file, as before
    try {
      // Browsers record Opus (webm); AAC is not available on web.
      final ok = await _recorder.isEncoderSupported(AudioEncoder.opus);
      if (ok) {
        _voiceEncoder = AudioEncoder.opus;
      }
      if (mounted) setState(() => _voiceSupported = ok);
    } catch (_) {
      if (mounted) setState(() => _voiceSupported = false);
    }
  }

  // --- app lifecycle: pause polling in the background ----------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      // Catch up straight away, then carry on at the normal pace.
      _consecutiveFailures = 0;
      _lastWasRateLimited = false;
      _lastActivity = DateTime.now();
      _pollTimer?.cancel();
      _fetchMessages(silent: true).whenComplete(_schedulePoll);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // `inactive` is deliberately ignored: it also fires for brief system
      // overlays such as the microphone permission prompt.
      _appInForeground = false;
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Duration _nextPollDelay() {
    if (_consecutiveFailures > 0 || _lastWasRateLimited) {
      final base = _lastWasRateLimited ? _rateLimitFloor : _activeDelay;
      final exp = _consecutiveFailures > 0 ? _consecutiveFailures - 1 : 0;
      // 3s, 6s, 12s, 24s, 48s, then capped at 60s (rate limited: 15s, 30s, 60s).
      final ms = base.inMilliseconds * (1 << (exp > 5 ? 5 : exp));
      return Duration(
        milliseconds: ms > _maxBackoff.inMilliseconds ? _maxBackoff.inMilliseconds : ms,
      );
    }
    final quiet = DateTime.now().difference(_lastActivity);
    if (quiet > const Duration(minutes: 5)) return _veryIdleDelay;
    if (quiet > const Duration(minutes: 1)) return _idleDelay;
    return _activeDelay;
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!mounted || !_appInForeground) return;
    _pollTimer = Timer(_nextPollDelay(), () async {
      await _fetchMessages(silent: true);
      _schedulePoll();
    });
  }

  void _markActive() {
    final wasIdle = DateTime.now().difference(_lastActivity) > const Duration(minutes: 1);
    _lastActivity = DateTime.now();
    // Typing after a long quiet spell: don't wait out a 30s timer.
    if (wasIdle && _consecutiveFailures == 0 && !_lastWasRateLimited) _schedulePoll();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final data = await ApiService.get('/chat/${widget.conversationId}/messages');
      if (!mounted) return;
      if (data['success'] == true) {
        _consecutiveFailures = 0;
        _lastWasRateLimited = false;
        final List<dynamic> newMessages = data['messages'] ?? [];
        final changed = newMessages.length != _messages.length;
        final fromOther = changed &&
            newMessages.isNotEmpty &&
            newMessages.last['sender_id'] != _myUserId;
        if (fromOther) _lastActivity = DateTime.now();
        setState(() {
          _messages = newMessages;
          _loading = false;
          _hasError = false;
        });
        if (changed) _scrollToBottom();
      } else {
        _consecutiveFailures++;
        _lastWasRateLimited = data['rateLimited'] == true;
        if (!silent) {
          setState(() {
            _hasError = true;
            _loading = false;
          });
        }
      }
    } catch (_) {
      // A silent background poll failing shouldn't flash an error screen
      // over an otherwise-working chat: only the initial load does.
      if (!mounted) return;
      _consecutiveFailures++;
      if (!silent) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Sends a text message, optionally with a picked image or a voice note.
  /// Attachments are sent as bytes, so this works on web as well as phones.
  Future<void> _sendMessage({
    UploadFile? attachment,
    bool isAudio = false,
    int? durationSeconds,
  }) async {
    if (_sending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty && attachment == null) return;

    _messageController.clear();
    _markActive();
    setState(() => _sending = true);

    try {
      final data = await UploadApi.send(
        '/chat/${widget.conversationId}/messages',
        fields: {
          if (text.isNotEmpty) 'content': text,
          if (attachment != null && isAudio) 'mediaType': 'audio',
          if (attachment != null && isAudio && durationSeconds != null)
            'durationSeconds': durationSeconds.toString(),
        },
        files: [if (attachment != null) attachment],
      );

      if (data['success'] == true) {
        Telemetry.track('message_sent', {
          'type': attachment == null ? 'text' : (isAudio ? 'voice' : 'image'),
        });
        // A send is a sign the chat is live again: reset any backoff.
        _consecutiveFailures = 0;
        _lastWasRateLimited = false;
        await _fetchMessages(silent: true);
        _schedulePoll();
      } else if (mounted) {
        // Put the text back so nothing the student typed is lost.
        if (text.isNotEmpty && _messageController.text.isEmpty) {
          _messageController.text = text;
        }
        _toast((data['error'] ?? 'Message not sent. Please try again.').toString());
      }
    } catch (_) {
      if (mounted) {
        if (text.isNotEmpty && _messageController.text.isEmpty) {
          _messageController.text = text;
        }
        _toast('Message not sent. Please try again.');
      }
    } finally {
      // Never leave the send/attach/mic buttons disabled.
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final result = await UploadPicker.pickImage();
    if (!mounted || result.cancelled) return;
    if (result.error != null) {
      _toast(result.error!);
      return;
    }
    final file = result.file!;
    await _sendMessage(
      attachment: UploadFile(field: 'attachment', bytes: file.bytes, name: file.name),
    );
  }

  Future<void> _startRecording() async {
    if (_sending || _isRecording) return;
    if (!_voiceSupported) {
      _toast("Voice notes aren't supported in this browser.");
      return;
    }
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _toast('Microphone permission is needed to record voice notes');
        return;
      }
      if (kIsWeb) {
        // On web the recording stays in the browser; the path is ignored.
        await _recorder.start(RecordConfig(encoder: _voiceEncoder), path: '');
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      }
    } catch (_) {
      _toast("Couldn't start recording. Please check your microphone and try again.");
      return;
    }
    if (!mounted) {
      try {
        await _recorder.stop();
      } catch (_) {}
      return;
    }
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
      // The server accepts 5MB; stop a runaway recording well before that.
      if (_recordSeconds >= 120) _stopRecordingAndSend();
    });
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (mounted) setState(() => _isRecording = false);
    // Anything under a second is almost certainly an accidental tap, not a
    // real voice note: don't bother sending it.
    if (path == null || seconds < 1) return;

    try {
      // XFile reads a file path on phones and a blob URL on web.
      final x = XFile(path);
      final size = await x.length();
      final problem = UploadRules.validate(
        fileName: kIsWeb ? 'voice_note.webm' : 'voice_note.m4a',
        sizeBytes: size,
        allowed: const [UploadKind.audio],
      );
      if (problem != null) {
        _toast(problem);
        return;
      }
      final Uint8List bytes = await x.readAsBytes();
      await _sendMessage(
        attachment: UploadFile(
          field: 'attachment',
          bytes: bytes,
          name: kIsWeb ? 'voice_note.webm' : 'voice_note.m4a',
        ),
        isAudio: true,
        durationSeconds: seconds,
      );
    } catch (_) {
      _toast('Voice note not sent. Please try again.');
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _showOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                _report();
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: AppColors.error),
              title: Text('Block user', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _block();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Report this conversation'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      try {
        final data = await ApiService.post('/chat/report', {
          'conversationId': widget.conversationId,
          'reason': reason,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['success'] == true ? 'Report submitted' : (data['error'] ?? 'Could not submit report'),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not submit report')));
        }
      }
    }
  }

  Future<void> _block() async {
    final otherId = _messages
        .map((m) => m['sender_id'])
        .firstWhere((id) => id != _myUserId, orElse: () => null);
    if (otherId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Block this user?'),
        content: const Text('They will no longer be able to message you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final data = await ApiService.post('/chat/block/$otherId', {});
        if (data['success'] == true && mounted) {
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not block this user')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not block this user')));
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.lightPurple,
              backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
              child: widget.avatarUrl == null
                  ? Icon(widget.isGroup ? Icons.groups : Icons.person, size: 16, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), tooltip: 'More options', onPressed: _showOptions),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.lightPurple,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 12, color: AppColors.primary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Messages are encrypted at rest. UniVerse staff may access chats when reviewing a safety report.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildMessages()),
          if (_showEmojiPicker) _buildEmojiGrid(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _isRecording ? _buildRecordingRow() : _buildComposeRow(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeRow() {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
            color: AppColors.primary,
          ),
          tooltip: _showEmojiPicker ? 'Show keyboard' : 'Show emoji picker',
          onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
        ),
        IconButton(
          icon: Icon(Icons.image_outlined, color: AppColors.primary),
          tooltip: 'Attach image',
          onPressed: _sending ? null : _pickAndSendImage,
        ),
        Expanded(
          child: TextField(
            controller: _messageController,
            onChanged: (_) => _markActive(),
            onTap: () {
              if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
            },
            decoration: const InputDecoration(hintText: 'Type a message...'),
          ),
        ),
        // Press and hold to record, release to send: same interaction
        // pattern as WhatsApp/Telegram/iMessage. Hidden where the browser
        // can't record, so there's no button that does nothing.
        if (_voiceSupported)
          Semantics(
            label: 'Hold to record a voice note',
            button: true,
            child: GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecordingAndSend(),
              onLongPressCancel: _cancelRecording,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.mic_none, color: AppColors.primary),
              ),
            ),
          ),
        IconButton(
          icon: Icon(Icons.send, color: AppColors.primary),
          tooltip: 'Send message',
          onPressed: _sending ? null : () => _sendMessage(),
        ),
      ],
    );
  }

  Widget _buildRecordingRow() {
    return Row(
      children: [
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Recording  ${_formatDuration(Duration(seconds: _recordSeconds))}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _cancelRecording,
          child: const Text('Cancel'),
        ),
        IconButton(
          icon: Icon(Icons.send, color: AppColors.primary),
          tooltip: 'Send voice note',
          onPressed: _stopRecordingAndSend,
        ),
      ],
    );
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursor = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(cursor, cursor, emoji);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + emoji.length),
    );
  }

  Widget _buildEmojiGrid() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: _emojis.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => _insertEmoji(_emojis[i]),
          child: Center(child: Text(_emojis[i], style: const TextStyle(fontSize: 22))),
        ),
      ),
    );
  }

  void _openImageViewer(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white54),
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 60,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load this conversation', onRetry: _fetchMessages);
    }
    if (_messages.isEmpty) {
      return const EmptyView(icon: Icons.waving_hand_outlined, title: 'Say hello 👋');
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        final isMine = m['sender_id'] == _myUserId;
        final counts = Map<String, int>.from(m['reactionCounts'] ?? {'like': 0, 'love': 0});
        final myReactions = List<String>.from(m['myReactions'] ?? []);
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showReactionPicker(m['id'], index),
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: isMine ? null : Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m['attachment_url'] != null && m['media_type'] == 'audio')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _VoiceMessageBubble(
                            url: m['attachment_url'],
                            durationSeconds: m['duration_seconds'] ?? 0,
                            isMine: isMine,
                          ),
                        )
                      else if (m['attachment_url'] != null)
                        GestureDetector(
                          onTap: () => _openImageViewer(m['attachment_url']),
                          child: AppNetworkImage(
                            m['attachment_url'],
                            width: 180,
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                          ),
                        ),
                      if (m['content'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            m['content'],
                            style: TextStyle(color: isMine ? Colors.white : AppColors.textPrimary),
                          ),
                        ),
                      if (m['created_at'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('h:mm a').format(DateTime.parse(m['created_at']).toLocal()),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMine ? Colors.white70 : AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if ((counts['like'] ?? 0) > 0 || (counts['love'] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((counts['like'] ?? 0) > 0) ...[
                          Icon(
                            Icons.thumb_up,
                            size: 12,
                            color: myReactions.contains('like')
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Text('${counts['like']}', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(width: 6),
                        ],
                        if ((counts['love'] ?? 0) > 0) ...[
                          Icon(
                            Icons.favorite,
                            size: 12,
                            color: myReactions.contains('love') ? Colors.red : AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Text('${counts['love']}', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReactionPicker(String messageId, int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 32,
              icon: Icon(Icons.thumb_up, color: AppColors.primary),
              tooltip: 'React with thumbs up',
              onPressed: () {
                Navigator.pop(context);
                _reactToMessage(messageId, index, 'like');
              },
            ),
            const SizedBox(width: 24),
            IconButton(
              iconSize: 32,
              icon: const Icon(Icons.favorite, color: Colors.red),
              tooltip: 'React with heart',
              onPressed: () {
                Navigator.pop(context);
                _reactToMessage(messageId, index, 'love');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reactToMessage(String messageId, int index, String reactionType) async {
    final counts = Map<String, int>.from(_messages[index]['reactionCounts'] ?? {'like': 0, 'love': 0});
    final myReactions = List<String>.from(_messages[index]['myReactions'] ?? []);
    final wasReacted = myReactions.contains(reactionType);
    setState(() {
      if (wasReacted) {
        myReactions.remove(reactionType);
        counts[reactionType] = (counts[reactionType] ?? 1) - 1;
      } else {
        myReactions.add(reactionType);
        counts[reactionType] = (counts[reactionType] ?? 0) + 1;
      }
      _messages[index]['myReactions'] = myReactions;
      _messages[index]['reactionCounts'] = counts;
    });
    final data = await ApiService.post('/chat/messages/$messageId/react', {'reactionType': reactionType});
    if (data['success'] != true && mounted) {
      setState(() {
        final revertCounts = Map<String, int>.from(_messages[index]['reactionCounts'] ?? {});
        final revertReactions = List<String>.from(_messages[index]['myReactions'] ?? []);
        if (wasReacted) {
          revertReactions.add(reactionType);
          revertCounts[reactionType] = (revertCounts[reactionType] ?? 0) + 1;
        } else {
          revertReactions.remove(reactionType);
          revertCounts[reactionType] = (revertCounts[reactionType] ?? 1) - 1;
        }
        _messages[index]['myReactions'] = revertReactions;
        _messages[index]['reactionCounts'] = revertCounts;
      });
    }
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Play/pause button + progress bar + duration label for a voice-note
/// message bubble. Duration comes from the backend (`duration_seconds`)
/// so we never need to probe the audio file client-side just to show a
/// label — only to actually play it.
class _VoiceMessageBubble extends StatefulWidget {
  final String url;
  final int durationSeconds;
  final bool isMine;

  const _VoiceMessageBubble({
    required this.url,
    required this.durationSeconds,
    required this.isMine,
  });

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  bool _loaded = false;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing && state.processingState != ProcessingState.completed;
      setState(() => _isPlaying = playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        setState(() => _position = Duration.zero);
      }
    });
    _posSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _toggle() async {
    try {
      if (!_loaded) {
        await _player.setUrl(widget.url);
        _loaded = true;
      }
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not play this voice note')));
      }
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = Duration(seconds: widget.durationSeconds);
    final progress = total.inMilliseconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final remaining = _position > Duration.zero ? (total - _position) : total;
    final label = _formatDuration(remaining.isNegative ? Duration.zero : remaining);
    final color = widget.isMine ? Colors.white : AppColors.primary;

    return SizedBox(
      width: 180,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: color.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
