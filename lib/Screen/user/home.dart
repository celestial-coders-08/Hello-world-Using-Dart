import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/api_service.dart';
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
import '../../widgets/animated_ai_nav_icon.dart';
import '../../models/pet_storage.dart';

class HomeScreen extends StatefulWidget {
  final String? userLookup;

  const HomeScreen({super.key, this.userLookup});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  final Set<int> _loadedNavTabs = {0};
  String _displayName = 'Pet Parent';
  bool _isLoadingUser = false;
  String? _userProfileImageBase64;
  Pet? _savedPet;
  final LocalPetStorage _petStorage = LocalPetStorage();
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
    _loadSavedPet();
    _fetchCustomerNotificationsCount();
  }

  int _customerUnreadNotifications = 0;

  Future<void> _fetchCustomerNotificationsCount() async {
    final lookup = widget.userLookup?.trim();
    if (lookup == null || lookup.isEmpty) return;
    final count = await ApiService.fetchUnreadNotificationsCount(
      recipientId: lookup,
      role: 'customer',
    );
    if (mounted) {
      setState(() => _customerUnreadNotifications = count);
    }
  }

  void _openCustomerNotificationsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CustomerNotificationsModal(
        customerLookup: widget.userLookup,
        onNotificationRead: () {
          _fetchCustomerNotificationsCount();
        },
      ),
    ).then((_) => _fetchCustomerNotificationsCount());
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

  Future<void> _loadSavedPet() async {
    final userLookup = widget.userLookup?.trim();
    if (userLookup == null || userLookup.isEmpty) return;

    final pet = await _petStorage.loadPetIfExists(userLookup);
    if (mounted) {
      setState(() => _savedPet = pet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;
    final colors = Theme.of(context).colorScheme;

    return PopScope<void>(
      canPop: _currentNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentNavIndex != 0) {
          setState(() => _currentNavIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        drawer: AppDrawer(userLookup: widget.userLookup, activeRoute: 'home'),
        appBar: (_currentNavIndex == 1 || _currentNavIndex == 2)
            ? null
            : AppBar(
                backgroundColor: colors.surface,
                elevation: 0,
                centerTitle: true,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      color: colors.onSurfaceVariant,
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
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, size: 24),
                        color: colors.onSurfaceVariant,
                        onPressed: _openCustomerNotificationsSheet,
                      ),
                      if (_customerUnreadNotifications > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFC62828),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              _customerUnreadNotifications > 9 ? '9+' : '$_customerUnreadNotifications',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
                          : Icon(
                              Icons.account_circle_outlined,
                              color: colors.onSurfaceVariant,
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
            _loadedNavTabs.contains(1)
                ? ChatScreen(
                    userLookup: widget.userLookup,
                    onBackPressed: () => setState(() => _currentNavIndex = 0),
                  )
                : const SizedBox.shrink(),
            _loadedNavTabs.contains(2)
                ? ShopScreen(userLookup: widget.userLookup)
                : const SizedBox.shrink(),
            const Center(child: Text('AI Assistant coming soon')),
          ],
        ),
        // Bottom Navigation bar for mobile view with active tabs
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
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
            backgroundColor: colors.surfaceContainer,
            selectedItemColor: PawStayTheme.primary,
            unselectedItemColor: colors.onSurfaceVariant,
            selectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            items: [
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
                icon: const AnimatedAiNavIcon(),
                label: 'AI',
              ),
            ],
            onTap: (index) {
              setState(() {
                _currentNavIndex = index;
                _loadedNavTabs.add(index);
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
      ),
    );
  }

  Widget _buildDashboard(bool isDesktop) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: PawStayResponsive.horizontalPadding(context),
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
                    Flexible(
                      child: Text(
                        '$_greeting, $_displayName!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isDesktop ? 36 : 28,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                          letterSpacing: -0.8,
                        ),
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
                    color: colors.onSurfaceVariant,
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
                color: colors.surfaceContainer,
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
                  Icon(Icons.search, color: PawStayTheme.outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: colors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search sitters, walkers, doctors...',
                        hintStyle: TextStyle(color: colors.onSurfaceVariant),
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
                color: colors.onSurface,
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
              childAspectRatio: PawStayResponsive.gridAspectRatio(
                context: context,
                baseRatio: isDesktop ? 1.4 : 1.25,
                compactRatio: 1.15,
                tabletRatio: 1.35,
              ),
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
                      builder: (_) => AddPetScreen(
                        userLookup: widget.userLookup,
                        existingPet: _savedPet,
                      ),
                    ),
                  ).then((_) => _loadSavedPet()),
                ),
                _buildBentoItem(
                  title: 'Buy pet',
                  subtitle: 'Find a friend',
                  icon: Icons.shopping_basket_rounded,
                  backgroundColor: colors.surfaceContainer,
                  iconColor: colors.onSurfaceVariant,
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
                  onTap: _openPetCareOptions,
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
                    color: colors.onSurface,
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

            // Interactive Map Banner — opens the nearby pet services map
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetMapScreen()),
              ),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
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
                              color: colors.surface.withValues(alpha: 0.92),
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
                                    color: colors.onSurface,
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
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
          boxShadow: PawStayTheme.ambientShadow1,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1.0,
          ),
        ),
        padding: EdgeInsets.all(PawStayResponsive.isCompact(context) ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon container badge
            Container(
              width: PawStayResponsive.isCompact(context) ? 38 : 44,
              height: PawStayResponsive.isCompact(context) ? 38 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: PawStayResponsive.isCompact(context) ? 19 : 22,
                ),
              ),
            ),

            // Labels
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: PawStayResponsive.isCompact(context) ? 14 : 15,
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
            ),
          ],
        ),
      ),
    );
  }

  void _openPetCareOptions() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PetCareOptionsScreen(
          userLookup: widget.userLookup,
          onDayCareReturn: (targetNavIndex) {
            if (targetNavIndex != null && mounted) {
              setState(() => _currentNavIndex = targetNavIndex);
            }
          },
        ),
      ),
    );
  }
}

