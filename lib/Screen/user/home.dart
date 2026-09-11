import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../theme/pawstay_theme.dart';
import 'profile_screen.dart';
import 'add_pet_screen.dart';
import 'pet_map_screen.dart';
import 'chat_screen.dart';
import 'pet_walking_screen.dart';

import 'shop_screen.dart';
import 'doctor_screen.dart';
import 'food_screen.dart';
import '../../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  final String? userLookup;

  const HomeScreen({super.key, this.userLookup});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  String _displayName = 'Pet Parent';
  bool _isLoadingUser = false;
  String? _userProfileImageBase64;
  final TextEditingController _searchController = TextEditingController();

  /// Returns a greeting based on the current hour.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchPets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    if (widget.userLookup == null || widget.userLookup!.trim().isEmpty) return;

    setState(() => _isLoadingUser = true);

    try {
      final url =
          '${ApiConfig.baseUrl}/profile?lookup=${Uri.encodeQueryComponent(widget.userLookup!.trim())}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            if (data['full_name'] != null &&
                data['full_name'].toString().isNotEmpty) {
              _displayName = data['full_name'].toString().split(' ').first;
            }
            final imgStr = data['profile_image']?.toString();
            if (imgStr != null && imgStr.isNotEmpty) {
              _userProfileImageBase64 = imgStr;
            }
          });
        }
      }
    } catch (_) {
      // Fallback stays as Pet Parent
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _fetchPets() async {
    // Pet list still fetched for future use; avatar now uses user profile image.
    if (widget.userLookup == null || widget.userLookup!.trim().isEmpty) return;
    try {
      final url =
          '${ApiConfig.baseUrl}/pets?user_id=${Uri.encodeQueryComponent(widget.userLookup!.trim())}';
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Ignore silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      drawer: AppDrawer(userLookup: widget.userLookup, activeRoute: 'home'),
      appBar: (_currentNavIndex == 1 || _currentNavIndex == 2)
          ? null
          : AppBar(
              backgroundColor: PawStayTheme.surface,
              elevation: 0,
              centerTitle: true,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pets, color: PawStayTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'PawStay',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                GestureDetector(
                  onTap: () {
                    if (widget.userLookup == null ||
                        widget.userLookup!.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please log in again to open your profile.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: PawStayTheme.error,
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userLookup: widget.userLookup!),
                      ),
                    ).then((_) => _fetchUserProfile());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _userProfileImageBase64 != null
                        ? CircleAvatar(
                            radius: 20,
                            backgroundImage: MemoryImage(
                              base64Decode(_userProfileImageBase64!),
                            ),
                          )
                        : const Icon(
                            Icons.account_circle_outlined,
                            color: PawStayTheme.onSurfaceVariant,
                            size: 28,
                          ),
                  ),
                ),
              ],
            ),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildDashboard(isDesktop),
          ChatScreen(
            userLookup: widget.userLookup,
            onBackPressed: () => setState(() => _currentNavIndex = 0),
          ),
          ShopScreen(userLookup: widget.userLookup),
          const Center(child: Text('AI Assistant coming soon')),
        ],
      ),
      // Bottom Navigation bar for mobile view with active tabs
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: PawStayTheme.primary,
          unselectedItemColor: PawStayTheme.onSurfaceVariant,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag_rounded),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.android_outlined),
              activeIcon: Icon(Icons.android_rounded),
              label: 'AI',
            ),
          ],
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
            });
            if (index == 3) {
              // AI Agent — coming soon
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Coming soon: AI Assistant',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                  backgroundColor: PawStayTheme.primary,
                  duration: const Duration(milliseconds: 700),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(bool isDesktop) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PawStayTheme.marginMobile,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Text Headers
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$_greeting, $_displayName!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isDesktop ? 36 : 28,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (_isLoadingUser) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PawStayTheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'What does your pet need today?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Search Input Unit Container
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 680),
              decoration: BoxDecoration(
                color: PawStayTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
                border: Border.all(
                  color: PawStayTheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: PawStayTheme.ambientShadow1,
              ),
              padding: const EdgeInsets.all(PawStayTheme.unit),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.search, color: PawStayTheme.outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: PawStayTheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search sitters, walkers, doctors...',
                        hintStyle: TextStyle(
                          color: PawStayTheme.tertiaryContainer,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Searching near you...',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: PawStayTheme.primary,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PawStayTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          PawStayTheme.radiusDefault,
                        ),
                      ),
                    ),
                    child: Text(
                      'Search',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Bento Grid of Services
            Text(
              'Explore Services',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Bento layout using a GridView with physical card elevations
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isDesktop ? 3 : 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.25,
              children: [
                _buildBentoItem(
                  title: 'Your pet',
                  subtitle: 'Manage profiles',
                  icon: Icons.pets,
                  backgroundColor: PawStayTheme.secondaryContainer,
                  iconColor: PawStayTheme.onSecondaryContainer,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddPetScreen(userLookup: widget.userLookup),
                    ),
                  ),
                ),
                _buildBentoItem(
                  title: 'Buy pet',
                  subtitle: 'Find a friend',
                  icon: Icons.shopping_basket_rounded,
                  backgroundColor: PawStayTheme.surfaceContainerLow,
                  iconColor: PawStayTheme.onSurfaceVariant,
                  onTap: () => setState(() => _currentNavIndex = 2),
                ),
                _buildBentoItem(
                  title: 'Pet Care',
                  subtitle: 'Daily wellness',
                  icon: Icons.favorite_rounded,
                  backgroundColor: PawStayTheme.primaryContainer.withValues(
                    alpha: 0.2,
                  ),
                  iconColor: PawStayTheme.primary,
                  onTap: () =>
                      _showServiceAlert('Daily wellness & care planner'),
                ),
                _buildBentoItem(
                  title: 'Pet Walking',
                  subtitle: 'Active & happy',
                  icon: Icons.directions_walk_rounded,
                  backgroundColor: PawStayTheme.secondaryContainer.withValues(
                    alpha: 0.6,
                  ),
                  iconColor: PawStayTheme.secondary,
                  onTap: () async {
                    final targetNavIndex = await Navigator.push<int>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PetWalkingScreen(userLookup: widget.userLookup),
                      ),
                    );
                    if (targetNavIndex != null && mounted) {
                      setState(() {
                        _currentNavIndex = targetNavIndex;
                      });
                    }
                  },
                ),
                _buildBentoItem(
                  title: 'Doctor',
                  subtitle: 'Expert help',
                  icon: Icons.medical_services_rounded,
                  backgroundColor: PawStayTheme.errorContainer,
                  iconColor: PawStayTheme.onErrorContainer,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DoctorScreen(userLookup: widget.userLookup),
                    ),
                  ),
                ),
                _buildBentoItem(
                  title: 'Food',
                  subtitle: 'Healthy meals',
                  icon: Icons.restaurant_rounded,
                  backgroundColor: PawStayTheme.primaryContainer.withValues(
                    alpha: 0.25,
                  ),
                  iconColor: PawStayTheme.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FoodScreen(userLookup: widget.userLookup),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Featured Map Widget Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nearby Services',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PetMapScreen()),
                    );
                  },
                  child: Text(
                    'Open Map',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Interactive Map Banner — taps into full Google Maps screen
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetMapScreen()),
              ),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: PawStayTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
                  border: Border.all(
                    color: PawStayTheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: PawStayTheme.ambientShadow1,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: MapStylingPainter(
                        zoomValue: 1.0,
                        useCenter: true,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: PawStayTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: PawStayTheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.pets,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.map_rounded,
                                  color: PawStayTheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Explore Nearby Pet Services',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: PawStayTheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: PawStayTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tap to Open',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: PawStayTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
          boxShadow: PawStayTheme.ambientShadow1,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon container badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 22)),
            ),

            // Labels
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: PawStayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceModalSheet(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PawStayTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: PawStayTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: PawStayTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Booking request sent for $title!',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: PawStayTheme.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    'Book Now',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PawStayTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    'Close',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showServiceAlert(String serviceName) {
    _showServiceModalSheet(
      serviceName,
      'Explore top verified service providers for your pet.',
      Icons.pets_rounded,
      PawStayTheme.primary,
    );
  }
}

