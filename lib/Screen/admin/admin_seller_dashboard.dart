import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import 'admin_theme.dart';

class SellerModel {
  final int id;
  final String name;
  final String businessName;
  final String category;
  final String email;
  final String phone;
  final String location;
  final double? rating;
  final int? reviewCount;
  final int? completedOrders;
  final double? ratePerHour;
  final String licenseNumber;
  final String experience;
  final String identityDocumentUrl;
  final String shopProofUrl;
  final List<String> facePhotoUrls;
  int? commissionRate;
  bool isVerified;
  bool isFeatured;
  bool isPending;
  final String sellerLookup;

  SellerModel({
    required this.id,
    required this.name,
    required this.businessName,
    required this.category,
    required this.email,
    required this.phone,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.completedOrders,
    required this.ratePerHour,
    required this.licenseNumber,
    required this.experience,
    required this.identityDocumentUrl,
    required this.shopProofUrl,
    required this.facePhotoUrls,
    this.commissionRate = 10,
    required this.isVerified,
    this.isFeatured = false,
    this.isPending = false,
    required this.sellerLookup,
  });

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    final isShopOwner = json['is_shop_owner'] == true;
    return SellerModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['full_name']?.toString() ?? '',
      businessName: json['username']?.toString() ?? '',
      category: isShopOwner ? 'Shop Seller' : 'Individual Seller',
      email: json['email']?.toString() ?? '',
      phone: json['phone_number']?.toString() ?? '',
      location: [
        json['city']?.toString(),
        json['state']?.toString(),
      ].whereType<String>().where((value) => value.isNotEmpty).join(', '),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt(),
      completedOrders: (json['completed_orders'] as num?)?.toInt(),
      ratePerHour: (json['walking_charge'] as num?)?.toDouble(),
      licenseNumber: json['license']?.toString() ?? 'N/A',
      experience: json['experience']?.toString() ?? 'N/A',
      identityDocumentUrl: json['aadhaar_url']?.toString() ?? '',
      shopProofUrl: json['shop_proof_url']?.toString() ?? '',
      facePhotoUrls: (json['face_images'] as List<dynamic>? ?? [])
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList(),
      commissionRate: (json['commission'] as num?)?.toInt(),
      isVerified: status == 'Approved',
      isPending: status == 'Pending',
      sellerLookup: json['username']?.toString() ?? '',
    );
  }
}

class AdminSellerDashboard extends StatefulWidget {
  const AdminSellerDashboard({super.key});

  @override
  State<AdminSellerDashboard> createState() => _AdminSellerDashboardState();
}

