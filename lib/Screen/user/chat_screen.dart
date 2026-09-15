import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../theme/pawstay_theme.dart';
import 'chat_detail_screen.dart';
import '../../widgets/profile_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String? userLookup;
  final VoidCallback? onBackPressed;

  const ChatScreen({super.key, this.userLookup, this.onBackPressed});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0 = Chat, 1 = Start Chat
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;
  bool _isLoadingCandidates = false;
  final Map<int, DateTime> _clearedAtByConversation = <int, DateTime>{};

  String get _userId => widget.userLookup ?? 'demo_user';

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() async {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _filtered = List.from(_conversations);
        });
      }
      return;
    }

    try {
      final url =
          '${ApiConfig.baseUrl}/users/search?q=${Uri.encodeQueryComponent(q)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _filtered = data
                .map(
                  (u) => {
                    'id': -1,
                    'contact_id': u['username'] ?? u['email'],
                    'contact_name': u['full_name'],
                    'contact_avatar_url': u['profile_image'],
                    'last_message': 'Tap to start conversation',
                    'last_message_time': '',
                    'unread_count': 0,
                  },
                )
                .toList()
                .cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _filtered = _conversations.where((c) {
            final name = (c['contact_name'] ?? '').toString().toLowerCase();
            return name.contains(q);
          }).toList();
        });
      }
    }
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final url =
          '${ApiConfig.messageBaseUrl}/conversations?user_id=${Uri.encodeQueryComponent(_userId)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final preferences = await SharedPreferences.getInstance();
        final clearedAt = <int, DateTime>{};
        for (final conversation in data.cast<Map<String, dynamic>>()) {
          final conversationId = conversation['id'] as int;
          final marker = preferences.getString(
            'cleared_chat_${_userId}_$conversationId',
          );
          final parsedMarker = marker == null
              ? null
              : DateTime.tryParse(marker);
          if (parsedMarker != null) {
            clearedAt[conversationId] = parsedMarker;
          }
        }
        if (mounted) {
          setState(() {
            _clearedAtByConversation
              ..clear()
              ..addAll(clearedAt);
            _conversations = data.cast<Map<String, dynamic>>();
            _filtered = List.from(_conversations);
          });
        }
      }
    } catch (_) {
      // Network error — show empty state
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isConversationCleared(Map<String, dynamic> conversation) {
    final clearedAt = _clearedAtByConversation[conversation['id'] as int];
    if (clearedAt == null) return false;
    final lastMessage = DateTime.tryParse(
      conversation['last_message_time'] as String? ?? '',
    );
    return lastMessage == null || !lastMessage.isAfter(clearedAt);
  }

  Future<void> _fetchCandidates() async {
    setState(() => _isLoadingCandidates = true);
    try {
      final url =
          '${ApiConfig.baseUrl}/users/chat-candidates?user_id=${Uri.encodeQueryComponent(_userId)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _candidates = data.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingCandidates = false);
    }
  }

  Future<void> _startChatWithCandidate(Map<String, dynamic> c) async {
    final contactId =
        c['username'] != null && c['username'].toString().isNotEmpty
        ? c['username']
        : (c['email'] ?? c['id'].toString());
    final contactName = c['full_name'] ?? 'User';
    final contactAvatar = c['profile_image'];

    final url = '${ApiConfig.messageBaseUrl}/conversations';
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'contact_id': contactId,
          'contact_name': contactName,
          'contact_avatar_url': contactAvatar,
        }),
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        final convId = d['id'] as int;
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              conversationId: convId,
              contactName: contactName,
              contactAvatarUrl: contactAvatar,
              userId: _userId,
            ),
          ),
        );
        _fetchConversations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
      }
    }
  }

  /// Format ISO timestamp to a friendly label:
  ///  - Same day  → "10:42 AM"
  ///  - Yesterday → "Yesterday"
  ///  - Within week → "Mon", "Tue" …
  ///  - Older      → "Oct 12"
  String _formatTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(msgDay).inDays;

      if (diff == 0) {
        final h = dt.hour;
        final m = dt.minute.toString().padLeft(2, '0');
        final period = h < 12 ? 'AM' : 'PM';
        final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        return '$hour:$m $period';
      } else if (diff == 1) {
        return 'Yesterday';
      } else if (diff < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[dt.month - 1]} ${dt.day}';
      }
    } catch (_) {
      return '';
    }
  }

  bool _isToday(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return false;
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: PawStayTheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: widget.onBackPressed,
              )
            : null,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, color: PawStayTheme.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'PawStay',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: PawStayTheme.primaryContainer,
              child: const Icon(
                Icons.person,
                color: PawStayTheme.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4EDE8),
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF9E7B6B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF9E7B6B),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Chat / Request Toggle ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE3DB),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: _selectedTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Chat',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: _selectedTab == 0
                                  ? PawStayTheme.primary
                                  : const Color(0xFF9E7B6B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedTab = 1);
                        _fetchCandidates();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: _selectedTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Start Chat',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: _selectedTab == 1
                                  ? PawStayTheme.primary
                                  : const Color(0xFF9E7B6B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conversation List ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: PawStayTheme.primary,
                    ),
                  )
                : _selectedTab == 1
                ? _buildStartChatList()
                : _filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchConversations,
                    color: PawStayTheme.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 78,
                        endIndent: 16,
                        color: PawStayTheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final conv = _filtered[index];
                        return _ConversationTile(
                          conversation: conv,
                          isCleared: _isConversationCleared(conv),
                          timeLabel: _formatTime(
                            conv['last_message_time'] as String?,
                          ),
                          isRecent: _isToday(
                            conv['last_message_time'] as String?,
                          ),
                          onTap: () async {
                            int convId = conv['id'] as int;
                            if (convId == -1) {
                              final url =
                                  '${ApiConfig.messageBaseUrl}/conversations';
                              try {
                                final resp = await http.post(
                                  Uri.parse(url),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'user_id': _userId,
                                    'contact_id': conv['contact_id'],
                                    'contact_name': conv['contact_name'],
                                    'contact_avatar_url':
                                        conv['contact_avatar_url'],
                                  }),
                                );
                                if (resp.statusCode == 201 ||
                                    resp.statusCode == 200) {
                                  final d = jsonDecode(resp.body);
                                  convId = d['id'] as int;
                                } else {
                                  return;
                                }
                              } catch (_) {
                                return;
                              }
                            }
                            if (!context.mounted) {
                              return;
                            }
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  conversationId: convId,
                                  contactName: conv['contact_name'] as String,
                                  contactAvatarUrl:
                                      conv['contact_avatar_url'] as String?,
                                  userId: _userId,
                                ),
                              ),
                            );
                            _fetchConversations();
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: PawStayTheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PawStayTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting with sitters, vets, or groomers.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: PawStayTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStartChatList() {
    if (_isLoadingCandidates) {
      return const Center(
        child: CircularProgressIndicator(color: PawStayTheme.primary),
      );
    }

    if (_candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: PawStayTheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No people found in your city',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Service providers, buyers, and doctors\nin your city will appear here.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: PawStayTheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCandidates,
      color: PawStayTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final c = _candidates[index];
          final String name = c['full_name'] ?? 'User';
          final String role = c['role'] ?? 'Member';
          final String city = c['city'] ?? '';
          final String? avatar = c['profile_image'];

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ProfileAvatar(name: name, imageValue: avatar, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EFEA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              role,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFCA6347),
                              ),
                            ),
                          ),
                          if (city.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: PawStayTheme.onSurfaceVariant,
                            ),
                            Text(
                              city,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: PawStayTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _startChatWithCandidate(c),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCA6347),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Chat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation Tile Widget
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String timeLabel;
  final bool isRecent;
  final VoidCallback onTap;
  final bool isCleared;

  const _ConversationTile({
    required this.conversation,
    required this.timeLabel,
    required this.isRecent,
    required this.onTap,
    required this.isCleared,
  });

  @override
  Widget build(BuildContext context) {
    final name = conversation['contact_name'] as String? ?? 'Unknown';
    final lastMsg = isCleared
        ? ''
        : conversation['last_message'] as String? ?? '';
    final unread = (conversation['unread_count'] as int?) ?? 0;
    final avatarUrl = conversation['contact_avatar_url'] as String?;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ──────────────────────────────────────────────
            ProfileAvatar(name: name, imageValue: avatarUrl),
            const SizedBox(width: 14),

            // ── Name + preview ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isRecent
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isRecent
                              ? PawStayTheme.primary
                              : PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: unread > 0
                                ? PawStayTheme.onSurface
                                : PawStayTheme.onSurfaceVariant,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: PawStayTheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unread',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
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