// Carrier data for markers
class MapMarkerData {
  final String name;
  final String type;
  final String details;
  final IconData icon;
  final Color color;
  final double topRatio;
  final double leftRatio;

  MapMarkerData({
    required this.name,
    required this.type,
    required this.details,
    required this.icon,
    required this.color,
    required this.topRatio,
    required this.leftRatio,
  });
}

// Custom Painter to draw stylized map street grid overlays
class MapStylingPainter extends CustomPainter {
  final double zoomValue;
  final bool useCenter;
  MapStylingPainter({required this.zoomValue, required this.useCenter});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFFDF6F0);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFD97757).withValues(alpha: 0.12)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double gridStep = 40.0 * zoomValue;

    // Draw stylized street layout lines (horizontal / vertical)
    for (double i = 0; i < size.width * 2; i += gridStep) {
      canvas.drawLine(Offset(i, 0), Offset(i - 80, size.height), linePaint);
      canvas.drawLine(Offset(0, i), Offset(size.width, i - 120), linePaint);
    }

    // Draw a mock river / green park shape in the middle
    final parkPaint = Paint()
      ..color = const Color(0xFFD0E7C2).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final Path parkPath = Path();
    parkPath.moveTo(size.width * 0.1, size.height * 0.8);
    parkPath.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.45,
      size.height * 0.9,
    );
    parkPath.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.95,
      size.width * 0.85,
      size.height * 0.6,
    );
    parkPath.lineTo(size.width, size.height);
    parkPath.lineTo(size.width * 0.0, size.height);
    parkPath.close();

    canvas.drawPath(parkPath, parkPaint);

    // Draw grid points for accentuation
    final pointPaint = Paint()
      ..color = const Color(0xFF99462A).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    for (double x = 20; x < size.width; x += gridStep) {
      for (double y = 20; y < size.height; y += gridStep) {
        canvas.drawCircle(Offset(x, y), 0.7, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MapStylingPainter oldDelegate) =>
      oldDelegate.zoomValue != zoomValue || oldDelegate.useCenter != useCenter;
}
