import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
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

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _hasError = false;
  String? _myUserId;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _showEmojiPicker = false;

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  static const _emojis = [
    '😀', '😂', '😍', '🥲', '😭', '😡', '🙏', '👍', '👎', '❤️',
    '🔥', '🎉', '😴', '🤔', '😅', '😎', '🙄', '😢', '👏', '🥳',
    '🤝', '💯', '😬', '😱', '🤣', '😊', '🙌', '✅', '❌', '⚠️',
  ];

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchMessages(silent: true),
    );
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await _fetchMessages();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final data = await ApiService.get('/chat/${widget.conversationId}/messages');
      if (data['success'] == true) {
        final newMessages = data['messages'] ?? [];
        final shouldScroll = newMessages.length != _messages.length;
        setState(() {
          _messages = newMessages;
          _loading = false;
        });
        if (shouldScroll) _scrollToBottom();
      } else if (!silent) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (e) {
      // A silent background poll failing shouldn't flash an error screen
      // over an otherwise-working chat — only the initial load does.
      if (!silent) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
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

  Future<void> _sendMessage({String? imagePath, String? audioPath, int? durationSeconds}) async {
    if (_messageController.text.trim().isEmpty && imagePath == null && audioPath == null) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    // Multipart (for the optional image/voice attachment) — ApiService has no
    // file-upload method, same legitimate exception as Course's resource
    // upload, still using the same token source as everywhere else.
    try {
      final token = await SessionService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/chat/${widget.conversationId}/messages'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      if (text.isNotEmpty) request.fields['content'] = text;
      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('attachment', imagePath));
      } else if (audioPath != null) {
        request.fields['mediaType'] = 'audio';
        if (durationSeconds != null) {
          request.fields['durationSeconds'] = durationSeconds.toString();
        }
        request.files.add(await http.MultipartFile.fromPath('attachment', audioPath));
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        await _fetchMessages();
      } else if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Message not sent')),
        );
      }
    } catch (_) {
      if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message not sent — check your connection')));
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      await _sendMessage(imagePath: picked.path);
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is needed to record voice notes')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final seconds = _recordSeconds;
    if (mounted) setState(() => _isRecording = false);
    // Anything under a second is almost certainly an accidental tap, not a
    // real voice note — don't bother sending it.
    if (path != null && seconds >= 1) {
      await _sendMessage(audioPath: path, durationSeconds: seconds);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    await _recorder.stop();
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
              leading: const Icon(Icons.block, color: AppColors.error),
              title: const Text('Block user', style: TextStyle(color: AppColors.error)),
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
            child: const Row(
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
          icon: const Icon(Icons.image_outlined, color: AppColors.primary),
          tooltip: 'Attach image',
          onPressed: _pickAndSendImage,
        ),
        Expanded(
          child: TextField(
            controller: _messageController,
            onTap: () {
              if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
            },
            decoration: const InputDecoration(hintText: 'Type a message...'),
          ),
        ),
        // Press and hold to record, release to send — same interaction
        // pattern as WhatsApp/Telegram/iMessage.
        Semantics(
          label: 'Hold to record a voice note',
          button: true,
          child: GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecordingAndSend(),
            onLongPressCancel: _cancelRecording,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.mic_none, color: AppColors.primary),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send, color: AppColors.primary),
          tooltip: 'Send message',
          onPressed: () => _sendMessage(),
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
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _cancelRecording,
          child: const Text('Cancel'),
        ),
        IconButton(
          icon: const Icon(Icons.send, color: AppColors.primary),
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
      decoration: const BoxDecoration(
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
                          Text('${counts['like']}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(width: 6),
                        ],
                        if ((counts['love'] ?? 0) > 0) ...[
                          Icon(
                            Icons.favorite,
                            size: 12,
                            color: myReactions.contains('love') ? Colors.red : AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Text('${counts['love']}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
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
              icon: const Icon(Icons.thumb_up, color: AppColors.primary),
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
