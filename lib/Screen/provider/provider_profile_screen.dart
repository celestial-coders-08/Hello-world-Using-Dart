import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../auth/login.dart';

const _kPetTypes = ['Dog', 'Cat', 'Bird', 'Fish', 'Rabbit', 'Hamster', 'Turtle'];
const _kSuggestions = [
  'Walk', 'Playtime', 'Treats', 'Photo updates', 'Fresh water',
  'Grooming', 'Training', 'Medication', 'All meals', 'Snacks',
];

String _fmtNum(dynamic v) {
  if (v == null) return '';
  if (v is int) return v == 0 ? '' : v.toString();
  if (v is double) {
    if (v == 0.0) return '';
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }
  return v.toString();
}

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

  // Identity (read-only from backend)
  String _displayName = 'Service Provider';
  String _locationLabel = 'PawStay Verified';
  String? _profileImageBase64;
  double? _rating;
  int _reviewCount = 0;

  // Profile fields
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController(text: '0');
  List<String> _petTypes = [];
  int _bioCharCount = 0;

  // Sitter service
  bool _sitterEnabled = false;
  final _sitterPriceCtrl = TextEditingController();
  final _sitterDurationCtrl = TextEditingController(text: '60');

  // Packages
  late final List<_PackageFormData> _packages;

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: PawStayTheme.onSurface,
      );

  @override
  void initState() {
    super.initState();
    _packages = [
      _PackageFormData(tier: 'bronze', label: 'Bronze'),
      _PackageFormData(tier: 'silver', label: 'Silver'),
      _PackageFormData(tier: 'gold', label: 'Gold'),
    ];
    _bioCtrl.addListener(() {
      if (mounted) setState(() => _bioCharCount = _bioCtrl.text.length);
    });
    _loadProfileData();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _experienceCtrl.dispose();
    _sitterPriceCtrl.dispose();
    _sitterDurationCtrl.dispose();
    for (final p in _packages) {
      p.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------
  Future<void> _loadProfileData() async {
    final lookup = widget.providerLookup?.trim();
    if (lookup == null || lookup.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final profile = await ApiService.fetchProviderProfile(
        providerLookup: lookup,
      );
      if (profile != null && mounted) {
        setState(() {
          // Identity
          final fullName = profile['full_name']?.toString().trim();
          final username = profile['username']?.toString().trim();
          if (fullName != null && fullName.isNotEmpty) {
            _displayName = fullName;
          } else if (username != null && username.isNotEmpty) {
            _displayName = username;
          }

          if (profile['profile_image']?.toString().isNotEmpty == true) {
            _profileImageBase64 = profile['profile_image'].toString();
          }

          _rating = (profile['average_rating'] as num?)?.toDouble();
          _reviewCount = (profile['review_count'] as num?)?.toInt() ?? 0;

          // Profile nested
          final p = profile['profile'];
          if (p is Map<String, dynamic>) {
            _bioCtrl.text = p['bio']?.toString() ?? '';
            _cityCtrl.text = p['city']?.toString() ?? '';
            _experienceCtrl.text = (p['experience_years'] ?? 0).toString();
            if (p['pet_types'] is List) {
              _petTypes = List<String>.from(p['pet_types']);
            }
          }

          // Backward compat
          if (_bioCtrl.text.isEmpty) {
            _bioCtrl.text =
                profile['provider_description']?.toString().trim() ?? '';
          }
          if (_cityCtrl.text.isEmpty) {
            _cityCtrl.text = profile['city']?.toString().trim() ?? '';
          }
          _locationLabel = _cityCtrl.text.isNotEmpty
              ? _cityCtrl.text
              : (profile['location']?.toString().trim() ?? 'PawStay Verified');

          // Sitter
          final s = profile['sitter_service'];
          if (s is Map<String, dynamic>) {
            _sitterEnabled = s['sitter_enabled'] == true;
            _sitterPriceCtrl.text = _fmtNum(s['sitter_price']);
            _sitterDurationCtrl.text =
                (s['sitter_duration_mins'] ?? 60).toString();
          }

          // Backward compat: old walking_charge
          if (!_sitterEnabled && _sitterPriceCtrl.text.isEmpty) {
            final wc = profile['walking_charge'];
            if (wc != null && wc != 0) {
              _sitterEnabled = true;
              _sitterPriceCtrl.text = _fmtNum(wc);
            }
          }

          // Packages
          final pkgList = profile['packages'];
          if (pkgList is List) {
            for (final pkgData in pkgList) {
              if (pkgData is Map<String, dynamic>) {
                final tier = pkgData['tier']?.toString();
                final match = _packages.where((p) => p.tier == tier);
                if (match.isNotEmpty) match.first.loadFrom(pkgData);
              }
            }
          }

          _bioCharCount = _bioCtrl.text.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading provider profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------
  String? _validateServices() {
    final anyEnabled = _sitterEnabled || _packages.any((p) => p.enabled);
    if (!anyEnabled) return 'Enable at least one service';

    if (_sitterEnabled) {
      final price = double.tryParse(_sitterPriceCtrl.text.trim()) ?? 0;
      if (price <= 0) return 'Sitter price must be greater than 0';
    }
    for (final pkg in _packages) {
      if (pkg.enabled) {
        final price = double.tryParse(pkg.priceCtrl.text.trim()) ?? 0;
        if (price <= 0) return '${pkg.label} package price must be > 0';
      }
    }

    final bronze = _packages[0];
    final silver = _packages[1];
    final gold = _packages[2];
    if (silver.enabled && bronze.enabled) {
      final sp = double.tryParse(silver.priceCtrl.text.trim()) ?? 0;
      final bp = double.tryParse(bronze.priceCtrl.text.trim()) ?? 0;
      if (sp < bp) return 'Silver price must be ≥ Bronze price';
    }
    if (gold.enabled && silver.enabled) {
      final gp = double.tryParse(gold.priceCtrl.text.trim()) ?? 0;
      final sp = double.tryParse(silver.priceCtrl.text.trim()) ?? 0;
      if (gp < sp) return 'Gold price must be ≥ Silver price';
    }
    if (gold.enabled && bronze.enabled && !silver.enabled) {
      final gp = double.tryParse(gold.priceCtrl.text.trim()) ?? 0;
      final bp = double.tryParse(bronze.priceCtrl.text.trim()) ?? 0;
      if (gp < bp) return 'Gold price must be ≥ Bronze price';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------
  Future<void> _saveProfile() async {
    // Expand enabled packages so form validators run
    bool needsRebuild = false;
    for (final p in _packages) {
      if (p.enabled && !p.expanded) {
        p.expanded = true;
        needsRebuild = true;
      }
    }
    if (needsRebuild) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!_formKey.currentState!.validate()) return;

    final error = _validateServices();
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    final lookup = widget.providerLookup?.trim();
    if (lookup == null || lookup.isEmpty) {
      _showSnack('Provider lookup identifier missing.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'profile': {
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'experience_years': int.tryParse(_experienceCtrl.text.trim()) ?? 0,
        'pet_types': _petTypes,
      },
      'sitter_service': {
        'sitter_enabled': _sitterEnabled,
        'sitter_price':
            double.tryParse(_sitterPriceCtrl.text.trim()) ?? 0.0,
        'sitter_duration_mins':
            int.tryParse(_sitterDurationCtrl.text.trim()) ?? 60,
      },
      'packages': _packages.map((p) => p.toJson()).toList(),
    };

    final success = await ApiService.updateProviderServices(
      providerLookup: lookup,
      payload: payload,
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
      _bioCtrl.clear();
      _cityCtrl.clear();
      _experienceCtrl.text = '0';
      _petTypes.clear();
      _sitterEnabled = false;
      _sitterPriceCtrl.clear();
      _sitterDurationCtrl.text = '60';
      for (final p in _packages) {
        p.enabled = false;
        p.expanded = false;
        p.priceCtrl.clear();
        p.durationValueCtrl.text = '1';
        p.durationUnit = 'hours';
        p.mealsCtrl.text = '0';
        p.walksCtrl.text = '0';
        p.inclusions.clear();
        p.descCtrl.clear();
      }
      _bioCharCount = 0;
    });
    _showSnack('Form cleared. Enter your custom pricing & bio.');
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: PawStayTheme.onSurface),
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
              backgroundColor:
                  PawStayTheme.primaryContainer.withValues(alpha: 0.3),
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
                    _buildProfileHeaderCard(),
                    const SizedBox(height: 20),
                    _buildProfileDetailsCard(),
                    const SizedBox(height: 20),
                    _buildBioCard(),
                    const SizedBox(height: 20),
                    _buildSitterServiceCard(),
                    const SizedBox(height: 14),
                    ...List.generate(
                      _packages.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildPackageCard(_packages[i]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildNoticeBanner(),
                    const SizedBox(height: 24),

                    // Save button
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

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final preferences =
                              await SharedPreferences.getInstance();
                          if (!navigator.mounted) return;
                          await preferences.remove('access_token');
                          if (!navigator.mounted) return;
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(
                          'Log Out',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
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

  // ---------------------------------------------------------------------------
  // Profile Header Card
  // ---------------------------------------------------------------------------
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
          // Avatar
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
                    child: _profileImageBase64 != null &&
                            _profileImageBase64!.isNotEmpty
                        ? Image.memory(
                            base64Decode(_profileImageBase64!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatarFallback(),
                          )
                        : _avatarFallback(),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
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
          Text(
            _displayName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),

          const SizedBox(height: 10),
          // Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      PawStayTheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 14, color: PawStayTheme.secondary),
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
              _buildRatingBadge(),
            ],
          ),

          // Top Rated banner (only with real reviews)
          if (_rating != null && _rating! > 0 && _reviewCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: PawStayTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pets_rounded,
                          size: 18, color: PawStayTheme.primary),
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
                            '$_reviewCount reviews',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PawStayTheme.surfaceDim),
                    ),
                    child: Text(
                      _cityCtrl.text.isNotEmpty
                          ? _cityCtrl.text
                          : _locationLabel,
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
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'P',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: PawStayTheme.primary,
        ),
      ),
    );
  }

  Widget _buildRatingBadge() {
    if (_rating == null || _rating == 0 || _reviewCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: PawStayTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_new_rounded,
                size: 14, color: PawStayTheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'New',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            '${_rating!.toStringAsFixed(1)} ($_reviewCount reviews)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Details Card (city, experience, pet types)
  // ---------------------------------------------------------------------------
  Widget _buildProfileDetailsCard() {
    return _sectionCard(
      icon: Icons.badge_outlined,
      title: 'Profile Details',
      children: [
        _buildLabeledField('City', _cityCtrl,
            type: TextInputType.text, hint: 'e.g., Mumbai'),
        const SizedBox(height: 14),
        _buildLabeledField('Years of Experience', _experienceCtrl, hint: '0'),
        const SizedBox(height: 14),
        Text('Pet Types', style: _labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPetTypes.map((type) {
            final selected = _petTypes.contains(type);
            return FilterChip(
              label: Text(
                type,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
              ),
              selected: selected,
              onSelected: (val) => setState(() {
                if (val) {
                  _petTypes.add(type);
                } else {
                  _petTypes.remove(type);
                }
              }),
              selectedColor:
                  PawStayTheme.primaryContainer.withValues(alpha: 0.4),
              checkmarkColor: PawStayTheme.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bio Card
  // ---------------------------------------------------------------------------
  Widget _buildBioCard() {
    return _sectionCard(
      icon: Icons.edit_note_rounded,
      title: 'About You',
      children: [
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
                controller: _bioCtrl,
                maxLines: 4,
                maxLength: 500,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                    null,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: PawStayTheme.onSurface,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText:
                      'Tell pet parents about your experience, home setup and daily routine',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Bio cannot be empty'
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: PawStayTheme.primary),
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
                    '$_bioCharCount / 500 characters',
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
    );
  }

  // ---------------------------------------------------------------------------
  // Pet Sitter Service Card
  // ---------------------------------------------------------------------------
  Widget _buildSitterServiceCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        border: Border.all(
          color: _sitterEnabled
              ? PawStayTheme.primary.withValues(alpha: 0.4)
              : PawStayTheme.surfaceDim,
        ),
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
                  color:
                      PawStayTheme.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets_rounded,
                    size: 20, color: PawStayTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pet Sitter',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
              ),
              Switch(
                value: _sitterEnabled,
                onChanged: (val) => setState(() => _sitterEnabled = val),
                activeTrackColor: PawStayTheme.primary,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Offer pet sitting services at your location',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: PawStayTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (_sitterEnabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildLabeledField(
                    'Price (₹)',
                    _sitterPriceCtrl,
                    hint: '0',
                    validator: (val) {
                      if (!_sitterEnabled) return null;
                      final v =
                          double.tryParse(val?.trim() ?? '') ?? 0;
                      return v <= 0 ? 'Enter a valid price' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLabeledField(
                    'Duration (mins)',
                    _sitterDurationCtrl,
                    hint: '60',
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
  // Package Card (Bronze / Silver / Gold)
  // ---------------------------------------------------------------------------
  Widget _buildPackageCard(_PackageFormData pkg) {
    const tierColors = {
      'bronze': Color(0xFFCD7F32),
      'silver': Color(0xFF78909C),
      'gold': Color(0xFFD4A017),
    };
    final color = tierColors[pkg.tier] ?? PawStayTheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        border: Border.all(
          color: pkg.enabled
              ? color.withValues(alpha: 0.5)
              : PawStayTheme.surfaceDim,
        ),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => pkg.expanded = !pkg.expanded),
            borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.workspace_premium_rounded,
                        color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pkg.label} Package',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSurface,
                          ),
                        ),
                        if (pkg.enabled && pkg.priceCtrl.text.isNotEmpty)
                          Text(
                            '₹${pkg.priceCtrl.text}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: PawStayTheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: pkg.enabled,
                    onChanged: (val) => setState(() {
                      pkg.enabled = val;
                      if (val) pkg.expanded = true;
                    }),
                    activeTrackColor: PawStayTheme.primary,
                    activeThumbColor: Colors.white,
                  ),
                  Icon(
                    pkg.expanded ? Icons.expand_less : Icons.expand_more,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (pkg.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildLabeledField(
                    'Price (₹)',
                    pkg.priceCtrl,
                    hint: '0',
                    validator: (val) {
                      if (!pkg.enabled) return null;
                      final v =
                          double.tryParse(val?.trim() ?? '') ?? 0;
                      return v <= 0 ? 'Enter a valid price' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLabeledField(
                          'Duration',
                          pkg.durationValueCtrl,
                          hint: '1',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildUnitDropdown(pkg)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLabeledField(
                          'Meals/day',
                          pkg.mealsCtrl,
                          hint: '0',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLabeledField(
                          'Walks/day',
                          pkg.walksCtrl,
                          hint: '0',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInclusionsEditor(pkg),
                  const SizedBox(height: 12),
                  _buildLabeledField(
                    'Description',
                    pkg.descCtrl,
                    type: TextInputType.text,
                    maxLines: 2,
                    hint: 'Brief package description',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown(_PackageFormData pkg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unit', style: _labelStyle),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PawStayTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(PawStayTheme.radiusDefault),
            border: Border.all(
              color: PawStayTheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: pkg.durationUnit,
              isExpanded: true,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: PawStayTheme.onSurface,
              ),
              items: const [
                DropdownMenuItem(value: 'hours', child: Text('Hours')),
                DropdownMenuItem(value: 'days', child: Text('Days')),
              ],
              onChanged: (val) =>
                  setState(() => pkg.durationUnit = val ?? 'hours'),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Inclusions Editor
  // ---------------------------------------------------------------------------
  Widget _buildInclusionsEditor(_PackageFormData pkg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extras', style: _labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...pkg.inclusions.map(
              (inc) => InputChip(
                label:
                    Text(inc, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                onDeleted: () =>
                    setState(() => pkg.inclusions.remove(inc)),
                backgroundColor: PawStayTheme.surfaceContainerLow,
                deleteIconColor: PawStayTheme.onSurfaceVariant,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label:
                  Text('Add', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              onPressed: () => _showAddInclusionDialog(pkg),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (_kSuggestions.any((s) => !pkg.inclusions.contains(s)))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _kSuggestions
                  .where((s) => !pkg.inclusions.contains(s))
                  .take(6)
                  .map(
                    (s) => GestureDetector(
                      onTap: () =>
                          setState(() => pkg.inclusions.add(s)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: PawStayTheme.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+ $s',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  void _showAddInclusionDialog(_PackageFormData pkg) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Extra',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g., Grooming, Photo updates'),
          onSubmitted: (val) {
            final text = val.trim();
            if (text.isNotEmpty && !pkg.inclusions.contains(text)) {
              setState(() => pkg.inclusions.add(text));
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && !pkg.inclusions.contains(text)) {
                setState(() => pkg.inclusions.add(text));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
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
                  color:
                      PawStayTheme.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: PawStayTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabeledField(
    String label,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.number,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: PawStayTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(PawStayTheme.radiusDefault),
            border: Border.all(
              color: PawStayTheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: TextFormField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            validator: validator,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: PawStayTheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
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

// ---------------------------------------------------------------------------
// Package Form Data Helper
// ---------------------------------------------------------------------------
class _PackageFormData {
  final String tier;
  final String label;
  bool enabled;
  bool expanded;
  int? id;
  final TextEditingController priceCtrl;
  final TextEditingController durationValueCtrl;
  String durationUnit;
  final TextEditingController mealsCtrl;
  final TextEditingController walksCtrl;
  List<String> inclusions;
  final TextEditingController descCtrl;

  _PackageFormData({required this.tier, required this.label})
      : enabled = false,
        expanded = false,
        priceCtrl = TextEditingController(),
        durationValueCtrl = TextEditingController(text: '1'),
        durationUnit = 'hours',
        mealsCtrl = TextEditingController(text: '0'),
        walksCtrl = TextEditingController(text: '0'),
        inclusions = [],
        descCtrl = TextEditingController();

  void dispose() {
    priceCtrl.dispose();
    durationValueCtrl.dispose();
    mealsCtrl.dispose();
    walksCtrl.dispose();
    descCtrl.dispose();
  }

  void loadFrom(Map<String, dynamic> data) {
    id = data['id'] as int?;
    enabled = data['enabled'] == true;
    priceCtrl.text = _fmtNum(data['price']);
    durationValueCtrl.text = (data['duration_value'] ?? 1).toString();
    durationUnit = (data['duration_unit'] ?? 'hours').toString();
    mealsCtrl.text = (data['meals_per_day'] ?? 0).toString();
    walksCtrl.text = (data['walks_per_day'] ?? 0).toString();
    if (data['inclusions'] is List) {
      inclusions = List<String>.from(data['inclusions']);
    }
    descCtrl.text = (data['description'] ?? '').toString();
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'tier': tier,
        'enabled': enabled,
        'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
        'duration_value': int.tryParse(durationValueCtrl.text.trim()) ?? 1,
        'duration_unit': durationUnit,
        'meals_per_day': int.tryParse(mealsCtrl.text.trim()) ?? 0,
        'walks_per_day': int.tryParse(walksCtrl.text.trim()) ?? 0,
        'inclusions': inclusions,
        'description': descCtrl.text.trim(),
      };
}
