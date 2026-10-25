import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ai_assistant_service.dart';
import '../../theme/pawstay_theme.dart';

enum AssistantAction {
  nearbyMap,
  callHospital,
  trackOrders,
  support,
  foodFilters,
  dietPlan,
  rating,
  totalSales,
  todaySales,
  salesTips,
  totalOrders,
  todayOrders,
}

class AssistantChatScreen extends StatefulWidget {
  final String role;
  final String userId;
  final ValueChanged<AssistantAction>? onNavigate;

  const AssistantChatScreen({
    super.key,
    required this.role,
    required this.userId,
    this.onNavigate,
  });

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantMessage {
  const _AssistantMessage({
    required this.text,
    required this.isUser,
    this.model,
  });

  final String text;
  final bool isUser;
  final String? model;
}

class _ActionItem {
  const _ActionItem(this.label, this.prompt, {this.action});

  final String label;
  final String prompt;
  final AssistantAction? action;
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [];
  bool _isSending = false;
  bool _isLoadingHistory = true;

  String get _title => widget.role == 'seller'
      ? 'Seller AI Assistant'
      : widget.role == 'provider'
      ? 'Provider AI Assistant'
      : 'PawStay AI Assistant';

  List<_ActionItem> get _actions {
    if (widget.role == 'seller') {
      return const [
        _ActionItem(
          'Total sales',
          'What are my total sales?',
          action: AssistantAction.totalSales,
        ),
        _ActionItem(
          "Today's sales",
          'How much did I sell today?',
          action: AssistantAction.todaySales,
        ),
        _ActionItem(
          'Sales tips',
          'How can I increase my sales?',
          action: AssistantAction.salesTips,
        ),
        _ActionItem(
          'Total orders',
          'How many total orders do I have?',
          action: AssistantAction.totalOrders,
        ),
        _ActionItem(
          "Today's orders",
          'How many orders did I receive today?',
          action: AssistantAction.todayOrders,
        ),
        _ActionItem(
          'Support & help',
          'How can I get help with my PawStay seller account?',
        ),
      ];
    }
    return [
      _ActionItem(
        'Nearby me',
        'Open the nearby services map.',
        action: AssistantAction.nearbyMap,
      ),
      _ActionItem(
        'Call hospital',
        'Find a nearby pet hospital.',
        action: AssistantAction.callHospital,
      ),
      _ActionItem(
        'Track orders',
        'Open my orders so I can track them.',
        action: AssistantAction.trackOrders,
      ),
      _ActionItem(
        'Food filters',
        'Open pet food so I can filter by food and price.',
        action: AssistantAction.foodFilters,
      ),
      const _ActionItem(
        'Diet plan',
        'Create a safe pet diet plan. Ask me whether it is for a cat, dog, or other pet and what its age, weight, and needs are.',
        action: AssistantAction.dietPlan,
      ),
      const _ActionItem(
        'Support & help',
        'Open PawStay support.',
        action: AssistantAction.support,
      ),
      if (widget.role == 'provider')
        const _ActionItem(
          'My rating',
          'Open my provider ratings.',
          action: AssistantAction.rating,
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await AiAssistantService.fetchHistory(
        role: widget.role,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(
          history.map(
            (message) => _AssistantMessage(
              text: message['content']?.toString() ?? '',
              isUser: message['sender'] == 'user',
              model: message['model']?.toString(),
            ),
          ),
        );
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
      _showError(error);
    }
  }

  Future<void> _handleAction(_ActionItem item) async {
    if (_isSending) return;
    final action = item.action;
    if (action == AssistantAction.trackOrders) {
      await _sendMessage(item.prompt);
      return;
    }
    if (action != null &&
        action != AssistantAction.dietPlan &&
        widget.onNavigate != null) {
      widget.onNavigate!(action);
      return;
    }
    await _sendMessage(item.prompt);
  }

  Future<void> _sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isSending || _isLoadingHistory) return;

    setState(() => _isSending = true);
    try {
      final response = await AiAssistantService.sendMessage(
        role: widget.role,
        userId: widget.userId,
        message: prompt,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _messages.add(_AssistantMessage(text: prompt, isUser: true));
        _messages.add(
          _AssistantMessage(
            text: response['reply']!,
            isUser: false,
            model: response['model'],
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showError(error);
    }
  }

  void _showError(Exception error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Exception: ', ''),
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: PawStayTheme.primary,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: PawStayTheme.primary,
              radius: 15,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              _title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              itemCount: _actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final item = _actions[index];
                return ActionChip(
                  avatar: const Icon(
                    Icons.bolt,
                    size: 15,
                    color: PawStayTheme.primary,
                  ),
                  label: Text(
                    item.label,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                  ),
                  onPressed: _isSending || _isLoadingHistory
                      ? null
                      : () => _handleAction(item),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(
                      color: PawStayTheme.primary,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isSending && index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      final message = _messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending && !_isLoadingHistory,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: widget.role == 'seller'
                          ? 'Ask about sales, orders, or support...'
                          : 'Ask PawStay AI...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: PawStayTheme.primary,
                  child: IconButton(
                    tooltip: 'Send message',
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _isSending || _isLoadingHistory
                        ? null
                        : () => _sendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.isUser
              ? PawStayTheme.primary
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: assistantBoldMarkdownSpans(message.text)),
              style: GoogleFonts.plusJakartaSans(
                color: message.isUser ? Colors.white : colors.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<TextSpan> assistantBoldMarkdownSpans(String text) {
  final spans = <TextSpan>[];
  final boldPattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  var offset = 0;
  for (final match in boldPattern.allMatches(text)) {
    if (match.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    offset = match.end;
  }
  if (offset < text.length || spans.isEmpty) {
    spans.add(TextSpan(text: text.substring(offset)));
  }
  return spans;
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(width: 24, height: 18, child: _PulsingDots()),
      ),
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        final phase = (_controller.value * 3 - index).abs().clamp(0.0, 1.0);
        return Opacity(
          opacity: 0.35 + (1 - phase) * 0.65,
          child: const CircleAvatar(
            radius: 3,
            backgroundColor: PawStayTheme.primary,
          ),
        );
      }),
    ),
  );
}
