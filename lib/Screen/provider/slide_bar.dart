import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/pawstay_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../user/contact_support_screen.dart';
import 'provider_profile_screen.dart';

class ProviderSlideBar extends StatelessWidget {
  final String? providerLookup;
  final String activeRoute;
  final String displayName;
  final String? profileImage;
  final VoidCallback? onRatingTap;

  const ProviderSlideBar({
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PawStayTheme.themeNotifier,
      builder: (context, _, child) => Theme(
        data: PawStayTheme.providerTheme,
        child: Drawer(
          backgroundColor: const Color(0xFFFFF9F6),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                    children: [
                      _buildItem(
                        context,
                        icon: Icons.person_outline_rounded,
                        title: 'Profile',
                        route: 'profile',
                        onTap: () => _open(
                          context,
                          ProviderProfileScreen(providerLookup: providerLookup),
                        ),
                      ),
                      _buildItem(
                        context,
                        icon: Icons.star_border_rounded,
                        title: 'Your Rating',
                        route: 'rating',
                        onTap: () {
                          _close(context);
                          onRatingTap?.call();
                        },
                      ),
                      _buildItem(
                        context,
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Contact & Support',
                        route: 'support',
                        onTap: () =>
                            _open(context, const ContactSupportScreen()),
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
                            color: const Color(0xFF3B2B27),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      color: const Color(0xFFCA6347),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PawStay',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Pet Care & Services',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: selected ? const Color(0xFFF2E1D9) : null,
        leading: Icon(
          icon,
          size: 20,
          color: selected ? PawStayTheme.primary : const Color(0xFF604D46),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? PawStayTheme.primary : const Color(0xFF3B2B27),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
