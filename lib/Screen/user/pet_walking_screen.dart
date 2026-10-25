import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/animated_ai_nav_icon.dart';
import 'profile_screen.dart';
import 'sitter_profile_screen.dart';

String _fmtPrice(dynamic v) {
  if (v == null) return '0';
  final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
  return n == n.truncateToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

class PetWalkingScreen extends StatefulWidget {
  final String? userLookup;
  final String initialCategory; // 'Pet Sitter' or 'Packages' or 'sitter' or 'packages'

  const PetWalkingScreen({
    super.key,
    this.userLookup,
    this.initialCategory = 'Pet Sitter',
  });

  @override
  State<PetWalkingScreen> createState() => _PetWalkingScreenState();
}

class _PetWalkingScreenState extends State<PetWalkingScreen> {
  late String _selectedCategory; // 'sitter' or 'packages'
  bool _isLoading = true;
  String? _errorMessage;
  String? _userProfileImageBase64;

  List<PetWalker> _walkers = [];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchPetWalkers();
  }

  Future<void> _fetchUserProfile() async {
    if (widget.userLookup == null || widget.userLookup!.trim().isEmpty) return;
    try {
      final url =
          '${ApiConfig.baseUrl}/profile?lookup=${Uri.encodeQueryComponent(widget.userLookup!.trim())}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          final imgStr = data['profile_image']?.toString();
          if (imgStr != null && imgStr.isNotEmpty) {
            setState(() {
              _userProfileImageBase64 = imgStr;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchProviders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.fetchCustomerProviders(
        category: _selectedCategory,
      );

      if (!mounted) return;

      setState(() {
        _providers = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to connect to PawStay. Please check your connection.';
      });
    }
  }

  void _switchCategory(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
    _fetchProviders();
  }

  void _openProvider(Map<String, dynamic> provider) {
    final lookup = (provider['username'] ?? provider['id'] ?? '').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SitterProfileScreen(
          providerLookup: lookup,
          userLookup: widget.userLookup,
          initialCategory: _selectedCategory,
          initialProviderData: provider,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredProviders {
    if (_searchQuery.trim().isEmpty) return _providers;
    final query = _searchQuery.trim().toLowerCase();
    return _providers.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final bio = (p['bio'] ?? '').toString().toLowerCase();
      return name.contains(query) || city.contains(query) || bio.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF9F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: PawStayTheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: PawStayTheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
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
          if (widget.userLookup != null && widget.userLookup!.trim().isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(userLookup: widget.userLookup!),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Icon(
                  Icons.account_circle_outlined,
                  color: PawStayTheme.onSurfaceVariant,
                  size: 28,
                ),
              ),
            ),
        ],
      ),

      body: RefreshIndicator(
        color: PawStayTheme.primary,
        onRefresh: _fetchPetWalkers,
        child: _buildBody(),
      ),

      // Bottom Navigation matching User screens
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
          currentIndex: 0,
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
            BottomNavigationBarItem(icon: AnimatedAiNavIcon(), label: 'AI'),
          ],
          onTap: (index) {
            Navigator.pop(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? PawStayTheme.primary : const Color(0xFFF7EFE9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: PawStayTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : PawStayTheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : PawStayTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: const Center(
              child: CircularProgressIndicator(color: PawStayTheme.primary),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          const Icon(Icons.cloud_off_rounded, size: 54, color: PawStayTheme.primary),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: PawStayTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _fetchProviders,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Try Again',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PawStayTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final list = _filteredProviders;

    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFCEEE8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets_rounded,
              size: 48,
              color: PawStayTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isPackages
                ? 'No Package Providers Available'
                : 'No Pet Sitters Available',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No providers matched "$_searchQuery". Try searching a different city or name.'
                : 'Check back soon as verified care providers activate their schedules.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: PawStayTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: list.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              _isPackages ? 'Care Packages' : 'Available Pet Sitters',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
          );
        }

        final provider = list[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildProviderCard(provider),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Card: avatar/initial, name, city, rating (or "New"), price display
  // ---------------------------------------------------------------------------
  Widget _buildProviderCard(Map<String, dynamic> provider) {
    final name = (provider['name'] ?? 'Pet Care Provider').toString();
    final city = (provider['city'] ?? '').toString().trim();

    final dynamic ratingRaw = provider['rating'];
    final double? rating = ratingRaw is num ? ratingRaw.toDouble() : double.tryParse('$ratingRaw');

    final dynamic reviewCountRaw = provider['review_count'];
    final int reviewCount = reviewCountRaw is int ? reviewCountRaw : int.tryParse('$reviewCountRaw') ?? 0;

    // Price display logic
    String priceText;
    if (_isPackages) {
      final minPrice = provider['min_package_price'];
      priceText = 'From ₹${_fmtPrice(minPrice)}';
    } else {
      final sitterPrice = provider['sitter_price'];
      priceText = '₹${_fmtPrice(sitterPrice)} / session';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openProvider(provider),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar / Initial
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFCEEE8),
                  ),
                  child: ClipOval(child: _buildAvatar(provider, name, 56)),
                ),
                const SizedBox(width: 14),

                // Name, City, Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: PawStayTheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Rating or New badge
                          _buildRatingBadge(rating, reviewCount),
                        ],
                      ),
                      const SizedBox(height: 3),

                      if (city.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: PawStayTheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              city,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: PawStayTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                      ],

                      Text(
                        priceText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: PawStayTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFAF0EB),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: PawStayTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(PetWalker walker) {
    if (walker.profileImage != null && walker.profileImage!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(
          walker.profileImage!.contains(',')
              ? walker.profileImage!.split(',').last
              : walker.profileImage!,
        );

        return CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFFAF0EB),
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFFAF0EB),
      child: const Icon(Icons.person, color: PawStayTheme.primary, size: 26),
    );
  }
}

