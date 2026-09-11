import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/pawstay_theme.dart';
import '../Screen/user/home.dart';
import '../Screen/user/doctor_screen.dart';
import '../Screen/user/food_screen.dart';
import '../Screen/user/profile_screen.dart';
import '../Screen/user/settings_screen.dart';
import '../Screen/user/feedback_screen.dart';
import '../Screen/user/contact_support_screen.dart';

class AppDrawer extends StatelessWidget {
  final String? userLookup;
  final String activeRoute;

  const AppDrawer({super.key, this.userLookup, this.activeRoute = 'home'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 50,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C1911), const Color(0xFF422115)]
                    : [PawStayTheme.primary, PawStayTheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
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
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Pet Care & Services',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(
                      PawStayTheme.radiusDefault,
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: PawStayTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          userLookup != null && userLookup!.isNotEmpty
                              ? userLookup!
                              : 'Pet Parent User',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PawStayTheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _buildSectionHeader(context, 'APP FEATURES'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.home_rounded,
                  title: 'Home Dashboard',
                  isSelected: activeRoute == 'home',
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != 'home') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(userLookup: userLookup),
                        ),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.medical_services_rounded,
                  title: 'Doctor & Vet Care',
                  badge: '24/7 Hotline',
                  badgeColor: PawStayTheme.errorContainer,
                  badgeTextColor: PawStayTheme.onErrorContainer,
                  isSelected: activeRoute == 'doctor',
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != 'doctor') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorScreen(userLookup: userLookup),
                        ),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.restaurant_rounded,
                  title: 'Food & Nutrition',
                  badge: 'Shop Food',
                  badgeColor: PawStayTheme.secondaryContainer,
                  badgeTextColor: PawStayTheme.onSecondaryContainer,
                  isSelected: activeRoute == 'food',
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != 'food') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FoodScreen(userLookup: userLookup),
                        ),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.person_rounded,
                  title: 'My Profile',
                  isSelected: activeRoute == 'profile',
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(userLookup: userLookup ?? ''),
                        ),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.support_agent_rounded,
                  title: 'Contact & Support',
                  isSelected: activeRoute == 'support',
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != 'support') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactSupportScreen(),
                        ),
                      );
                    }
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(height: 1),
                ),

                _buildSectionHeader(context, 'PREFERENCES & HELP'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  isSelected: activeRoute == 'settings',
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(userLookup: userLookup),
                        ),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.rate_review_rounded,
                  title: 'Feedback',
                  isSelected: activeRoute == 'feedback',
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != 'feedback') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FeedbackScreen(userLookup: userLookup),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final textColor = isSelected ? activeColor : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusDefault),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          icon,
          color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor ?? theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color:
                        badgeTextColor ??
                        theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              )
            : isSelected
            ? Icon(Icons.chevron_right_rounded, color: activeColor, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }
}
