import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';
import 'chat_detail_screen.dart';
import 'pet_walking_screen.dart';

String _fmtPrice(dynamic v) {
  if (v == null) return '0';
  final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
  return n == n.truncateToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

class SitterProfileScreen extends StatefulWidget {
  final PetWalker? walker;
  final String? providerLookup;
  final String? userLookup;
  final String initialCategory; // 'sitter' or 'packages'
  final Map<String, dynamic>? initialProviderData;

  const SitterProfileScreen({
    super.key,
    this.walker,
    this.providerLookup,
    this.userLookup,
    this.initialCategory = 'sitter',
    this.initialProviderData,
  });

  @override
  State<SitterProfileScreen> createState() => _SitterProfileScreenState();
}

class _SitterProfileScreenState extends State<SitterProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Provider data
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _reviews = [];

  // Selected service for booking
  String _selectedServiceType = 'sitter'; // 'sitter' or 'package'
  int? _selectedPackageId;
  String? _selectedTier;
  double _selectedPrice = 0.0;
  bool _isBooking = false;

  String get _effectiveLookup {
    if (widget.providerLookup != null &&
        widget.providerLookup!.trim().isNotEmpty) {
      return widget.providerLookup!.trim();
    }
    if (widget.initialProviderData != null) {
      final uname = widget.initialProviderData!['username']?.toString().trim();
      if (uname != null && uname.isNotEmpty) return uname;
      final id = widget.initialProviderData!['id']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }
    if (widget.walker != null) {
      if (widget.walker!.username.trim().isNotEmpty) {
        return widget.walker!.username.trim();
      }
      return widget.walker!.id.toString();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _initCategorySelection();
    _loadAllData();
  }

  void _initCategorySelection() {
    if (widget.initialCategory.toLowerCase().contains('pack')) {
      _selectedServiceType = 'package';
    } else {
      _selectedServiceType = 'sitter';
    }
  }

  Future<void> _loadAllData() async {
    final lookup = _effectiveLookup;
    if (lookup.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Provider information is not available.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.fetchCustomerProviderDetail(providerLookup: lookup),
        ApiService.fetchProviderReviews(providerLookup: lookup),
      ]);

      final detail = results[0] as Map<String, dynamic>?;
      final reviews = results[1] as List<Map<String, dynamic>>? ?? [];

      if (!mounted) return;

      if (detail != null) {
        _detail = detail;
        _reviews = reviews;
        _selectDefaultService(detail);
        setState(() {
          _isLoading = false;
        });
      } else if (widget.walker != null || widget.initialProviderData != null) {
        // Fallback to initial data if detailed endpoint failed
        final fallback = _buildFallbackDetail();
        _detail = fallback;
        _reviews = reviews;
        _selectDefaultService(fallback);
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load provider profile.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (widget.walker != null || widget.initialProviderData != null) {
        final fallback = _buildFallbackDetail();
        _detail = fallback;
        _selectDefaultService(fallback);
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to connect. Please check your network.';
        });
      }
    }
  }

  Map<String, dynamic> _buildFallbackDetail() {
    if (widget.initialProviderData != null) {
      return Map<String, dynamic>.from(widget.initialProviderData!);
    }
    final w = widget.walker!;
    return {
      'id': w.id,
      'name': w.fullName,
      'username': w.username,
      'city': w.city,
      'is_verified': w.isVerified,
      'profile_image': w.profileImage,
      'rating': w.averageRating > 0 ? w.averageRating : null,
      'review_count': w.reviewCount,
      'bio': w.providerDescription ?? '',
      'experience_years': 0,
      'pet_types': <String>[],
      'sitter_service': w.walkingCharge != null && w.walkingCharge! > 0
          ? {
              'sitter_enabled': true,
              'sitter_price': w.walkingCharge!.toDouble(),
              'sitter_duration_mins': 60,
            }
          : null,
      'packages': <Map<String, dynamic>>[],
    };
  }

  void _selectDefaultService(Map<String, dynamic> data) {
    final sitter = data['sitter_service'] as Map<String, dynamic>?;
    final hasSitter = sitter != null &&
        sitter['sitter_enabled'] == true &&
        ((sitter['sitter_price'] as num?)?.toDouble() ?? 0) > 0;

    final rawPkgs = data['packages'];
    final packages = (rawPkgs is List ? rawPkgs : [])
        .whereType<Map<String, dynamic>>()
        .where((p) => p['enabled'] == true && ((p['price'] as num?)?.toDouble() ?? 0) > 0)
        .toList();

    if (_selectedServiceType == 'package' && packages.isNotEmpty) {
      // Prefer Silver if enabled, else first available
      final silver = packages.firstWhere(
        (p) => (p['tier'] ?? '').toString().toLowerCase() == 'silver',
        orElse: () => packages.first,
      );
      _selectedPackageId = silver['id'] as int?;
      _selectedTier = silver['tier']?.toString();
      _selectedPrice = ((silver['price'] as num?)?.toDouble() ?? 0.0);
    } else if (hasSitter) {
      _selectedServiceType = 'sitter';
      _selectedPackageId = null;
      _selectedTier = null;
      _selectedPrice = ((sitter['sitter_price'] as num?)?.toDouble() ?? 0.0);
    } else if (packages.isNotEmpty) {
      _selectedServiceType = 'package';
      final first = packages.first;
      _selectedPackageId = first['id'] as int?;
      _selectedTier = first['tier']?.toString();
      _selectedPrice = ((first['price'] as num?)?.toDouble() ?? 0.0);
    }
  }

  double get _minimumDisplayPrice {
    if (_detail == null) return 0.0;
    double? minP;

    final sitter = _detail!['sitter_service'] as Map<String, dynamic>?;
    if (sitter != null && sitter['sitter_enabled'] == true) {
      final p = (sitter['sitter_price'] as num?)?.toDouble();
      if (p != null && p > 0) minP = p;
    }

    final rawPkgs = _detail!['packages'];
    if (rawPkgs is List) {
      for (final item in rawPkgs) {
        if (item is Map && item['enabled'] == true) {
          final p = (item['price'] as num?)?.toDouble();
          if (p != null && p > 0) {
            if (minP == null || p < minP) minP = p;
          }
        }
      }
    }
    return minP ?? _selectedPrice;
  }

  Future<void> _handleBookNow() async {
    final currentUser = widget.userLookup?.trim();
    if (currentUser == null || currentUser.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in to book this sitter.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _showBookingFormSheet(currentUser);
  }

  void _showBookingFormSheet(String currentUser) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedStartTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay selectedEndTime = const TimeOfDay(hour: 12, minute: 0);
    final petNameController = TextEditingController();
    final notesController = TextEditingController();
    String selectedPetType = 'Dog';

    final serviceLabel = _selectedServiceType == 'package'
        ? '${(_selectedTier ?? 'Care').toUpperCase()} Package'
        : 'Pet Sitter Session';
    final priceToPay = _selectedPrice > 0 ? _selectedPrice : _minimumDisplayPrice;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            const fullWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
            const fullMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
            final formattedDateStr = '${fullWeekdays[selectedDate.weekday - 1]}, ${fullMonths[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Booking',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: PawStayTheme.onSurface,
                              ),
                            ),
                            Text(
                              serviceLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: PawStayTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${_fmtPrice(priceToPay)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: PawStayTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Date Selection
                    Text(
                      'Booking Date',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: modalCtx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF0E5DF)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: PawStayTheme.primary),
                                const SizedBox(width: 10),
                                Text(
                                  formattedDateStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: PawStayTheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.edit_calendar_rounded, size: 18, color: PawStayTheme.primary),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Time Range
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: PawStayTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: modalCtx,
                                    initialTime: selectedStartTime,
                                  );
                                  if (picked != null) {
                                    setModalState(() => selectedStartTime = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF9F6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFF0E5DF)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        selectedStartTime.format(modalCtx),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, size: 16, color: PawStayTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: PawStayTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: modalCtx,
                                    initialTime: selectedEndTime,
                                  );
                                  if (picked != null) {
                                    setModalState(() => selectedEndTime = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF9F6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFF0E5DF)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        selectedEndTime.format(modalCtx),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, size: 16, color: PawStayTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Pet Info
                    Text(
                      'Pet Information',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: petNameController,
                      decoration: InputDecoration(
                        hintText: 'Pet Name (e.g., Buddy)',
                        prefixIcon: const Icon(Icons.pets, size: 18, color: PawStayTheme.primary),
                        filled: true,
                        fillColor: const Color(0xFFFFF9F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFF0E5DF)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFF0E5DF)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Pet Type Chips
                    Row(
                      children: ['Dog', 'Cat', 'Bird', 'Other'].map((type) {
                        final isSel = selectedPetType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: isSel,
                            selectedColor: PawStayTheme.primary,
                            labelStyle: GoogleFonts.plusJakartaSans(
                              color: isSel ? Colors.white : PawStayTheme.onSurface,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) setModalState(() => selectedPetType = type);
                            },
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    Text(
                      'Special Notes / Instructions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Feeding times, allergies, temperaments, etc.',
                        filled: true,
                        fillColor: const Color(0xFFFFF9F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFF0E5DF)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFF0E5DF)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final startDt = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedStartTime.hour,
                            selectedStartTime.minute,
                          );
                          final endDt = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedEndTime.hour,
                            selectedEndTime.minute,
                          );

                          final pName = petNameController.text.trim();

                          setState(() => _isBooking = true);
                          final payload = <String, dynamic>{
                            'provider_lookup': _effectiveLookup,
                            'provider_id': _effectiveLookup,
                            'service_type': _selectedServiceType,
                            if (_selectedServiceType == 'package' && _selectedPackageId != null)
                              'package_id': _selectedPackageId,
                            if (_selectedServiceType == 'package' && _selectedTier != null)
                              'tier': _selectedTier,
                            'price': priceToPay,
                            'customer_lookup': currentUser,
                            'customer_id': currentUser,
                            'start_datetime': startDt.toIso8601String(),
                            'end_datetime': endDt.toIso8601String(),
                            'pet_name': pName.isNotEmpty ? pName : 'Pet',
                            'pet_type': selectedPetType,
                            'notes': notesController.text.trim(),
                          };

                          final result = await ApiService.createBooking(payload);
                          if (!mounted) return;
                          setState(() => _isBooking = false);

                          final bool succeeded = result['success'] == true ||
                              result['id'] != null ||
                              result['booking'] != null;

                          if (succeeded) {
                            // Close modal first, then celebrate
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showBookingSuccessDialog();
                          } else {
                            final errMsg = result['error']?.toString() ??
                                'Failed to submit booking. Please try again.';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  errMsg,
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                                ),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Confirm & Request Booking',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBookingSuccessDialog() {
    final serviceLabel = _selectedServiceType == 'package'
        ? '${(_selectedTier ?? 'Care').toUpperCase()} Package'
        : 'Pet Sitter Session';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: PawStayTheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: PawStayTheme.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Booking Requested',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: PawStayTheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Your request for $serviceLabel with ${_detail?['name'] ?? widget.walker?.fullName ?? 'your sitter'} for ₹${_fmtPrice(_selectedPrice > 0 ? _selectedPrice : _minimumDisplayPrice)} has been submitted with status: Pending. The provider has been notified and you will receive an update once confirmed.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: PawStayTheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: PawStayTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final currentUser = widget.userLookup?.trim();
    if (currentUser == null || currentUser.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in before starting a chat.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final providerId = _effectiveLookup;
    final providerName = _detail?['name']?.toString() ??
        widget.walker?.fullName ??
        'Service Provider';
    final avatarUrl = _detail?['profile_image']?.toString() ??
        widget.walker?.profileImage;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.messageBaseUrl}/conversations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': currentUser,
          'contact_id': providerId,
          'contact_name': providerName,
          'contact_avatar_url': avatarUrl,
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
            contactName: providerName,
            contactAvatarUrl: avatarUrl,
            userId: currentUser,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open chat. Please try again.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAllReviewsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PawStayTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Client Reviews (${_reviews.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: _reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildReviewCard(_reviews[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF9F6);

    return Scaffold(
      backgroundColor: bg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PawStayTheme.primary),
            )
          : _errorMessage != null && _detail == null
              ? _buildErrorView()
              : Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        _buildAppBar(context, bg),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                _buildHeroCard(),
                                const SizedBox(height: 20),
                                _buildAboutSection(),
                                const SizedBox(height: 20),
                                _buildServicesSection(),
                                const SizedBox(height: 20),
                                _buildDetailsSection(),
                                if (_reviews.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _buildReviewsSection(),
                                ],
                                const SizedBox(height: 110), // Bottom bar clearance
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildStickyBottomBar(context),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: PawStayTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Profile Not Available',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to PawStay.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PawStayTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Color bg) {
    return SliverAppBar(
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
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1E1E1E),
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
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Hero card: avatar/initial, name, verified tick, city, stats row. NO email.
  // ---------------------------------------------------------------------------
  Widget _buildHeroCard() {
    final name = (_detail?['name'] ?? widget.walker?.fullName ?? 'Pet Sitter').toString();
    final city = (_detail?['city'] ?? widget.walker?.city ?? '').toString().trim();
    final isVerified = _detail?['is_verified'] == true || widget.walker?.isVerified == true;

    final dynamic ratingRaw = _detail?['rating'] ?? (widget.walker?.averageRating != null && widget.walker!.averageRating > 0 ? widget.walker!.averageRating : null);
    final double? rating = ratingRaw is num ? ratingRaw.toDouble() : double.tryParse('$ratingRaw');

    final dynamic reviewCountRaw = _detail?['review_count'] ?? widget.walker?.reviewCount ?? _reviews.length;
    final int reviewCount = reviewCountRaw is int ? reviewCountRaw : int.tryParse('$reviewCountRaw') ?? 0;

    final dynamic expRaw = _detail?['experience_years'];
    final int expYears = expRaw is int ? expRaw : int.tryParse('$expRaw') ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFCEEE8),
              boxShadow: [
                BoxShadow(
                  color: PawStayTheme.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: _buildAvatar(name, 88)),
          ),
          const SizedBox(height: 14),

          // Name + Verified Tick
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: PawStayTheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),

          if (city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: PawStayTheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  city,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Stats row: rating · reviews · experience yrs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF3EC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rating
                if (rating != null && rating > 0 && reviewCount > 0) ...[
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.onSurface,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: PawStayTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'New',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.secondary,
                      ),
                    ),
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '·',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.outlineVariant,
                    ),
                  ),
                ),

                // Reviews
                Text(
                  reviewCount == 1 ? '1 review' : '$reviewCount reviews',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '·',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.outlineVariant,
                    ),
                  ),
                ),

                // Experience
                Text(
                  expYears > 0 ? '$expYears yrs exp' : 'PawStay Care',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. About: bio; if empty show "This sitter hasn't added a description yet."
  // ---------------------------------------------------------------------------
  Widget _buildAboutSection() {
    final bio = (_detail?['bio'] ?? widget.walker?.providerDescription ?? '').toString().trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bio.isNotEmpty ? bio : "This sitter hasn't added a description yet.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: bio.isNotEmpty
                  ? PawStayTheme.onSurface
                  : PawStayTheme.onSurfaceVariant,
              height: 1.5,
              fontStyle: bio.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Services: section customer came from shows first.
  //    Pet Sitter = single card (price, duration).
  //    Packages = 3 cards: tier badge, price, duration, checklist, "Most Popular" on Silver.
  //    Hide disabled/unpriced services entirely; no "pricing not provided" text.
  // ---------------------------------------------------------------------------
  Widget _buildServicesSection() {
    final sitter = _detail?['sitter_service'] as Map<String, dynamic>?;
    final isSitterEnabled = sitter != null &&
        sitter['sitter_enabled'] == true &&
        ((sitter['sitter_price'] as num?)?.toDouble() ?? 0) > 0;

    final rawPkgs = _detail?['packages'];
    final packages = (rawPkgs is List ? rawPkgs : [])
        .whereType<Map<String, dynamic>>()
        .where((p) => p['enabled'] == true && ((p['price'] as num?)?.toDouble() ?? 0) > 0)
        .toList();

    if (!isSitterEnabled && packages.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool packagesFirst = widget.initialCategory.toLowerCase().contains('pack');

    final sitterWidget = isSitterEnabled
        ? _buildSitterCard(sitter)
        : null;

    final packagesWidget = packages.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: packages.map(_buildPackageCard).toList(),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services & Packages',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PawStayTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (packagesFirst) ...[
          ?packagesWidget,
          if (sitterWidget != null) ...[
            if (packagesWidget != null) const SizedBox(height: 12),
            sitterWidget,
          ],
        ] else ...[
          ?sitterWidget,
          if (packagesWidget != null) ...[
            if (sitterWidget != null) const SizedBox(height: 12),
            packagesWidget,
          ],
        ],
      ],
    );
  }

  Widget _buildSitterCard(Map<String, dynamic> sitter) {
    final price = (sitter['sitter_price'] as num?)?.toDouble() ?? 0.0;
    final duration = sitter['sitter_duration_mins'] ?? 60;
    final isSelected = _selectedServiceType == 'sitter';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedServiceType = 'sitter';
          _selectedPackageId = null;
          _selectedTier = null;
          _selectedPrice = price;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? PawStayTheme.primary : Colors.transparent,
            width: isSelected ? 2.0 : 0.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? PawStayTheme.primary.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFCEEE8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: PawStayTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pet Sitter',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF3EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$duration mins',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PawStayTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attentive, dedicated in-person sitting & care session',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${_fmtPrice(price)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.primary,
                  ),
                ),
                Text(
                  '/ session',
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

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final id = pkg['id'] as int?;
    final tier = (pkg['tier'] ?? 'Package').toString().toLowerCase();
    final price = (pkg['price'] as num?)?.toDouble() ?? 0.0;
    final durVal = pkg['duration_value'] ?? 1;
    final durUnit = (pkg['duration_unit'] ?? 'hours').toString();
    final meals = (pkg['meals_per_day'] as num?)?.toInt() ?? 0;
    final walks = (pkg['walks_per_day'] as num?)?.toInt() ?? 0;
    final desc = (pkg['description'] ?? '').toString().trim();
    final rawInclusions = pkg['inclusions'];
    final inclusions = rawInclusions is List
        ? rawInclusions.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final isSilver = tier == 'silver';
    final isSelected = _selectedServiceType == 'package' &&
        (_selectedPackageId == id || (_selectedPackageId == null && _selectedTier == tier));

    Color tierColor;
    Color tierBg;
    if (tier == 'bronze') {
      tierColor = const Color(0xFFB45309);
      tierBg = const Color(0xFFFEF3C7);
    } else if (tier == 'gold') {
      tierColor = const Color(0xFFD97706);
      tierBg = const Color(0xFFFFFBEB);
    } else {
      // Silver
      tierColor = const Color(0xFF475569);
      tierBg = const Color(0xFFF1F5F9);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedServiceType = 'package';
          _selectedPackageId = id;
          _selectedTier = tier;
          _selectedPrice = price;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? PawStayTheme.primary : Colors.transparent,
            width: isSelected ? 2.0 : 0.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? PawStayTheme.primary.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Tier badge, Most Popular tag, and Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tierBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tier.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: tierColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (isSilver) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: PawStayTheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                size: 13, color: PawStayTheme.primary),
                            const SizedBox(width: 3),
                            Text(
                              'Most Popular',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: PawStayTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_fmtPrice(price)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.primary,
                      ),
                    ),
                    Text(
                      '$durVal $durUnit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: PawStayTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: PawStayTheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF5EBE6)),
            const SizedBox(height: 12),

            // Checklist
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                if (meals > 0)
                  _buildCheckItem('$meals ${meals == 1 ? 'meal' : 'meals'}/day'),
                if (walks > 0)
                  _buildCheckItem('$walks ${walks == 1 ? 'walk' : 'walks'}/day'),
                ...inclusions.map(_buildCheckItem),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 13,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: PawStayTheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Details: pet types, city.
  // ---------------------------------------------------------------------------
  Widget _buildDetailsSection() {
    final rawPetTypes = _detail?['pet_types'];
    final petTypes = rawPetTypes is List
        ? rawPetTypes.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final city = (_detail?['city'] ?? widget.walker?.city ?? '').toString().trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),

          // Accepted Pet Types
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.pets_rounded, size: 18, color: PawStayTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accepted Pets',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (petTypes.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: petTypes
                            .map(
                              (p) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF0EB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  p,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: PawStayTheme.primary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      )
                    else
                      Text(
                        'All pet types welcome',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (city.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF5EBE6)),
            const SizedBox(height: 14),

            // City
            Row(
              children: [
                const Icon(Icons.location_city_rounded,
                    size: 18, color: PawStayTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Location',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        city,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Reviews preview (top 2-3, "See all") only if reviews exist.
  // ---------------------------------------------------------------------------
  Widget _buildReviewsSection() {
    final preview = _reviews.take(3).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Client Reviews (${_reviews.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PawStayTheme.onSurface,
                ),
              ),
              if (_reviews.length > 3)
                TextButton(
                  onPressed: _showAllReviewsSheet,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See all',
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
          ...preview.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildReviewCard(r),
              )),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final name = (review['user_name'] ?? review['user_lookup'] ?? 'Client').toString();
    final description = (review['description'] ?? '').toString();
    final rating = (review['rating'] as num?)?.toDouble() ?? 5.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF9F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: PawStayTheme.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: PawStayTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (idx) => Icon(
                    idx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 14,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: PawStayTheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Sticky bottom bar: "From ₹X", Chat (outlined) + Book Now (filled).
  // ---------------------------------------------------------------------------
  Widget _buildStickyBottomBar(BuildContext context) {
    final displayPrice = _selectedPrice > 0 ? _selectedPrice : _minimumDisplayPrice;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Row(
          children: [
            // Price Display
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPrice > 0 ? 'Selected' : 'From',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '₹${_fmtPrice(displayPrice)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Outlined Chat button
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => _openChat(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(
                  'Chat',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PawStayTheme.primary,
                  side: const BorderSide(color: PawStayTheme.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Filled Book Now button
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _handleBookNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PawStayTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isBooking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Book Now',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, double size) {
    final img = _detail?['profile_image']?.toString() ??
        widget.walker?.profileImage;

    if (img != null && img.trim().isNotEmpty) {
      try {
        final raw = img.trim();
        final bytes = base64Decode(raw.contains(',') ? raw.split(',').last : raw);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsAvatar(name, size),
        );
      } catch (_) {}
    }
    return _initialsAvatar(name, size);
  }

  Widget _initialsAvatar(String name, double size) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
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