class _PetCareOptionsScreen extends StatelessWidget {
  final String? userLookup;
  final ValueChanged<int?> onDayCareReturn;

  const _PetCareOptionsScreen({
    required this.userLookup,
    required this.onDayCareReturn,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Pet Care',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose a service for your pet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _PetCareOptionTile(
            title: 'Day Care',
            subtitle: 'Find walking and care providers',
            icon: Icons.directions_walk_rounded,
            onTap: () async {
              final targetNavIndex = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (_) => PetWalkingScreen(userLookup: userLookup),
                ),
              );
              onDayCareReturn(targetNavIndex);
            },
          ),
          const SizedBox(height: 14),
          _PetCareOptionTile(
            title: 'Doctor',
            subtitle: 'Browse veterinary care',
            icon: Icons.medical_services_rounded,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorScreen(userLookup: userLookup),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PetCareOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PetCareOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: PawStayTheme.primaryContainer,
          foregroundColor: PawStayTheme.primary,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
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

// ---------------------------------------------------------------------------
// Customer Notifications Modal Bottom Sheet
// ---------------------------------------------------------------------------
class _CustomerNotificationsModal extends StatefulWidget {
  final String? customerLookup;
  final VoidCallback onNotificationRead;

  const _CustomerNotificationsModal({
    required this.customerLookup,
    required this.onNotificationRead,
  });

  @override
  State<_CustomerNotificationsModal> createState() => _CustomerNotificationsModalState();
}

class _CustomerNotificationsModalState extends State<_CustomerNotificationsModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final lookup = widget.customerLookup?.trim();
    if (lookup == null || lookup.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final items = await ApiService.fetchNotifications(
      recipientId: lookup,
      role: 'customer',
    );
    if (!mounted) return;
    setState(() {
      _notifications = items;
      _isLoading = false;
    });
  }

  Future<void> _markAllRead() async {
    final lookup = widget.customerLookup?.trim();
    if (lookup == null) return;
    await ApiService.markAllNotificationsRead(
      recipientId: lookup,
      role: 'customer',
    );
    widget.onNotificationRead();
    _loadNotifications();
  }

  Future<void> _onItemTapped(Map<String, dynamic> item) async {
    final nid = (item['id'] as num?)?.toInt();
    if (nid != null && item['is_read'] != true) {
      await ApiService.markNotificationRead(nid);
      widget.onNotificationRead();
      _loadNotifications();
    }
  }

  String _formatTime(String? dtStr) {
    if (dtStr == null) return '';
    try {
      final dt = DateTime.parse(dtStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$month ${dt.day} • $hour12:$minute $ampm';
    } catch (_) {
      return dtStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Booking Updates & Alerts',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PawStayTheme.onSurface,
                ),
              ),
              if (_notifications.any((n) => n['is_read'] != true))
                TextButton(
                  onPressed: _markAllRead,
                  child: Text(
                    'Mark all as read',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: PawStayTheme.primary),
                  )
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                color: PawStayTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'When sitters confirm or update your bookings, you\'ll see alerts here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          final isUnread = item['is_read'] != true;
                          final title = item['title']?.toString() ?? 'Booking Update';
                          final message = item['message']?.toString() ?? '';
                          final time = _formatTime(item['created_at']?.toString());
                          final type = item['type']?.toString().toLowerCase() ?? '';

                          Color iconColor = PawStayTheme.primary;
                          IconData iconData = Icons.notifications_rounded;
                          if (type.contains('accepted')) {
                            iconColor = const Color(0xFF2E7D32);
                            iconData = Icons.check_circle_rounded;
                          } else if (type.contains('declined')) {
                            iconColor = const Color(0xFFC62828);
                            iconData = Icons.cancel_rounded;
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(iconData, size: 20, color: iconColor),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: PawStayTheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: PawStayTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  message,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: PawStayTheme.onSurfaceVariant,
                                  ),
                                ),
                                if (time.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => _onItemTapped(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