// ---------------------------------------------------------------------------
// Backward-compatible PetWalker model for any references
// ---------------------------------------------------------------------------
class PetWalker {
  final int id;
  final String fullName;
  final String email;
  final String username;
  final String role;
  final String city;
  final bool isVerified;
  final String? profileImage;
  final String distance;
  final String serviceLabel;
  final int? walkingCharge;
  final int? daycareCharge;
  final int? daycareFoodCharge;
  final String? providerDescription;
  final double averageRating;
  final int reviewCount;

  PetWalker({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
    required this.city,
    required this.isVerified,
    required this.profileImage,
    required this.distance,
    required this.serviceLabel,
    required this.walkingCharge,
    required this.daycareCharge,
    required this.daycareFoodCharge,
    required this.providerDescription,
    required this.averageRating,
    required this.reviewCount,
  });

  factory PetWalker.fromJson(Map<String, dynamic> json) {
    final uname = (json['username'] ?? '').toString();
    final mail = (json['email'] ?? '').toString().trim();

    return PetWalker(
      id: _toInt(json['id']),
      fullName: (json['full_name'] ?? json['name'] ?? 'Pet Sitter').toString(),
      email: mail,
      username: uname,
      role: (json['role'] ?? 'Service provider').toString(),
      city: (json['city'] ?? '').toString(),
      isVerified: json['is_verified'] == true,
      profileImage: json['profile_image']?.toString(),
      distance: (json['distance'] ?? '2 miles away').toString(),
      serviceLabel: (json['service'] ?? 'Pet Care').toString(),
      walkingCharge: _toNullableInt(json['sitter_price'] ?? json['walking_charge']),
      daycareCharge: _toNullableInt(json['daycare_charge']),
      daycareFoodCharge: _toNullableInt(json['daycare_food_charge']),
      providerDescription: (json['bio'] ?? json['provider_description'])?.toString(),
      averageRating: (json['rating'] ?? json['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: _toInt(json['review_count']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}