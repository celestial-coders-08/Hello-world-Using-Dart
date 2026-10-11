import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/pawstay_theme.dart';

class SellerAiAssistantScreen extends StatefulWidget {
  final String sellerLookup;

  const SellerAiAssistantScreen({super.key, required this.sellerLookup});

  @override
  State<SellerAiAssistantScreen> createState() =>
      _SellerAiAssistantScreenState();
}

class _SellerAiAssistantScreenState extends State<SellerAiAssistantScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Hello! I am your PawStay AI Assistant. 🐾\nI can help you write pet descriptions, set optimal pricing, understand verification rules, or manage order requests. How can I assist your business today?',
      'time': 'Just now',
    },
  ];

  final List<String> _quickPrompts = [
    'How do I price my Pet Food item?',
    'What documents are needed for Shop Verification?',
    'Tips to write a attractive Pet description',
    'What are the health reporting rules?',
  ];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMessage = text.trim();
    _messageController.clear();

    setState(() {
      _messages.add({'isUser': true, 'text': userMessage, 'time': 'Just now'});
    });

    _scrollToBottom();

    // Generate simulated AI Response tailored to PawStay Seller rules
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      String aiResponse = _getAiResponse(userMessage);

      setState(() {
        _messages.add({
          'isUser': false,
          'text': aiResponse,
          'time': 'Just now',
        });
      });

      _scrollToBottom();
    });
  }

  String _getAiResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('price') || lower.contains('pricing')) {
      return '💰 **Pricing Recommendation**:\n- Standard Pet breeds: Compare local market rates.\n- Pet Food & Accessories: Ensure you list standard MRP or slight discount.\n- Note: Shop Owners can sell food & items, while Individual Sellers can only list Pets.';
    } else if (lower.contains('document') ||
        lower.contains('verify') ||
        lower.contains('shop')) {
      return '📜 **Verification Rules**:\n1. **Aadhaar Card**: Upload clear photo (< 1 MB).\n2. **Shop Owners**: Upload Government issued shop license / address proof (< 1 MB).\n3. **Live Face Check**: Follow live camera prompts (Left, Right, Blink) and click photo.';
    } else if (lower.contains('description') || lower.contains('attrac')) {
      return '✨ **Description Tip**:\n- State breed name, age, gender & vaccination status.\n- If any health issue exists, toggle the health issue field and explain clearly to buyers.\n- Include minimum 3 to maximum 5 high-quality images.';
    } else if (lower.contains('health')) {
      return '🏥 **Health Issue Guidelines**:\n- PawStay requires full transparency. Always specify any known allergies, chronic conditions, or special care required for pets before publishing your listing.';
    } else {
      return '🤖 Thank you for asking! As your PawStay AI Assistant, I recommend uploading clear documents under 1 MB, capturing at least 3 pet photos, and keeping your product stock updated.';
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
              radius: 14,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              'PawStay AI Assistant',
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
          // Quick Prompts Horizontal Bar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: colors.surfaceContainerLow,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  avatar: const Icon(
                    Icons.bolt,
                    size: 14,
                    color: PawStayTheme.primary,
                  ),
                  label: Text(
                    prompt,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                  ),
                  onPressed: () => _sendMessage(prompt),
                );
              },
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] == true;

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? PawStayTheme.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'],
                          style: GoogleFonts.plusJakartaSans(
                            color: isUser ? Colors.white : colors.onSurface,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            msg['time'],
                            style: GoogleFonts.plusJakartaSans(
                              color: isUser
                                  ? Colors.white70
                                  : colors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Bar
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
                    decoration: InputDecoration(
                      hintText: 'Ask AI anything about selling...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: PawStayTheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(_messageController.text),
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
