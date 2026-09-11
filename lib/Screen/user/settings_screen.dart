import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/app_drawer.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? userLookup;

  const SettingsScreen({super.key, this.userLookup});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _appointmentReminders = true;
  bool _promoEmails = false;
  bool _highContrast = false;
  bool _twoFactorAuth = false;

  String _distanceUnit = 'Miles (mi)';
  String _language = 'English (US)';

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_reset_rounded, color: PawStayTheme.primary),
            const SizedBox(width: 10),
            Text(
              'Change Password',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_clock_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPassController.text.isEmpty ||
                  newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Passwords do not match or field is empty!',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                    ),
                    backgroundColor: PawStayTheme.error,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Password updated successfully!',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                  backgroundColor: PawStayTheme.secondary,
                ),
              );
            },
            child: Text(
              'Save Password',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = PawStayTheme.themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: AppDrawer(userLookup: widget.userLookup, activeRoute: 'settings'),
      body: ListView(
        padding: const EdgeInsets.all(PawStayTheme.marginMobile),
        children: [
          // Section 1: Appearance & Theme
          _buildSectionHeader('APPEARANCE & DISPLAY'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: PawStayTheme.primary,
                  ),
                  title: Text(
                    'Dark Theme Mode',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    isDarkMode ? 'Dark UI enabled' : 'Light UI enabled',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  value: isDarkMode,
                  onChanged: (value) {
                    setState(() {
                      PawStayTheme.themeNotifier.value = value
                          ? ThemeMode.dark
                          : ThemeMode.light;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.contrast_rounded,
                    color: PawStayTheme.secondary,
                  ),
                  title: Text(
                    'High Contrast Mode',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Enhance visual text legibility',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  value: _highContrast,
                  onChanged: (val) => setState(() => _highContrast = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 2: Notifications
          _buildSectionHeader('NOTIFICATION PREFERENCES'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_active_rounded,
                    color: PawStayTheme.primary,
                  ),
                  title: Text(
                    'Push Notifications',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Get alerts for messages & sitter updates',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  value: _pushNotifications,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.alarm_rounded,
                    color: PawStayTheme.secondary,
                  ),
                  title: Text(
                    'Care & Appointment Reminders',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Reminders for vet visits & pet feeding',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  value: _appointmentReminders,
                  onChanged: (val) =>
                      setState(() => _appointmentReminders = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.local_offer_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(
                    'Promotions & Discounts',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Receive food coupon codes and seasonal offers',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  value: _promoEmails,
                  onChanged: (val) => setState(() => _promoEmails = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 3: App Preferences
          _buildSectionHeader('REGIONAL & PREFERENCES'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.straighten_rounded,
                    color: PawStayTheme.primary,
                  ),
                  title: Text(
                    'Distance Unit',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _distanceUnit,
                    underline: const SizedBox(),
                    items: ['Miles (mi)', 'Kilometers (km)']
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              u,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _distanceUnit = val);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.language_rounded,
                    color: PawStayTheme.secondary,
                  ),
                  title: Text(
                    'Language',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox(),
                    items:
                        [
                              'English (US)',
                              'Spanish (ES)',
                              'French (FR)',
                              'German (DE)',
                            ]
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(
                                  l,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _language = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 4: Account & Security
          _buildSectionHeader('ACCOUNT & SECURITY'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline_rounded,
                    color: PawStayTheme.primary,
                  ),
                  title: Text(
                    'Edit Profile Information',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userLookup: widget.userLookup ?? ''),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.lock_outline_rounded,
                    color: PawStayTheme.secondary,
                  ),
                  title: Text(
                    'Change Account Password',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.blue,
                  ),
                  title: Text(
                    'Two-Factor Authentication (2FA)',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Secure account login via OTP code',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  value: _twoFactorAuth,
                  onChanged: (val) => setState(() => _twoFactorAuth = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 5: Legal & System
          _buildSectionHeader('ABOUT & SYSTEM'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.outline,
                  ),
                  title: Text(
                    'Terms of Service',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _showLegalDialog(
                    'Terms of Service',
                    'Welcome to PawStay! By accessing our services, you agree to comply with our community guidelines, pet care safety standards, and service terms.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: theme.colorScheme.outline,
                  ),
                  title: Text(
                    'Privacy Policy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _showLegalDialog(
                    'Privacy Policy',
                    'Your data privacy is important to us. PawStay encrypts all user profiles, vet booking notes, and contact details securely.',
                  ),
                ),

                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.cleaning_services_rounded,
                    color: PawStayTheme.error,
                  ),
                  title: Text(
                    'Clear App Cache & Data',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.error,
                    ),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'App cache cleared successfully!',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: PawStayTheme.secondary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                Text(
                  'PawStay Mobile v2.4.0 (Build 108)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ for Pet Lovers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: theme.colorScheme.outline.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
