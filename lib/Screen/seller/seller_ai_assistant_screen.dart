import 'package:flutter/material.dart';

import '../assistant/assistant_chat_screen.dart';

class SellerAiAssistantScreen extends StatefulWidget {
  final String sellerLookup;

  const SellerAiAssistantScreen({super.key, required this.sellerLookup});

  @override
  State<SellerAiAssistantScreen> createState() =>
      _SellerAiAssistantScreenState();
}

class _SellerAiAssistantScreenState extends State<SellerAiAssistantScreen> {
  @override
  Widget build(BuildContext context) =>
      AssistantChatScreen(role: 'seller', userId: widget.sellerLookup);
}
