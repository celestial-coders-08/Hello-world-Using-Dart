import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../config/api_config.dart';

class ChatDetailScreen extends StatefulWidget {
  final int conversationId;
  final String contactName;
  final String? contactAvatarUrl;
  final String userId;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    required this.userId,
    this.contactAvatarUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _initSocket();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initSocket() {
    try {
      _socket = io.io(
        ApiConfig.messageBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .build(),
      );

      _socket?.connect();

      _socket?.onConnect((_) {
        debugPrint('[SOCKET] Connected to message microservice');
        _socket?.emit('join_room', {'conversation_id': widget.conversationId});
      });

      _socket?.on('new_message', (data) {
        if (data != null && data['conversation_id'] == widget.conversationId) {
          if (mounted) {
            setState(() {
              final msgId = data['id'];
              final bool exists = _messages.any((m) => m['id'] == msgId);
              if (!exists) {
                // If last message was optimistic with id -1, replace or append
                if (_messages.isNotEmpty &&
                    _messages.last['id'] == -1 &&
                    _messages.last['sender_id'] == data['sender_id']) {
                  _messages[_messages.length - 1] =
                      data as Map<String, dynamic>;
                } else {
                  _messages.add(data as Map<String, dynamic>);
                }
              }
            });
            _scrollToBottom();
          }
        }
      });
    } catch (e) {
      debugPrint('[SOCKET] Socket initialization error: $e');
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final url =
          '${ApiConfig.messageBaseUrl}/conversations/${widget.conversationId}/messages';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _messages = data.cast<Map<String, dynamic>>();
        });
        _scrollToBottom();

        _markRead();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await http.patch(
        Uri.parse(
          '${ApiConfig.messageBaseUrl}/conversations/${widget.conversationId}/messages/read'
          '?user_id=${Uri.encodeQueryComponent(widget.userId)}',
        ),
      );
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final nowIso = DateTime.now().toIso8601String();
    final optimistic = {
      'id': -1,
      'conversation_id': widget.conversationId,
      'sender_id': widget.userId,
      'content': content,
      'timestamp': nowIso,
      'is_read': false,
    };

    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    final isSocketConnected = _socket != null && (_socket!.connected == true);

    if (isSocketConnected) {
      // Send via real-time Socket.IO ONLY
      try {
        _socket?.emit('send_message', {
          'conversation_id': widget.conversationId,
          'sender_id': widget.userId,
          'content': content,
        });
      } catch (e) {
        debugPrint('[SOCKET] Error emitting message: $e');
      }
    } else {
      // Fallback to REST endpoint ONLY if Socket.IO is disconnected
      try {
        final url =
            '${ApiConfig.messageBaseUrl}/conversations/${widget.conversationId}/messages';
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'sender_id': widget.userId,
                'content': content,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 201 && mounted) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          setState(() {
            if (_messages.isNotEmpty && _messages.last['id'] == -1) {
              _messages[_messages.length - 1] = data;
            }
          });
          _scrollToBottom();
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _isSending = false);
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

  String _formatBubbleTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h < 12 ? 'AM' : 'PM';
      final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour:$m $period';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5F0), // Warm off-white background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2C2420),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF3EBE4),
                  backgroundImage:
                      widget.contactAvatarUrl != null &&
                          widget.contactAvatarUrl!.isNotEmpty
                      ? NetworkImage(widget.contactAvatarUrl!)
                      : null,
                  child:
                      widget.contactAvatarUrl == null ||
                          widget.contactAvatarUrl!.isEmpty
                      ? Text(
                          widget.contactName.isNotEmpty
                              ? widget.contactName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFCA6347),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: const Color(0xFF2C2420),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Active now',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF8D7B74),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF2C2420),
              size: 24,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Date Pill Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EBE4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Today',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8D7B74),
                ),
              ),
            ),
          ),

          // ── Messages List ───────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFCA6347)),
                  )
                : _messages.isEmpty
                ? _buildEmptyThread()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg['sender_id'] == widget.userId;
                      final imageUrl = msg['image_url'] as String?;
                      return _MessageBubble(
                        content: msg['content'] as String? ?? '',
                        imageUrl: imageUrl,
                        isMine: isMine,
                        time: _formatBubbleTime(msg['timestamp'] as String?),
                      );
                    },
                  ),
          ),

          // ── Bottom Input Row ─────────────────────────────────────────
          _buildInputRow(),
        ],
      ),
    );
  }

  Widget _buildEmptyThread() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.waving_hand_rounded,
            size: 52,
            color: Color(0xFFCA6347),
          ),
          const SizedBox(height: 16),
          Text(
            'Say hello! 👋',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C2420),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with ${widget.contactName}.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF8D7B74),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      color: const Color(0xFFFAF5F0),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Pill input field ──────────────────────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Emoji icon
                  IconButton(
                    icon: const Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: Color(0xFFBBA8A0),
                      size: 24,
                    ),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    splashRadius: 20,
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFBBA8A0),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        color: const Color(0xFF2C2420),
                      ),
                    ),
                  ),
                  // Attachment icon
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: Color(0xFFBBA8A0),
                      size: 22,
                    ),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Circular send button ──────────────────────────────────
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFCA6347),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCA6347).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble Widget
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String content;
  final String? imageUrl;
  final bool isMine;
  final String time;

  const _MessageBubble({
    required this.content,
    this.imageUrl,
    required this.isMine,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isMine
                  ? const Color(0xFFCA6347) // Terracotta bubble for user
                  : Colors.white, // White card for other party
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isMine
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
                bottomRight: isMine
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                  ),
                  if (content.isNotEmpty) const SizedBox(height: 8),
                ],
                if (content.isNotEmpty)
                  Text(
                    content,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      color: isMine ? Colors.white : const Color(0xFF2C2420),
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF9E8B83),
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.done_all_rounded,
                  size: 15,
                  color: Color(0xFFCA6347),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
