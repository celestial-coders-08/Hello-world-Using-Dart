import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../widgets/profile_avatar.dart';

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
  DateTime? _clearedAt;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _initSocket();
  }

  Future<void> _initializeChat() async {
    await _loadClearMarker();
    await _fetchMessages();
  }

  String get _clearMarkerKey =>
      'cleared_chat_${widget.userId}_${widget.conversationId}';

  Future<void> _loadClearMarker() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_clearMarkerKey);
    if (!mounted || value == null) return;
    setState(() => _clearedAt = DateTime.tryParse(value));
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
          _messages = data.cast<Map<String, dynamic>>().where((message) {
            final timestamp = DateTime.tryParse(
              message['timestamp'] as String? ?? '',
            );
            return _clearedAt == null ||
                timestamp == null ||
                timestamp.isAfter(_clearedAt!);
          }).toList();
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

  Future<void> _sendMessage({
    String? imageUrl,
    String? documentUrl,
    String? documentName,
  }) async {
    final content = _messageController.text.trim();
    if (content.isEmpty && imageUrl == null && documentUrl == null) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final nowIso = DateTime.now().toIso8601String();
    final optimistic = <String, dynamic>{
      'id': -1,
      'conversation_id': widget.conversationId,
      'sender_id': widget.userId,
      'content': content,
      'image_url': imageUrl,
      'document_url': documentUrl,
      'document_name': documentName,
      'timestamp': nowIso,
      'is_read': false,
    };

    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    final payload = <String, dynamic>{
      'conversation_id': widget.conversationId,
      'sender_id': widget.userId,
      'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
      if (documentUrl != null) 'document_url': documentUrl,
      if (documentName != null) 'document_name': documentName,
    };

    final isSocketConnected = _socket != null && (_socket!.connected == true);

    if (isSocketConnected) {
      // Send via real-time Socket.IO ONLY
      try {
        _socket?.emit('send_message', payload);
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
              body: jsonEncode(payload),
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
                ProfileAvatar(
                  name: widget.contactName,
                  imageValue: widget.contactAvatarUrl,
                  radius: 20,
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
            onPressed: _showChatMenu,
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
                      final documentUrl = msg['document_url'] as String?;
                      final documentName = msg['document_name'] as String?;
                      return _MessageBubble(
                        content: msg['content'] as String? ?? '',
                        imageUrl: imageUrl,
                        documentUrl: documentUrl,
                        documentName: documentName,
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

  Future<void> _showChatMenu() async {
    final shouldClear = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: const Text('Clear chat'),
          onTap: () => Navigator.pop(sheetContext, true),
        ),
      ),
    );
    if (shouldClear != true || !mounted) return;

    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    await preferences.setString(_clearMarkerKey, now.toIso8601String());
    if (!mounted) return;
    setState(() {
      _clearedAt = now;
      _messages.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat cleared on this device.')),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0D5CE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Send Attachment',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C2420),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Image Option
                    _buildAttachmentOption(
                      icon: Icons.image_rounded,
                      color: const Color(0xFFCA6347),
                      bgColor: const Color(0xFFFBF0ED),
                      label: 'Image',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendImage();
                      },
                    ),
                    // Document Option
                    _buildAttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      color: const Color(0xFF2B7A78),
                      bgColor: const Color(0xFFEBF5F5),
                      label: 'Document',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendDocument();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C2420),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _sendMessage(imageUrl: base64Str);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? file;
      try {
        file = await picker.pickMedia();
      } catch (_) {
        file = await picker.pickImage(source: ImageSource.gallery);
      }
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64Str =
            'data:application/octet-stream;base64,${base64Encode(bytes)}';
        final name = file.name;
        final documentName =
            (name.endsWith('.pdf') ||
                name.endsWith('.doc') ||
                name.endsWith('.docx') ||
                name.endsWith('.txt'))
            ? name
            : 'Document_${DateTime.now().millisecondsSinceEpoch}.${name.contains('.') ? name.split('.').last : 'pdf'}';
        _sendMessage(documentUrl: base64Str, documentName: documentName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach document: $e')),
        );
      }
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                  // Attachment icon (opens modal with Image & Document)
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: Color(0xFFBBA8A0),
                      size: 22,
                    ),
                    onPressed: _showAttachmentOptions,
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
            onTap: _isSending ? null : () => _sendMessage(),
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
  final String? documentUrl;
  final String? documentName;
  final bool isMine;
  final String time;

  const _MessageBubble({
    required this.content,
    this.imageUrl,
    this.documentUrl,
    this.documentName,
    required this.isMine,
    required this.time,
  });

  Widget _buildImageWidget(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Bytes = base64Decode(url.split(',').last);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Bytes,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          color: Colors.black.withValues(alpha: 0.05),
          child: const Center(
            child: Icon(Icons.image_not_supported_rounded, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentWidget(
    BuildContext context,
    String? docUrl,
    String? docName,
  ) {
    final name = (docName != null && docName.isNotEmpty)
        ? docName
        : 'Document.pdf';
    final isPdf = name.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFF3EBE4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? Colors.white.withValues(alpha: 0.3)
              : const Color(0xFFE6D7CD),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPdf
                  ? const Color(0xFFE53935).withValues(alpha: 0.2)
                  : const Color(0xFF1976D2).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
              color: isPdf ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMine ? Colors.white : const Color(0xFF2C2420),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Document',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF8D7B74),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              Icons.download_rounded,
              color: isMine ? Colors.white : const Color(0xFFCA6347),
              size: 20,
            ),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Opening $name...')));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final hasDoc =
        (documentUrl != null && documentUrl!.isNotEmpty) ||
        (documentName != null && documentName!.isNotEmpty);

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
              maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                if (hasImage) ...[
                  _buildImageWidget(imageUrl!),
                  if (content.isNotEmpty || hasDoc) const SizedBox(height: 8),
                ],
                if (hasDoc) ...[
                  _buildDocumentWidget(context, documentUrl, documentName),
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
