import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String? providerLookup;

  const ProviderProfileScreen({super.key, this.providerLookup});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  final ImagePicker _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _walkingChargeController =
      TextEditingController();
  final TextEditingController _daycareChargeController =
      TextEditingController();
  final TextEditingController _daycareFoodChargeController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _displayName = 'Service Provider';
  String _location = 'PawStay Verified';
  String _rating = '4.9 (184 reviews)';
  String? _profileImageBase64;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _charCount = _descriptionController.text.length;
    _descriptionController.addListener(() {
      if (mounted) {
        setState(() {
          _charCount = _descriptionController.text.length;
        });
      }
    });
    _loadProfileData();
  }

  @override
  void dispose() {
    _walkingChargeController.dispose();
    _daycareChargeController.dispose();
    _daycareFoodChargeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final lookup = widget.providerLookup;
    if (lookup == null || lookup.trim().isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profile = await ApiService.fetchProviderProfile(
        providerLookup: lookup.trim(),
      );
      if (profile != null && mounted) {
        setState(() {
          if (profile['full_name'] != null &&
              profile['full_name'].toString().trim().isNotEmpty) {
            _displayName = profile['full_name'].toString().trim();
          } else if (profile['username'] != null &&
              profile['username'].toString().trim().isNotEmpty) {
            _displayName = profile['username'].toString().trim();
          }

          if (profile['city'] != null &&
              profile['city'].toString().trim().isNotEmpty) {
            _location = profile['city'].toString().trim();
          } else if (profile['location'] != null &&
              profile['location'].toString().trim().isNotEmpty) {
            _location = profile['location'].toString().trim();
          }

          if (profile['profile_image'] != null &&
              profile['profile_image'].toString().isNotEmpty) {
            _profileImageBase64 = profile['profile_image'].toString();
          }

          if (profile['walking_charge'] != null) {
            _walkingChargeController.text = profile['walking_charge']
                .toString();
          }
          if (profile['daycare_charge'] != null) {
            _daycareChargeController.text = profile['daycare_charge']
                .toString();
          }
          if (profile['daycare_food_charge'] != null) {
            _daycareFoodChargeController.text = profile['daycare_food_charge']
                .toString();
          }
          if (profile['provider_description'] != null &&
              profile['provider_description'].toString().trim().isNotEmpty) {
            _descriptionController.text = profile['provider_description']
                .toString()
                .trim();
            _charCount = _descriptionController.text.length;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading provider profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isError ? PawStayTheme.error : PawStayTheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final lookup = widget.providerLookup;
    if (lookup == null || lookup.trim().isEmpty) {
      _showSnack('Provider identifier missing.', isError: true);
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );

      if (file == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final success = await ApiService.uploadProfilePhoto(
        providerLookup: lookup.trim(),
        base64Image: base64Image,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _profileImageBase64 = base64Image;
          });
          _showSnack('Profile photo updated successfully!');
        } else {
          _showSnack('Failed to update profile photo.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error picking image: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final lookup = widget.providerLookup;
    if (lookup == null || lookup.trim().isEmpty) {
      _showSnack('Provider lookup identifier missing.', isError: true);
      return;
    }

    final walking = int.tryParse(_walkingChargeController.text.trim()) ?? 0;
    final daycare = int.tryParse(_daycareChargeController.text.trim()) ?? 0;
    final daycareFood =
        int.tryParse(_daycareFoodChargeController.text.trim()) ?? 0;
    final desc = _descriptionController.text.trim();

    if (walking <= 0 || daycare <= 0 || daycareFood <= 0) {
      _showSnack('Please enter valid positive pricing amounts.', isError: true);
      return;
    }

    if (desc.isEmpty) {
      _showSnack(
        'Please provide a short description of your experience.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await ApiService.updateProviderProfile(
      providerLookup: lookup.trim(),
      walkingCharge: walking,
      daycareCharge: daycare,
      daycareFoodCharge: daycareFood,
      description: desc,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        _showSnack('Profile changes saved successfully!');
        Navigator.pop(context, true);
      } else {
        _showSnack(
          'Failed to save profile changes. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _resetToDefaults() {
    setState(() {
      _walkingChargeController.clear();
      _daycareChargeController.clear();
      _daycareFoodChargeController.clear();
      _descriptionController.clear();
      _charCount = 0;
    });
    _showSnack('Form cleared. Enter your custom pricing & bio.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: PawStayTheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: PawStayTheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets,
                size: 18,
                color: PawStayTheme.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Provider Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: PawStayTheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: PawStayTheme.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PawStayTheme.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: PawStayTheme.marginMobile,
                vertical: 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 1. Header Profile Card
                    _buildProfileHeaderCard(),

                    const SizedBox(height: 20),

                    // 2. Service Charges & Pricing Card
                    _buildPricingCard(),

                    const SizedBox(height: 20),

                    // 3. Service Provider Description Card
                    _buildDescriptionCard(),

                    const SizedBox(height: 20),

                    // 4. Info Notice Banner
                    _buildNoticeBanner(),

                    const SizedBox(height: 24),

                    // 5. Save Changes Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          _isSaving ? 'Saving Changes...' : 'Save Changes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PawStayTheme.radiusMd,
                            ),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 6. Reset to Defaults Text Button
                    TextButton(
                      onPressed: _resetToDefaults,
                      child: Text(
                        'Reset to Defaults',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        border: Border.all(color: PawStayTheme.surfaceDim),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar with camera icon overlay (No external placeholder photos used)
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PawStayTheme.primaryContainer,
                  ),
                  child: ClipOval(
                    child:
                        _profileImageBase64 != null &&
                            _profileImageBase64!.isNotEmpty
                        ? Image.memory(
                            base64Decode(_profileImageBase64!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                _displayName.isNotEmpty
                                    ? _displayName[0].toUpperCase()
                                    : 'P',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: PawStayTheme.primary,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _displayName.isNotEmpty
                                  ? _displayName[0].toUpperCase()
                                  : 'P',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: PawStayTheme.primary,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: PawStayTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _isUploadingPhoto
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Verified Provider Name
          Text(
            _displayName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),

          const SizedBox(height: 10),

          // Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Verified Care Provider tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: PawStayTheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: PawStayTheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Care Provider',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PawStayTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Rating Tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _rating,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Top Rated Sitter banner container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: PawStayTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.pets_rounded,
                      size: 18,
                      color: PawStayTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Rated Sitter',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSurface,
                          ),
                        ),
                        Text(
                          '99% response rate',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PawStayTheme.surfaceDim),
                  ),
                  child: Text(
                    _location,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        border: Border.all(color: PawStayTheme.surfaceDim),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PawStayTheme.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: PawStayTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Service Charges & Pricing',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Set your service rates in Indian Rupees (₹). Clients will see these rates when booking your services.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: PawStayTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // 1. Pet Walking Charges
          _buildChargeInputField(
            title: 'Pet Walking Charges',
            badgeLabel: 'Per Session',
            unitLabel: '/ 45 mins',
            controller: _walkingChargeController,
            note: 'Standard rate per dog walking session',
          ),

          const SizedBox(height: 16),

          // 2. Day Care Charges
          _buildChargeInputField(
            title: 'Day Care Charges',
            badgeLabel: 'Base Rate',
            unitLabel: '/ day',
            controller: _daycareChargeController,
            note: 'Full day pet sitting & supervision at your location',
          ),

          const SizedBox(height: 16),

          // 3. Day Care + Food Charges
          _buildChargeInputField(
            title: 'Day Care + Food Charges',
            badgeLabel: 'All-Inclusive',
            unitLabel: '/ day',
            controller: _daycareFoodChargeController,
            note: 'Day care combined with nutritious organic meals and snacks',
          ),
        ],
      ),
    );
  }

  Widget _buildChargeInputField({
    required String title,
    required String badgeLabel,
    required String unitLabel,
    required TextEditingController controller,
    required String note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            Text(
              badgeLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: PawStayTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(PawStayTheme.radiusDefault),
            border: Border.all(
              color: PawStayTheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Text(
                '₹ ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: PawStayTheme.primary,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter rate';
                    if (int.tryParse(val.trim()) == null) return 'Invalid rate';
                    return null;
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: PawStayTheme.surfaceDim.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unitLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 14,
              color: PawStayTheme.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: PawStayTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        border: Border.all(color: PawStayTheme.surfaceDim),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PawStayTheme.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: PawStayTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Service Provider Description',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'About You & Your Experience',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PawStayTheme.onSurface,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: PawStayTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(PawStayTheme.radiusDefault),
              border: Border.all(
                color: PawStayTheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 500,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: PawStayTheme.onSurface,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Write a brief description of your pet care services and background...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'Description cannot be empty';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: PawStayTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Warm & Friendly tone',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_charCount / 500 characters',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PawStayTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PawStayTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
        border: Border.all(
          color: PawStayTheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.handshake_outlined,
            size: 20,
            color: PawStayTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your pricing changes update instantly for all new prospective booking inquiries. Active stays remain protected at previous agreed rates.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: PawStayTheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
