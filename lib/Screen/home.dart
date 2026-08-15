import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/pawstay_theme.dart';
import 'profile_screen.dart';
import 'contact_support_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? userLookup;

  const HomeScreen({super.key, this.userLookup});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  String? _selectedMarkerName;
  double _zoomScale = 1.0;
  bool _useCurrentLocation = true;
  String _displayName = 'Pet Parent';
  bool _isLoadingUser = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
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
        if (mounted &&
            data['full_name'] != null &&
            data['full_name'].toString().isNotEmpty) {
          setState(() {
            _displayName = data['full_name'].toString().split(' ').first;
          });
        }
      }
    } catch (_) {
      // Fallback stays as Pet Parent
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  // Nearby service listings for mock map markers
  final List<MapMarkerData> _markers = [
    MapMarkerData(
      name: 'City Vet Clinic',
      type: 'Doctor / Clinic',
      details: 'Open 24/7 • 1.2 miles away',
      icon: Icons.medical_services_rounded,
      color: PawStayTheme.error,
      topRatio: 0.25,
      leftRatio: 0.33,
    ),
    MapMarkerData(
      name: 'Happy Paws Daycare',
      type: 'Pet Care / Stay',
      details: '4.8 ★ (120 reviews) • 2.5 miles away',
      icon: Icons.pets_rounded,
      color: PawStayTheme.secondary,
      topRatio: 0.50,
      leftRatio: 0.70,
    ),
    MapMarkerData(
      name: "Buster's Walkers",
      type: 'Pet Walking',
      details: 'Active now • 0.8 miles away',
      icon: Icons.directions_walk_rounded,
      color: PawStayTheme.primary,
      topRatio: 0.65,
      leftRatio: 0.48,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.help_outline_rounded,
            color: PawStayTheme.onSurfaceVariant,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
            );
          },
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
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: PawStayTheme.onSurfaceVariant,
              size: 28,
            ),
            onPressed: () {
              if (widget.userLookup == null ||
                  widget.userLookup!.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please log in again to open your profile.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                    ),
                    backgroundColor: PawStayTheme.error,
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userLookup: widget.userLookup!),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
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
                        'Good morning, $_displayName!',
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
                    onTap: () => _showServiceAlert('Pet profiles manager'),
                  ),
                  _buildBentoItem(
                    title: 'Buy pet',
                    subtitle: 'Find a friend',
                    icon: Icons.shopping_basket_rounded,
                    backgroundColor: PawStayTheme.surfaceContainerHighest,
                    iconColor: PawStayTheme.onSurfaceVariant,
                    onTap: () => _showServiceAlert('Adopt or Buy Pet services'),
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
                    onTap: () => _showServiceAlert('Schedule dog walkers'),
                  ),
                  _buildBentoItem(
                    title: 'Doctor',
                    subtitle: 'Expert help',
                    icon: Icons.medical_services_rounded,
                    backgroundColor: PawStayTheme.errorContainer,
                    iconColor: PawStayTheme.onErrorContainer,
                    onTap: () =>
                        _showServiceAlert('Vet clinical services finder'),
                  ),
                  _buildBentoItem(
                    title: 'Food',
                    subtitle: 'Healthy meals',
                    icon: Icons.restaurant_rounded,
                    backgroundColor: PawStayTheme.primaryContainer.withValues(
                      alpha: 0.25,
                    ),
                    iconColor: PawStayTheme.primary,
                    onTap: () =>
                        _showServiceAlert('Find healthy meals and supplies'),
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
                      _showServiceAlert('Sitter list expanded view');
                    },
                    child: Text(
                      'View List',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive Stylized Mock Map Container
              Container(
                height: 400,
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
                  children: [
                    // Stylized Custom Paint Grid Mock Map
                    InteractiveViewer(
                      scaleEnabled: true,
                      maxScale: 3.0,
                      minScale: 0.5,
                      child: SizedBox(
                        width: double.infinity,
                        height: 400,
                        child: CustomPaint(
                          painter: MapStylingPainter(
                            zoomValue: _zoomScale,
                            useCenter: _useCurrentLocation,
                          ),
                        ),
                      ),
                    ),

                    // Map markers overlay placement
                    ..._markers.map((marker) {
                      final isSelected = _selectedMarkerName == marker.name;
                      return Positioned(
                        top:
                            400 * marker.topRatio * _zoomScale -
                            (isSelected ? 10 : 0),
                        left: size.width * 0.8 * marker.leftRatio * _zoomScale,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMarkerName = marker.name;
                              _useCurrentLocation = false;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 48 : 40,
                                height: isSelected ? 48 : 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: marker.color,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      offset: const Offset(0, 4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  marker.icon,
                                  color: Colors.white,
                                  size: isSelected ? 24 : 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  marker.name.split(' ').first,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontStyle: FontStyle.normal,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Current user location indicator mock dot
                    if (_useCurrentLocation)
                      Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Top Left Current Location Button
                    Positioned(
                      top: 16,
                      left: 16,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _useCurrentLocation = true;
                            _selectedMarkerName = null;
                            _zoomScale = 1.0;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Centered to Current Location!',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.blue[600],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          foregroundColor: PawStayTheme.onSurface,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(
                          Icons.my_location,
                          size: 18,
                          color: PawStayTheme.primary,
                        ),
                        label: Text(
                          'Current Location',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Zoom Controls overlay (Bottom Right)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMapControlBtn(Icons.add, () {
                            setState(() {
                              _zoomScale = (_zoomScale + 0.15).clamp(0.8, 1.8);
                            });
                          }),
                          const SizedBox(height: 8),
                          _buildMapControlBtn(Icons.remove, () {
                            setState(() {
                              _zoomScale = (_zoomScale - 0.15).clamp(0.8, 1.8);
                            });
                          }),
                        ],
                      ),
                    ),

                    // Selected Marker Detail Banner / Tooltip Popup
                    if (_selectedMarkerName != null)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 80, // Leave spacing for zoom buttons
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              PawStayTheme.radiusMd,
                            ),
                            border: Border.all(
                              color: PawStayTheme.outlineVariant,
                            ),
                            boxShadow: PawStayTheme.ambientShadow2,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedMarkerName!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: PawStayTheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _markers
                                          .firstWhere(
                                            (e) =>
                                                e.name == _selectedMarkerName,
                                          )
                                          .details,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: PawStayTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: PawStayTheme.primary,
                                  size: 16,
                                ),
                                onPressed: () {
                                  _showServiceAlert(
                                    'Navigating to $_selectedMarkerName details',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
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
              label: 'Chat with AI',
            ),
          ],
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Switched to tab: ${['Home', 'Chat', 'Shop', 'AI Agent'][index]}',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                ),
                backgroundColor: PawStayTheme.primary,
                duration: const Duration(milliseconds: 700),
              ),
            );
          },
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

  Widget _buildMapControlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PawStayTheme.radiusSm),
          border: Border.all(color: PawStayTheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: PawStayTheme.onSurfaceVariant, size: 20),
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
