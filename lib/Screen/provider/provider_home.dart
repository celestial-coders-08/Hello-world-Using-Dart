import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../user/chat_screen.dart';
import '../user/pet_map_screen.dart';
import '../user/shop_screen.dart';
import 'provider_profile_screen.dart';
import 'slide_bar.dart';
import 'your_rating.dart';

class ProviderDashboardScreen extends StatefulWidget {
  final String? providerLookup;

  const ProviderDashboardScreen({super.key, this.providerLookup});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _currentNavIndex = 0;
  String _displayName = 'Service Provider';
  String? _profileImageBase64;
  bool _isProfileComplete = false;

  double _mapZoom = 1.0;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    PawStayTheme.enterProviderLightMode();
    _checkProfileStatusAndPrompt();
  }

  @override
  void dispose() {
    PawStayTheme.exitProviderLightMode();
    super.dispose();
  }

  Future<void> _checkProfileStatusAndPrompt() async {
    final lookup = widget.providerLookup;
    if (lookup != null && lookup.trim().isNotEmpty) {
      final profile = await ApiService.fetchProviderProfile(
        providerLookup: lookup.trim(),
      );
      if (profile != null && mounted) {
        setState(() {
          if (profile['full_name'] != null &&
              profile['full_name'].toString().trim().isNotEmpty) {
            _displayName = profile['full_name']
                .toString()
                .trim()
                .split(' ')
                .first;
          } else if (profile['username'] != null &&
              profile['username'].toString().trim().isNotEmpty) {
            _displayName = profile['username'].toString().trim();
          }

          if (profile['profile_image'] != null &&
              profile['profile_image'].toString().isNotEmpty) {
            _profileImageBase64 = profile['profile_image'].toString();
          }

          _isProfileComplete = profile['is_complete'] == true;
        });
      }
    }

    // Show complete profile popup dialog if profile is incomplete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isProfileComplete) {
        _showCompleteProfileDialog();
      }
    });
  }

  void _showCompleteProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated paw header badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PawStayTheme.primaryContainer.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_ind_rounded,
                    color: PawStayTheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Complete your profile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Set your service charges (Pet Walking, Day Care, Day Care + Food) and provider description to start receiving client bookings.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: PawStayTheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Skip button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: PawStayTheme.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PawStayTheme.radiusDefault,
                            ),
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Complete button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _openProfileScreen();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PawStayTheme.radiusDefault,
                            ),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Complete Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openProfileScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProviderProfileScreen(providerLookup: widget.providerLookup),
      ),
    );
    if (updated == true && mounted) {
      _checkProfileStatusAndPrompt();
    }
  }

  void _showRatingSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YourRatingScreen(providerLookup: widget.providerLookup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PawStayTheme.themeNotifier,
      builder: (context, _, child) => Theme(
        data: PawStayTheme.providerTheme,
        child: Scaffold(
          backgroundColor: PawStayTheme.background,
          drawer: ProviderSlideBar(
            providerLookup: widget.providerLookup,
            activeRoute: _currentNavIndex == 0 ? 'dashboard' : 'chat',
            displayName: _displayName,
            profileImage: _profileImageBase64,
            onRatingTap: _showRatingSummary,
          ),
          appBar: (_currentNavIndex == 1 || _currentNavIndex == 2)
              ? null
              : AppBar(
                  backgroundColor: PawStayTheme.background,
                  elevation: 0,
                  centerTitle: true,
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PawStayTheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.menu_rounded,
                          color: PawStayTheme.onSurface,
                          size: 18,
                        ),
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pets,
                        color: PawStayTheme.primary,
                        size: 22,
                      ),
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
                      onTap: _openProfileScreen,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: PawStayTheme.surfaceContainer,
                          child: _profileImageBase64 != null
                              ? ClipOval(
                                  child: Image.memory(
                                    base64Decode(_profileImageBase64!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.person_outline_rounded,
                                  color: PawStayTheme.onSurface,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
          body: IndexedStack(
            index: _currentNavIndex,
            children: [
              _buildDashboardHome(),
              ChatScreen(
                userLookup: widget.providerLookup,
                onBackPressed: () => setState(() => _currentNavIndex = 0),
              ),
              ShopScreen(userLookup: widget.providerLookup),
              const Center(child: Text('AI Assistant coming soon')),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                  icon: Icon(Icons.smart_toy_outlined),
                  activeIcon: Icon(Icons.smart_toy_rounded),
                  label: 'Chat with AI',
                ),
              ],
              onTap: (index) {
                setState(() {
                  _currentNavIndex = index;
                });
                if (index == 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Coming soon: Chat with AI Assistant',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      backgroundColor: PawStayTheme.primary,
                      duration: const Duration(milliseconds: 900),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: PawStayTheme.marginMobile,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Subtitle with Edit Profile Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting, $_displayName!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Service Provider Hub & Schedule',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: PawStayTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openProfileScreen,
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  'Edit Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PawStayTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Profile status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isProfileComplete
                  ? PawStayTheme.secondaryContainer.withValues(alpha: 0.3)
                  : PawStayTheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
              border: Border.all(
                color: _isProfileComplete
                    ? PawStayTheme.secondary.withValues(alpha: 0.4)
                    : PawStayTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isProfileComplete
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  color: _isProfileComplete
                      ? PawStayTheme.secondary
                      : PawStayTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isProfileComplete
                            ? 'Profile Completed & Active'
                            : 'Complete Your Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isProfileComplete
                            ? 'Your profile, services, and rates are live for pet owners.'
                            : 'Add your charges and bio to start accepting client bookings.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _openProfileScreen,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isProfileComplete ? 'Edit Profile' : 'Complete Now',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isProfileComplete
                          ? PawStayTheme.secondary
                          : PawStayTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Search Bar
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: PawStayTheme.surfaceDim),
              boxShadow: PawStayTheme.ambientShadow1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: PawStayTheme.outlineVariant,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: PawStayTheme.onSurface,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search bookings, clients, or servic...',
                      hintStyle: TextStyle(
                        color: PawStayTheme.tertiaryContainer,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Searching bookings and services...',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Search',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Provider Services & Overview Section
          Text(
            'Provider Services & Overview',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // 2-Column Grid of Overview Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.35,
            children: [
              // 1. Rating
              _buildOverviewCard(
                icon: Icons.star_rounded,
                iconBg: const Color(0xFFFFF4E5),
                iconColor: const Color(0xFFD97706),
                title: 'Rating',
                subtitle: 'View client reviews',
                onTap: _showRatingSummary,
              ),

              // 2. Analysis
              _buildOverviewCard(
                icon: Icons.bar_chart_rounded,
                iconBg: PawStayTheme.secondaryContainer.withValues(alpha: 0.4),
                iconColor: PawStayTheme.secondary,
                title: 'Analysis',
                subtitle: '68 tasks done • +15%',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Provider Analytics Dashboard',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      backgroundColor: PawStayTheme.secondary,
                    ),
                  );
                },
              ),

              // 3. Buy pet
              _buildOverviewCard(
                icon: Icons.shopping_basket_rounded,
                iconBg: PawStayTheme.surfaceContainerLow,
                iconColor: PawStayTheme.onSurfaceVariant,
                title: 'Buy pet',
                subtitle: 'Client pet matches',
                onTap: () => setState(() => _currentNavIndex = 2),
              ),

              // 4. Doctor
              _buildOverviewCard(
                icon: Icons.medical_services_rounded,
                iconBg: PawStayTheme.errorContainer.withValues(alpha: 0.4),
                iconColor: PawStayTheme.error,
                title: 'Doctor',
                subtitle: '24/7 Vet support',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '24/7 Vet support line connected',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      backgroundColor: PawStayTheme.error,
                    ),
                  );
                },
              ),

              // 5. Food
              _buildOverviewCard(
                icon: Icons.restaurant_rounded,
                iconBg: PawStayTheme.primaryContainer.withValues(alpha: 0.2),
                iconColor: PawStayTheme.primary,
                title: 'Food',
                subtitle: 'Meals & nutrition',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Meals & Nutrition planner open',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      backgroundColor: PawStayTheme.primary,
                    ),
                  );
                },
              ),

              // 6. Pet Care
              _buildOverviewCard(
                icon: Icons.favorite_rounded,
                iconBg: const Color(0xFFFCE7F3),
                iconColor: const Color(0xFFDB2777),
                title: 'Pet Care',
                subtitle: 'Daily active visits',
                onTap: _openProfileScreen,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Current Service Location Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Service Location',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
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
                  'View List',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Custom Painted Map Container
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
              border: Border.all(color: PawStayTheme.surfaceDim),
              boxShadow: PawStayTheme.ambientShadow1,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Stylized map graphics background
                CustomPaint(
                  size: Size.infinite,
                  painter: ProviderMapPainter(zoomLevel: _mapZoom),
                ),

                // Top left Current Location pill badge
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: PawStayTheme.ambientShadow1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 14,
                          color: PawStayTheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Current Location',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: PawStayTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Zoom control buttons (+ / -) bottom right
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(
                          () => _mapZoom = (_mapZoom + 0.2).clamp(0.6, 2.0),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: PawStayTheme.ambientShadow1,
                          ),
                          child: Icon(
                            Icons.add,
                            color: PawStayTheme.onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => setState(
                          () => _mapZoom = (_mapZoom - 0.2).clamp(0.6, 2.0),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: PawStayTheme.ambientShadow1,
                          ),
                          child: Icon(
                            Icons.remove,
                            color: PawStayTheme.onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
          border: Border.all(
            color: PawStayTheme.surfaceDim.withValues(alpha: 0.6),
          ),
          boxShadow: PawStayTheme.ambientShadow1,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
              child: Center(child: Icon(icon, color: iconColor, size: 20)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
}

/// Custom Map Graphic Painter reproducing the organic road shapes & pins in Image 1
class ProviderMapPainter extends CustomPainter {
  final double zoomLevel;

  ProviderMapPainter({this.zoomLevel = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFFAF3EC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = const Color(0xFFF0E4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36 * zoomLevel
      ..strokeCap = StrokeCap.round;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    path1.cubicTo(
      size.width * 0.3,
      size.height * 0.9,
      size.width * 0.5,
      size.height * 0.4,
      size.width,
      size.height * 0.5,
    );
    canvas.drawPath(path1, roadPaint);

    final path2 = Path();
    path2.moveTo(size.width * 0.4, 0);
    path2.cubicTo(
      size.width * 0.6,
      size.height * 0.3,
      size.width * 0.7,
      size.height * 0.7,
      size.width * 0.9,
      size.height,
    );
    canvas.drawPath(path2, roadPaint);

    // Large main brown pin ring
    final centerPin = Offset(size.width * 0.4, size.height * 0.45);
    final shadowPaint = Paint()
      ..color = const Color(0xFF99462A).withValues(alpha: 0.15);
    canvas.drawCircle(centerPin, 28 * zoomLevel, shadowPaint);

    final pinPaint = Paint()..color = const Color(0xFF99462A);
    canvas.drawCircle(centerPin, 16 * zoomLevel, pinPaint);

    final pinDotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(centerPin, 5 * zoomLevel, pinDotPaint);

    // Secondary walking pin (brown)
    final walkPin = Offset(size.width * 0.55, size.height * 0.78);
    canvas.drawCircle(walkPin, 14 * zoomLevel, pinPaint);

    // Secondary paw pin (green)
    final greenPinPaint = Paint()..color = const Color(0xFF506447);
    final pawPin = Offset(size.width * 0.68, size.height * 0.75);
    canvas.drawCircle(pawPin, 14 * zoomLevel, greenPinPaint);
  }

  @override
  bool shouldRepaint(covariant ProviderMapPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel;
  }
}
