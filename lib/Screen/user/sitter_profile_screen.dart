import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/pawstay_theme.dart';
import 'chat_detail_screen.dart';
import 'pet_walking_screen.dart';

class SitterProfileScreen extends StatelessWidget {
  final PetWalker walker;
  final String? userLookup;

  const SitterProfileScreen({super.key, required this.walker, this.userLookup});

  Future<void> _openChat(BuildContext context) async {
    final currentUser = userLookup?.trim();
    if (currentUser == null || currentUser.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before starting a chat.')),
      );
      return;
    }

    final providerId = walker.username.trim().isNotEmpty
        ? walker.username.trim()
        : walker.id.toString();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.messageBaseUrl}/conversations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': currentUser,
          'contact_id': providerId,
          'contact_name': walker.fullName,
          'contact_avatar_url': walker.profileImage,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Unable to start conversation');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final conversationId = (data['id'] as num).toInt();
      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: conversationId,
            contactName: walker.fullName,
            contactAvatarUrl: walker.profileImage,
            userId: currentUser,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFF9F6);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: bg,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                leadingWidth: 52,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: PawStayTheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                centerTitle: true,
                title: Text(
                  'Sitter Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.primary,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: () {},
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.ios_share_rounded,
                          size: 18,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildHeader(context),
                      const SizedBox(height: 22),
                      _buildServicesSection(),
                      // Bottom padding for the sticky button
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky bottom "Chat with Sitter" button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(context).padding.bottom + 14,
              ),
              child: ElevatedButton.icon(
                onPressed: () => _openChat(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(
                  'Chat with Sitter',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PawStayTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFF0E6E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Profile photo with verified badge
            Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF0E6E0),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(child: _buildAvatar(size: 88)),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: PawStayTheme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Name
            Text(
              walker.fullName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            // Email
            Text(
              walker.email,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 12),

            // Rating + Super Sitter badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCF0EB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8CCBF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: PawStayTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '4.9 (128 Reviews)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PawStayTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (walker.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: PawStayTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Super Sitter',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PawStayTheme.secondary,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Description / Bio
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF2EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                walker.providerDescription?.trim().isNotEmpty == true
                    ? walker.providerDescription!.trim()
                    : 'No provider description available.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: PawStayTheme.onSurface,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    final walkPrice = walker.walkingCharge;
    final daycarePrice = walker.daycareCharge;
    final daycareFoodPrice = walker.daycareFoodCharge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services & Pricing',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PawStayTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          icon: Icons.directions_walk_rounded,
          iconColor: const Color(0xFFB85C38),
          iconBg: const Color(0xFFFCEEE8),
          title: 'Pet Walking',
          subtitle: null,
          price: walkPrice != null ? '₹$walkPrice' : 'Not set',
          unit: '/walk',
        ),
        const SizedBox(height: 10),
        _buildServiceCard(
          icon: Icons.wb_sunny_rounded,
          iconColor: const Color(0xFFC07B3B),
          iconBg: const Color(0xFFFCF3E8),
          title: 'Day Care',
          subtitle: 'Provider pricing not provided.',
          price: daycarePrice != null ? '₹$daycarePrice' : 'Not set',
          unit: '/day',
        ),
        const SizedBox(height: 10),
        _buildServiceCard(
          icon: Icons.restaurant_menu_rounded,
          iconColor: const Color(0xFFB05030),
          iconBg: const Color(0xFFF5E8E2),
          title: 'Day Care + Food',
          subtitle: 'Provider pricing not provided.',
          price: daycareFoodPrice != null ? '₹$daycareFoodPrice' : 'Not set',
          unit: '/day',
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String? subtitle,
    required String price,
    required String unit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E6E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: PawStayTheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PawStayTheme.primary,
                ),
              ),
              Text(
                unit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: PawStayTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required double size}) {
    if (walker.profileImage != null && walker.profileImage!.trim().isNotEmpty) {
      try {
        final raw = walker.profileImage!;
        final bytes = base64Decode(
          raw.contains(',') ? raw.split(',').last : raw,
        );
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsAvatar(size),
        );
      } catch (_) {}
    }
    return _initialsAvatar(size);
  }

  Widget _initialsAvatar(double size) {
    final initial = walker.fullName.trim().isNotEmpty
        ? walker.fullName[0].toUpperCase()
        : 'S';
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFFCEEE8),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          color: PawStayTheme.primary,
        ),
      ),
    );
  }
}
