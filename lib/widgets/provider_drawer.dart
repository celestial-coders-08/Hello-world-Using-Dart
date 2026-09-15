import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Screen/provider/provider_profile_screen.dart';
import '../Screen/user/contact_support_screen.dart';
import '../Screen/user/doctor_screen.dart';
import '../Screen/user/feedback_screen.dart';
import '../Screen/user/food_screen.dart';
import '../Screen/user/settings_screen.dart';
import '../theme/pawstay_theme.dart';
import 'profile_avatar.dart';

class ProviderDrawer extends StatelessWidget {
  final String? providerLookup;
  final String activeRoute;
  final String displayName;
  final String? profileImage;
  final VoidCallback? onRatingTap;

  const ProviderDrawer({
    super.key,
    this.providerLookup,
    this.activeRoute = 'dashboard',
    this.displayName = 'Service Provider',
    this.profileImage,
    this.onRatingTap,
  });

  void _close(BuildContext context) => Navigator.of(context).pop();

  void _open(BuildContext context, Widget screen) {
    _close(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: PawStayTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PawStay',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: PawStayTheme.primary,
                        ),
                      ),
                      Text(
                        'HOST DASHBOARD',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                children: [
                  _item(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    route: 'profile',
                    onTap: () => _open(
                      context,
                      ProviderProfileScreen(providerLookup: providerLookup),
                    ),
                  ),
                  _item(
                    context,
                    icon: Icons.star_border_rounded,
                    title: 'Your Rating',
                    route: 'rating',
                    onTap: () {
                      _close(context);
                      onRatingTap?.call();
                    },
                  ),
                  _item(
                    context,
                    icon: Icons.medical_services_outlined,
                    title: 'Call Doctor',
                    route: 'doctor',
                    onTap: () => _open(
                      context,
                      DoctorScreen(userLookup: providerLookup),
                    ),
                  ),
                  _item(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Order Pet Food',
                    route: 'food',
                    onTap: () =>
                        _open(context, FoodScreen(userLookup: providerLookup)),
                  ),
                  _item(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Contact & Support',
                    route: 'support',
                    onTap: () => _open(context, const ContactSupportScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    route: 'settings',
                    onTap: () => _open(
                      context,
                      SettingsScreen(userLookup: providerLookup),
                    ),
                  ),
                  _item(
                    context,
                    icon: Icons.rate_review_outlined,
                    title: 'Feedback',
                    route: 'feedback',
                    onTap: () => _open(
                      context,
                      FeedbackScreen(userLookup: providerLookup),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Row(
                children: [
                  ProfileAvatar(
                    name: displayName,
                    imageValue: profileImage,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required VoidCallback onTap,
  }) {
    final selected = activeRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        minLeadingWidth: 25,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: selected ? PawStayTheme.primary : null,
        leading: Icon(
          icon,
          size: 19,
          color: selected ? Colors.white : PawStayTheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : PawStayTheme.onSurface,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
