import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../config/api_config.dart';
import '../../theme/pawstay_theme.dart';
import '../../models/pet_storage.dart';
import 'home.dart';

class AddPetScreen extends StatefulWidget {
  final String? userLookup;
  final Pet? existingPet;

  const AddPetScreen({super.key, this.userLookup, this.existingPet});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _petNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _dietController = TextEditingController();
  final _otherPetTypeController = TextEditingController();
  final LocalPetStorage _petStorage = LocalPetStorage();

  String _selectedCategory = 'Dog';
  String _selectedAgeUnit = 'Years';
  bool _isEditing = false;
  bool _isSaving = false;
  Uint8List? _profileImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  late AnimationController _avatarAnimController;
  late Animation<double> _avatarScaleAnim;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingPet != null;
    if (_isEditing) {
      final pet = widget.existingPet!;
      _petNameController.text = pet.name;
      _selectedCategory = pet.type;
      _ageController.text = pet.age.toString();
      _dietController.text = pet.dietaryPreferences;
      final savedImage = pet.profileImage;
      if (savedImage != null && savedImage.isNotEmpty) {
        try {
          final encodedImage = savedImage.contains(',')
              ? savedImage.split(',').last
              : savedImage;
          _profileImageBytes = base64Decode(encodedImage);
        } catch (_) {
          _profileImageBytes = null;
        }
      }
    }

    _avatarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _avatarScaleAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _ageController.dispose();
    _dietController.dispose();
    _otherPetTypeController.dispose();
    _avatarAnimController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: isError ? PawStayTheme.error : PawStayTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _profileImageBytes = bytes;
      });
    } catch (_) {
      _showSnack('Could not pick photo.', isError: true);
    }
  }

  Future<void> _savePetProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final petName = _petNameController.text.trim();
    final ageText = _ageController.text.trim();
    final diet = _dietController.text.trim();

    if (petName.isEmpty) {
      _showSnack("Please enter your pet's name.", isError: true);
      return;
    }

    final age = int.tryParse(ageText) ?? 0;
    final category = _selectedCategory == 'Other'
        ? (_otherPetTypeController.text.trim().isEmpty
              ? 'Other'
              : _otherPetTypeController.text.trim())
        : _selectedCategory;

    final pet = Pet(
      userId: widget.userLookup ?? 'guest',
      name: petName,
      type: category,
      age: age,
      dietaryPreferences: diet,
      healthStatus: '',
      profileImage: _profileImageBytes != null
          ? base64Encode(_profileImageBytes!)
          : null,
    );

    setState(() => _isSaving = true);

    try {
      await _petStorage.savePet(pet);

      final body = jsonEncode(pet.toJson());
      try {
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/pets'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // The local profile remains the source of truth when sync is unavailable.
      }

      if (!mounted) return;

      _showSnack(
        _isEditing ? 'Pet profile updated! 🐾' : 'Pet profile saved! 🐾',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a, sa) =>
                HomeScreen(userLookup: widget.userLookup),
            transitionsBuilder: (c, a, sa, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (_) {
      _showSnack('Could not save pet profile.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Reusable Section Card ──────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PawStayTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        border: Border.all(color: PawStayTheme.surfaceDim),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: PawStayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ─── Profile Photo Avatar ───────────────────────────────────────────────────
  Widget _buildProfileAvatar() {
    return Center(
      child: GestureDetector(
        onTap: _pickProfilePhoto,
        child: ScaleTransition(
          scale: _avatarScaleAnim,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PawStayTheme.primaryContainer.withValues(alpha: 0.15),
                  border: Border.all(
                    color: PawStayTheme.primary.withValues(alpha: 0.4),
                    width: 2.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _profileImageBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          _profileImageBytes!,
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            color: PawStayTheme.primary,
                            size: 30,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Profile Photo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: PawStayTheme.primary,
                            ),
                          ),
                          Text(
                            'Show us their cute face!',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              color: PawStayTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
              if (_profileImageBytes != null)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PawStayTheme.primary,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Category Toggle Button ─────────────────────────────────────────────────
  Widget _buildCategoryBtn(String label, {IconData? icon}) {
    final isSelected = _selectedCategory == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? PawStayTheme.primary
                : PawStayTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? PawStayTheme.primary
                  : PawStayTheme.surfaceDim,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : PawStayTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : PawStayTheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Themed Text Field ──────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: PawStayTheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: PawStayTheme.tertiaryContainer,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PawStayTheme.onSurfaceVariant,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, color: PawStayTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              _isEditing ? 'Edit Pet Profile' : 'Add Your Pet',
              style: GoogleFonts.plusJakartaSans(
                color: PawStayTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Basics Card ─────────────────────────────────────
                      _buildSectionCard(
                        title: 'Basics',
                        children: [
                          _buildProfileAvatar(),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                "Pet's Name",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: PawStayTheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _petNameController,
                            hint: 'e.g. Bella',
                            validator: (v) => v == null || v.trim().isEmpty
                                ? "Please enter your pet's name."
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Category Card ────────────────────────────────────
                      _buildSectionCard(
                        title: 'Category',
                        children: [
                          Row(
                            children: [
                              _buildCategoryBtn('Dog'),
                              _buildCategoryBtn('Cat'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = 'Other'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedCategory == 'Other'
                                      ? PawStayTheme.primary
                                      : PawStayTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(
                                    PawStayTheme.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: _selectedCategory == 'Other'
                                        ? PawStayTheme.primary
                                        : PawStayTheme.surfaceDim,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pets_rounded,
                                      size: 16,
                                      color: _selectedCategory == 'Other'
                                          ? Colors.white
                                          : PawStayTheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Other',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedCategory == 'Other'
                                            ? Colors.white
                                            : PawStayTheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_selectedCategory == 'Other') ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _otherPetTypeController,
                              hint: 'e.g. Parrot, Rabbit...',
                              label: 'Pet type',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Profile Details Card ─────────────────────────────
                      _buildSectionCard(
                        title: 'Profile Details',
                        children: [
                          Text(
                            'Age of Pet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: PawStayTheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _ageController,
                                  hint: 'e.g. 3',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: PawStayTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(
                                    PawStayTheme.radiusDefault,
                                  ),
                                  border: Border.all(
                                    color: PawStayTheme.outlineVariant,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedAgeUnit,
                                    isDense: true,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: PawStayTheme.onSurfaceVariant,
                                    ),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: PawStayTheme.onSurface,
                                    ),
                                    items: ['Years', 'Months']
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u,
                                            child: Text(u),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setState(
                                      () => _selectedAgeUnit = val ?? 'Years',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Health & Diet Card ───────────────────────────────
                      _buildSectionCard(
                        title: 'Health & Diet',
                        children: [
                          Text(
                            'Dietary Preferences & Food Type',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: PawStayTheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _dietController,
                            hint: 'Describe their food preferences...',
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Sticky Bottom Buttons ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: PawStayTheme.background,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      offset: const Offset(0, -4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _savePetProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: PawStayTheme.primary
                              .withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PawStayTheme.radiusMd,
                            ),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 20),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : (_isEditing
                                    ? 'Update Pet Profile'
                                    : 'Save Pet Profile'),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: PawStayTheme.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PawStayTheme.radiusMd,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