class _AdminSellerDashboardState extends State<AdminSellerDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _isLoading = false;
  String? _loadError;

  List<SellerModel> _sellers = [];
  List<SellerModel> _filteredSellers = [];

  @override
  void initState() {
    super.initState();
    _loadSellers();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSellers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final headers = await _adminHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.adminBaseUrl}/admin/seller-verifications'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception(
          'Could not load seller verifications (${response.statusCode}).',
        );
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      _sellers = data
          .map(
            (item) =>
                SellerModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      _loadError = null;
    } catch (error, stackTrace) {
      debugPrint('Failed to load seller verifications: $error\n$stackTrace');
      _sellers = [];
      _loadError = error.toString().replaceFirst('Exception: ', '');
    }

    if (mounted) {
      _applyFilter();
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, String>> _adminHeaders() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('access_token');
    if (token == null || token.isEmpty) {
      throw StateError(
        'Admin sign-in is required to load seller applications.',
      );
    }
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<void> _updateVerification(
    SellerModel seller,
    String status,
    BuildContext dialogContext,
  ) async {
    try {
      final headers = await _adminHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http
          .patch(
            Uri.parse(
              '${ApiConfig.adminBaseUrl}/admin/seller-verifications/'
              '${Uri.encodeComponent(seller.sellerLookup)}',
            ),
            headers: headers,
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        final decoded = jsonDecode(response.body);
        final detail = decoded is Map ? decoded['detail'] : null;
        throw Exception(
          detail?.toString() ??
              'Could not update seller verification (${response.statusCode}).',
        );
      }
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      await _loadSellers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Approved'
                ? '${seller.name} verified successfully!'
                : 'Application rejected for ${seller.name}',
          ),
          backgroundColor: status == 'Approved'
              ? AdminTheme.secondary
              : AdminTheme.statusDanger,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update verification: $error'),
          backgroundColor: AdminTheme.statusDanger,
        ),
      );
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredSellers = _sellers.where((seller) {
        final matchesQuery =
            seller.name.toLowerCase().contains(query) ||
            seller.businessName.toLowerCase().contains(query) ||
            seller.location.toLowerCase().contains(query) ||
            seller.licenseNumber.toLowerCase().contains(query);

        if (!matchesQuery) return false;

        if (_selectedCategory == 'Pending') {
          return seller.isPending;
        } else if (_selectedCategory != 'All') {
          return seller.category.toLowerCase() ==
              _selectedCategory.toLowerCase();
        }
        return true;
      }).toList();
    });
  }

  void _showApprovalDialog(SellerModel seller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AdminTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AdminTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.verified_outlined,
                color: AdminTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Review Application', style: AdminTheme.heading(16)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.62,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seller.name,
                    style: AdminTheme.heading(
                      14,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  Text(
                    seller.businessName,
                    style: AdminTheme.body(12, color: AdminTheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text('Uploaded documents', style: AdminTheme.heading(13)),
                  const SizedBox(height: 8),
                  _buildEvidenceDocument(
                    'Identity document',
                    seller.identityDocumentUrl,
                  ),
                  if (seller.shopProofUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildEvidenceDocument(
                      'Shop ownership proof',
                      seller.shopProofUrl,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Verification photos', style: AdminTheme.heading(13)),
                  const SizedBox(height: 8),
                  if (seller.facePhotoUrls.isEmpty)
                    Text(
                      'No verification photos were uploaded.',
                      style: AdminTheme.body(12, color: AdminTheme.textMuted),
                    )
                  else
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: seller.facePhotoUrls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => _buildFacePhoto(
                          seller.facePhotoUrls[index],
                          index + 1,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminTheme.border),
                    ),
                    child: Column(
                      children: [
                        _buildMiniRow('Category:', seller.category),
                        const SizedBox(height: 4),
                        _buildMiniRow('Experience:', seller.experience),
                        const SizedBox(height: 4),
                        _buildMiniRow(
                          'Rate:',
                          seller.ratePerHour == null
                              ? 'N/A'
                              : '₹${seller.ratePerHour!.toInt()}/hr',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _updateVerification(seller, 'Rejected', ctx),
            child: Text(
              'Reject',
              style: GoogleFonts.plusJakartaSans(
                color: AdminTheme.statusDanger,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _updateVerification(seller, 'Approved', ctx),
            child: Text(
              'Approve',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Uri _evidenceUri(String path) {
    final uri = Uri.parse(path);
    return uri.hasScheme ? uri : Uri.parse('${ApiConfig.sellerBaseUrl}$path');
  }

  bool _isImageDocument(String path) {
    final extension = _evidenceUri(path).path.toLowerCase();
    return [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
    ].any(extension.endsWith);
  }

  Widget _buildEvidenceDocument(String title, String path) {
    if (path.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminTheme.border),
        ),
        child: Text(
          '$title was not uploaded.',
          style: AdminTheme.body(12, color: AdminTheme.textMuted),
        ),
      );
    }
    final uri = _evidenceUri(path);
    if (_isImageDocument(path)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AdminTheme.body(11, color: AdminTheme.textMuted)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: AdminTheme.cardBg,
                child: InteractiveViewer(
                  child: Image.network(
                    uri.toString(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Could not load this uploaded document.'),
                    ),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                uri.toString(),
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (context, error, stackTrace) => _documentOpenTile(
                  title,
                  uri,
                  'Preview unavailable. Tap to open the uploaded document.',
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _documentOpenTile(title, uri, 'Tap to open the uploaded document.');
  }

  Widget _documentOpenTile(String title, Uri uri, String subtitle) {
    return InkWell(
      onTap: () async {
        try {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (opened || !mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this document.')),
          );
        } catch (error, stackTrace) {
          debugPrint('Could not open seller document: $error\n$stackTrace');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open this document.')),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: AdminTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AdminTheme.body(12, weight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: AdminTheme.body(10, color: AdminTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: AdminTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildFacePhoto(String path, int photoNumber) {
    final uri = _evidenceUri(path);
    return Tooltip(
      message: 'Verification photo $photoNumber',
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: AdminTheme.cardBg,
            child: InteractiveViewer(
              child: Image.network(
                uri.toString(),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load this verification photo.'),
                ),
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            uri.toString(),
            width: 120,
            height: 128,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 120,
              height: 128,
              color: AdminTheme.background,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                color: AdminTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCommissionModal(SellerModel seller) {
    int currentCommission = seller.commissionRate ?? 10;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: AdminTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AdminTheme.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Commission Rate', style: AdminTheme.heading(16)),
              Text(
                'Adjust platform percentage for ${seller.name}',
                style: AdminTheme.body(12),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Cut:',
                    style: AdminTheme.body(
                      13,
                      color: AdminTheme.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AdminTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$currentCommission%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: currentCommission.toDouble(),
                min: 5,
                max: 25,
                divisions: 20,
                activeColor: AdminTheme.primary,
                inactiveColor: AdminTheme.border,
                onChanged: (val) {
                  setModalState(() => currentCommission = val.round());
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      seller.commissionRate = currentCommission;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Commission set to $currentCommission%'),
                        backgroundColor: AdminTheme.secondary,
                      ),
                    );
                  },
                  child: Text(
                    'Save Rate',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AdminTheme.body(11, color: AdminTheme.textMuted)),
        Flexible(
          child: Text(
            val,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AdminTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _sellers.where((s) => s.isPending).length;
    final doctorCount = _sellers.where((s) => s.category == 'Doctor').length;
    final boardingCount = _sellers
        .where((s) => s.category == 'Boarding')
        .length;
    final walkerCount = _sellers.where((s) => s.category == 'Walker').length;

    return ValueListenableBuilder<bool>(
      valueListenable: AdminTheme.isDarkMode,
      builder: (context, isDark, _) => RefreshIndicator(
        onRefresh: () async => _loadSellers(),
        color: AdminTheme.primary,
        backgroundColor: AdminTheme.cardBg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seller & Vet Hub', style: AdminTheme.heading(20)),
                        const SizedBox(height: 2),
                        Text(
                          'Doctors, clinic partners, boarding hosts & walkers',
                          style: AdminTheme.body(12),
                        ),
                      ],
                    ),
                  ),
                  if (pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AdminTheme.statusWarningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminTheme.statusWarning),
                      ),
                      child: Text(
                        '$pendingCount Pending',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.statusWarning,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Could not load live seller data: $_loadError',
                    style: AdminTheme.body(12, color: AdminTheme.statusDanger),
                  ),
                ),

              // Top Metrics Responsive Grid (2x2 on phones)
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricCard(
                        'Total Providers',
                        _loadError == null ? '${_sellers.length}' : 'N/A',
                        'Seller verification records',
                        Icons.storefront_outlined,
                        AdminTheme.primary,
                        cardWidth,
                      ),
                      _buildMetricCard(
                        'Pending Review',
                        _loadError == null ? '$pendingCount' : 'N/A',
                        'Needs approval',
                        Icons.pending_actions,
                        AdminTheme.statusWarning,
                        cardWidth,
                      ),
                      _buildMetricCard(
                        'Avg Vet Rating',
                        'N/A',
                        'No rating data available',
                        Icons.star_outline_rounded,
                        AdminTheme.secondary,
                        cardWidth,
                      ),
                      _buildMetricCard(
                        'Due Payouts',
                        'N/A',
                        'No payout data available',
                        Icons.payments_outlined,
                        const Color(0xFFD97757),
                        cardWidth,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Search Bar & Category Filter
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AdminTheme.cardDecoration(),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminTheme.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search Doctor, Clinic or Walker...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: AdminTheme.textMuted,
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AdminTheme.primary,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AdminTheme.background,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AdminTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AdminTheme.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab('All', _sellers.length, Icons.apps),
                          const SizedBox(width: 6),
                          _buildFilterTab(
                            'Pending',
                            pendingCount,
                            Icons.hourglass_top,
                            highlight: true,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterTab(
                            'Doctor',
                            doctorCount,
                            Icons.medical_services_outlined,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterTab(
                            'Boarding',
                            boardingCount,
                            Icons.home_outlined,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterTab(
                            'Walker',
                            walkerCount,
                            Icons.directions_walk,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Seller Cards List
              Text(
                'Registered Providers (${_filteredSellers.length})',
                style: AdminTheme.heading(16),
              ),
              const SizedBox(height: 10),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AdminTheme.primary),
                  ),
                )
              else if (_filteredSellers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: AdminTheme.cardDecoration(),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 40,
                        color: AdminTheme.textMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No providers found in this category',
                        style: AdminTheme.body(13),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredSellers.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final seller = _filteredSellers[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: AdminTheme.cardDecoration(
                        borderColor: seller.isPending
                            ? AdminTheme.statusWarning
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AdminTheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getCategoryIcon(seller.category),
                                  color: AdminTheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            seller.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AdminTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (seller.isFeatured) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  AdminTheme.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'TOP',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: AdminTheme.primary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      seller.businessName,
                                      style: AdminTheme.body(
                                        11,
                                        color: AdminTheme.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 11,
                                          color: AdminTheme.textMuted,
                                        ),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            seller.location,
                                            style: AdminTheme.body(
                                              10,
                                              color: AdminTheme.textMuted,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.star,
                                          size: 11,
                                          color: Color(0xFFE65100),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          seller.rating == null
                                              ? 'N/A'
                                              : '${seller.rating} (${seller.reviewCount ?? 0})',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AdminTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: seller.isPending
                                      ? AdminTheme.statusWarningBg
                                      : AdminTheme.statusSuccessBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  seller.isPending ? 'PENDING' : 'VERIFIED',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: seller.isPending
                                        ? AdminTheme.statusWarning
                                        : AdminTheme.statusSuccess,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AdminTheme.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoItem('License', seller.licenseNumber),
                                _buildInfoItem(
                                  'Rate',
                                  seller.ratePerHour == null
                                      ? 'N/A'
                                      : '₹${seller.ratePerHour!.toInt()}/hr',
                                ),
                                _buildInfoItem(
                                  'Done',
                                  seller.completedOrders?.toString() ?? 'N/A',
                                ),
                                _buildInfoItem(
                                  'Cut',
                                  seller.commissionRate == null
                                      ? 'N/A'
                                      : '${seller.commissionRate}%',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (seller.isPending) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AdminTheme.secondary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.check,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Approve',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _showApprovalDialog(seller),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AdminTheme.primary,
                                  side: BorderSide(color: AdminTheme.border),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.percent, size: 14),
                                label: Text(
                                  'Commission',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                  ),
                                ),
                                onPressed: () => _showCommissionModal(seller),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: Icon(
                                  seller.isFeatured
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: seller.isFeatured
                                      ? AdminTheme.primary
                                      : AdminTheme.textMuted,
                                  size: 20,
                                ),
                                tooltip: 'Feature Provider',
                                onPressed: () {
                                  setState(() {
                                    seller.isFeatured = !seller.isFeatured;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        seller.isFeatured
                                            ? '${seller.name} Featured!'
                                            : 'Removed from Featured',
                                      ),
                                      backgroundColor: AdminTheme.secondary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminTheme.body(9, color: AdminTheme.textMuted)),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AdminTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtext,
    IconData icon,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: AdminTheme.body(11, color: AdminTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AdminTheme.heading(18, color: AdminTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: AdminTheme.body(10, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
    String label,
    int count,
    IconData icon, {
    bool highlight = false,
  }) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminTheme.primary
              : (highlight ? AdminTheme.statusWarningBg : AdminTheme.cardBg),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AdminTheme.primary
                : (highlight ? AdminTheme.statusWarning : AdminTheme.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (highlight
                        ? AdminTheme.statusWarning
                        : AdminTheme.textSecondary),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (highlight
                          ? AdminTheme.statusWarning
                          : AdminTheme.textSecondary),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black.withValues(alpha: 0.2)
                    : AdminTheme.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AdminTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'doctor':
        return Icons.medical_services_outlined;
      case 'boarding':
        return Icons.home_outlined;
      case 'walker':
        return Icons.directions_walk;
      default:
        return Icons.storefront_outlined;
    }
  }
}
