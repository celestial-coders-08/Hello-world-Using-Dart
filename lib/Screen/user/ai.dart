import 'package:flutter/material.dart';

import '../assistant/assistant_chat_screen.dart';
import 'contact_support_screen.dart';
import 'doctor_screen.dart';
import 'food_screen.dart';
import 'pet_map_screen.dart';
import 'your_orders_screen.dart';

class AI extends StatelessWidget {
  final String? userLookup;

  const AI({super.key, this.userLookup});

  @override
  Widget build(BuildContext context) => AssistantChatScreen(
    role: 'user',
    userId: userLookup?.trim().isNotEmpty == true
        ? userLookup!.trim()
        : 'guest-user',
    onNavigate: (action) {
      final screen = switch (action) {
        AssistantAction.nearbyMap => const PetMapScreen(),
        AssistantAction.callHospital => DoctorScreen(userLookup: userLookup),
        AssistantAction.trackOrders => const YourOrdersScreen(),
        AssistantAction.support => const ContactSupportScreen(),
        AssistantAction.foodFilters => FoodScreen(userLookup: userLookup),
        _ => null,
      };
      if (screen != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen));
      }
    },
  );
}
