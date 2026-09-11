import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';
import 'profile_screen.dart';
import 'sitter_profile_screen.dart';

class PetWalkingScreen extends StatefulWidget {
  final String? userLookup;

  const PetWalkingScreen({super.key, this.userLookup});

  @override
  State<PetWalkingScreen> createState() => _PetWalkingScreenState();
}

class _PetWalkingScreenState extends State<PetWalkingScreen> {
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

  Future<void> _fetchPetWalkers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        Uri.parse('${ApiConfig.baseUrl}/service-providers/pet-walking')
            .replace(
              queryParameters: {
                if (widget.userLookup != null &&
                    widget.userLookup!.trim().isNotEmpty)
                  'user_id': widget.userLookup!.trim(),
              },
            )
            .toString(),
      );

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is! List) {
          throw Exception('Invalid response received from server.');
        }

        final List<PetWalker> walkers = [];

        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            walkers.add(PetWalker.fromJson(item));
          } else if (item is Map) {
            walkers.add(PetWalker.fromJson(Map<String, dynamic>.from(item)));
          }
        }

        setState(() {
          _walkers = walkers;
          _isLoading = false;
        });
      } else {
        String message = 'Failed to load available walkers.';

        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['detail'] != null) {
            message = body['detail'].toString();
          }
        } catch (_) {}

        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to connect to PawStay server. Please check your connection.';
      });
    }
  }

  Future<void> _openProvider(PetWalker walker) async {
    // Show loading indicator briefly while fetching provider pricing
    final lookup = walker.username.isNotEmpty
        ? walker.username
        : walker.fullName;

    Map<String, dynamic>? providerData;
    try {
      providerData = await ApiService.fetchProviderProfile(
        providerLookup: lookup,
      );
    } catch (_) {}

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SitterProfileScreen(
          walker: walker,
          userLookup: widget.userLookup,
          walkingCharge:
              walker.walkingCharge ?? providerData?['walking_charge'] as int?,
          daycareCharge:
              walker.daycareCharge ?? providerData?['daycare_charge'] as int?,
          daycareFoodCharge:
              walker.daycareFoodCharge ??
              providerData?['daycare_food_charge'] as int?,
          providerDescription:
              walker.providerDescription ??
              providerData?['provider_description']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFFF9F6,
      ), // Warm off-white background matching UI design
      appBar: AppBar(
        backgroundColor: PawStayTheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: PawStayTheme.onSurfaceVariant,
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
          GestureDetector(
            onTap: () {
              if (widget.userLookup != null &&
                  widget.userLookup!.trim().isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(userLookup: widget.userLookup!),
                  ),
                ).then((_) => _fetchUserProfile());
              }
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

      body: RefreshIndicator(
        color: PawStayTheme.primary,
        onRefresh: _fetchPetWalkers,
        child: _buildBody(),
      ),

      // Standard Bottom Navigation Bar matching HomeScreen
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
            BottomNavigationBarItem(
              icon: Icon(Icons.android_outlined),
              activeIcon: Icon(Icons.android_rounded),
              label: 'AI',
            ),
          ],
          onTap: (index) {
            Navigator.pop(context, index);
          },
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
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Icon(Icons.cloud_off_rounded, size: 54, color: PawStayTheme.outline),
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
              onPressed: _fetchPetWalkers,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Try Again',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PawStayTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final displayWalkers = _walkers;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Text(
          'Available Walkers',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PawStayTheme.onSurface,
          ),
        ),

        const SizedBox(height: 16),

        if (displayWalkers.isEmpty)
          Text(
            'No pet walkers are currently available.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: PawStayTheme.onSurfaceVariant,
            ),
          ),

        ...displayWalkers.map(
          (walker) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildWalkerCard(walker),
          ),
        ),
      ],
    );
  }

  Widget _buildWalkerCard(PetWalker walker) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2E8E2), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openProvider(walker),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildProfileImage(walker),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walker.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: PawStayTheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${walker.distance} • ${walker.serviceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFAF0EB),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
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

class PetWalker {
  final int id;
  final String fullName;
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

  PetWalker({
    required this.id,
    required this.fullName,
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
  });

  factory PetWalker.fromJson(Map<String, dynamic> json) {
    return PetWalker(
      id: _toInt(json['id']),
      fullName: (json['full_name'] ?? 'Pet Walker').toString(),
      username: (json['username'] ?? '').toString(),
      role: (json['role'] ?? 'Service provider').toString(),
      city: (json['city'] ?? '').toString(),
      isVerified: json['is_verified'] == true,
      profileImage: json['profile_image']?.toString(),
      distance: _formatDistance(json['distance']),
      serviceLabel: _formatServiceLabel(
        json['service'] ?? json['service_type'] ?? json['service_name'],
      ),
      walkingCharge: _toNullableInt(json['walking_charge']),
      daycareCharge: _toNullableInt(json['daycare_charge']),
      daycareFoodCharge: _toNullableInt(json['daycare_food_charge']),
      providerDescription: json['provider_description']?.toString(),
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

  static String _formatDistance(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '2 miles away';
    }
    final text = value.toString().trim();
    if (text.toLowerCase().contains('mile') ||
        text.toLowerCase().contains('km')) {
      return text;
    }
    return '$text miles away';
  }

  static String _formatServiceLabel(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Active Walk';
    }
    return value.toString().trim();
  }
}
