import 'package:flutter/material.dart';

import '../assistant/assistant_chat_screen.dart';
import '../user/contact_support_screen.dart';
import '../user/doctor_screen.dart';
import '../user/food_screen.dart';
import '../user/pet_map_screen.dart';
import '../user/your_orders_screen.dart';
import 'your_rating.dart';

class AI extends StatelessWidget {
  final String? providerLookup;

  const AI({super.key, this.providerLookup});

  @override
  Widget build(BuildContext context) => AssistantChatScreen(
    role: 'provider',
    userId: providerLookup?.trim().isNotEmpty == true
        ? providerLookup!.trim()
        : 'guest-provider',
    onNavigate: (action) {
      final screen = switch (action) {
        AssistantAction.nearbyMap => const PetMapScreen(),
        AssistantAction.callHospital => DoctorScreen(
          userLookup: providerLookup,
        ),
        AssistantAction.trackOrders => const YourOrdersScreen(),
        AssistantAction.support => const ContactSupportScreen(),
        AssistantAction.foodFilters => FoodScreen(userLookup: providerLookup),
        AssistantAction.rating => YourRatingScreen(
          providerLookup: providerLookup,
        ),
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
