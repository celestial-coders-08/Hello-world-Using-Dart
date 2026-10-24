import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';

class AddProductScreen extends StatefulWidget {
  final String sellerLookup;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const AddProductScreen({
    super.key,
    required this.sellerLookup,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const int _minImages = 3;
  static const int _maxImages = 5;
  static const _animalTypes = ['Dog', 'Cat', 'Other'];

  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _breedController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockQuantityController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _healthIssueController = TextEditingController();

  bool _isShopOwner = false;
  bool _isLoadingVerification = true;

  String? _listingType; // 'pets', 'food', 'other'
  String _animalType = 'Dog';
  final Set<String> _suitableFor = {};
  List<XFile> _images = [];

  bool _hasHealthIssue = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkSellerVerification();
  }

  Future<void> _checkSellerVerification() async {
    try {
      final res = await SellerApiService.fetchVerification(widget.sellerLookup);
      setState(() {
        _isShopOwner = res['is_shop_owner'] == true;
        _isLoadingVerification = false;
        // Non-shop owners default to 'pets'
        if (!_isShopOwner) {
          _listingType = 'pets';
        }
      });
    } catch (_) {
      setState(() {
        _isShopOwner = false;
        _isLoadingVerification = false;
        _listingType = 'pets';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _breedController.dispose();
    _priceController.dispose();
    _stockQuantityController.dispose();
    _descriptionController.dispose();
    _healthIssueController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final selected = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1800,
        limit: _maxImages,
      );
      if (!mounted || selected.isEmpty) return;
      if (selected.length > _maxImages) {
        _showMessage('Choose no more than $_maxImages images.');
        return;
      }
      setState(() => _images = selected);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not select images: $error');
    }
  }

  Future<void> _publish() async {
    if (_listingType == null) {
      _showMessage('Choose what you want to sell first.');
      return;
    }

    if (!_isShopOwner && _listingType != 'pets') {
      _showMessage('Individual sellers can only list pets for sale.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_images.length < _minImages) {
      _showMessage(
        'Please select at least $_minImages images (up to $_maxImages).',
      );
      return;
    }

    if (_listingType == 'food' && _suitableFor.isEmpty) {
      _showMessage('Select which animals can eat this food.');
      return;
    }

    if (_listingType == 'other' && _suitableFor.isEmpty) {
      _showMessage('Select which animals can use this item.');
      return;
    }

    if (_listingType == 'pets' &&
        _hasHealthIssue &&
        _healthIssueController.text.trim().isEmpty) {
      _showMessage('Please describe the health issue.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SellerApiService.createListing(
        sellerLookup: widget.sellerLookup,
        listingType: _listingType!,
        price: double.parse(_priceController.text.trim()),
        stockQuantity: int.parse(_stockQuantityController.text.trim()),
        images: _images,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        animalType: _animalType,
        breed: _breedController.text.trim(),
        description: _descriptionController.text.trim(),
        hasHealthIssue: _hasHealthIssue,
        healthIssue: _healthIssueController.text.trim(),
        suitableFor: _suitableFor.toList(),
      );
      if (mounted) {
        _showMessage('Item listed successfully!');
        widget.onSuccess();
      }
    } on Exception catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: PawStayTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_isLoadingVerification) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Product',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCancel,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Seller status banner
                Card(
                  color: PawStayTheme.primaryContainer.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _isShopOwner ? Icons.storefront : Icons.person,
                          color: PawStayTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isShopOwner
                                    ? 'Verified Shop Owner'
                                    : 'Individual Seller (Non-Shop)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _isShopOwner
                                    ? 'You can list Pets, Pet Food, and Pet Accessories.'
                                    : 'You are permitted to list Pets (Dog, Cat, Other).',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Choose category to sell',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                // Category Selection options
                _listingTypeChoice(
                  context,
                  type: 'pets',
                  title: 'Sell a Pet',
                  description: 'Dogs, Cats, and other pets',
                  icon: Icons.pets,
                  enabled: true,
                ),
                const SizedBox(height: 8),
                _listingTypeChoice(
                  context,
                  type: 'food',
                  title: 'Pet Food',
                  description: 'Packaged food, treats, and nutrition',
                  icon: Icons.restaurant,
                  enabled: _isShopOwner,
                ),
                const SizedBox(height: 8),
                _listingTypeChoice(
                  context,
                  type: 'other',
                  title: 'Pet Items & Accessories',
                  description: 'Toys, collars, care items, and accessories',
                  icon: Icons.shopping_bag_outlined,
                  enabled: _isShopOwner,
                ),

                if (_listingType != null) ...[
                  const Divider(height: 36),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _formTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_listingType == 'pets') _buildPetForm(),
                        if (_listingType == 'food') _buildFoodForm(),
                        if (_listingType == 'other') _buildOtherForm(),

                        const SizedBox(height: 14),
                        _textInput(
                          _priceController,
                          'Price (₹)',
                          number: true,
                          required: true,
                        ),

                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _stockQuantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Available stock *',
                            hintText: 'Enter the number of items available',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final quantity = int.tryParse(value?.trim() ?? '');
                            if (quantity == null || quantity < 0) {
                              return 'Enter a whole number of 0 or more.';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),
                        _textInput(
                          _descriptionController,
                          'Description',
                          required: true,
                          maxLines: 3,
                        ),

                        const SizedBox(height: 16),
                        _buildImagePicker(context),

                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _publish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PawStayTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isSubmitting ? 'Publishing...' : 'List Item',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _formTitle => switch (_listingType) {
    'food' => 'Pet Food Details',
    'pets' => 'Pet Details',
    _ => 'Item & Accessory Details',
  };

  Widget _listingTypeChoice(
    BuildContext context, {
    required String type,
    required String title,
    required String description,
    required IconData icon,
    required bool enabled,
  }) {
    final selected = _listingType == type;
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: selected
          ? PawStayTheme.primaryContainer.withValues(alpha: 0.2)
          : enabled
          ? colors.surfaceContainerLow
          : colors.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? PawStayTheme.primary
              : enabled
              ? colors.outlineVariant
              : colors.outlineVariant.withValues(alpha: 0.3),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: selected
              ? PawStayTheme.primary
              : (enabled ? colors.onSurface : colors.outline),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: enabled ? colors.onSurface : colors.outline,
          ),
        ),
        subtitle: Text(
          enabled ? description : '$description (Shop Owners Only)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: enabled ? colors.onSurfaceVariant : colors.outline,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: PawStayTheme.primary)
            : null,
        onTap: enabled && !_isSubmitting
            ? () => setState(() {
                _listingType = type;
                _images = [];
              })
            : null,
      ),
    );
  }

  Widget _buildPetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _animalType,
          decoration: const InputDecoration(
            labelText: 'Pet Category *',
            border: OutlineInputBorder(),
          ),
          items: _animalTypes
              .map(
                (animal) => DropdownMenuItem(
                  value: animal,
                  child: Text(animal == 'Other' ? 'Other Pet' : animal),
                ),
              )
              .toList(),
          onChanged: _isSubmitting
              ? null
              : (value) {
                  if (value != null) setState(() => _animalType = value);
                },
        ),
        const SizedBox(height: 12),
        _textInput(_breedController, 'Breed', required: true),
        const SizedBox(height: 14),

        // Health Issue Toggle & Details
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Does this pet have any health issues?',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  value: _hasHealthIssue,
                  onChanged: _isSubmitting
                      ? null
                      : (val) => setState(() => _hasHealthIssue = val),
                ),
                if (_hasHealthIssue) ...[
                  const SizedBox(height: 8),
                  _textInput(
                    _healthIssueController,
                    'Describe Health Issue',
                    required: true,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textInput(_brandController, 'Food Brand / Name', required: true),
        const SizedBox(height: 12),
        Text(
          'Who can eat this food? *',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        ..._animalTypes.map(
          (animal) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(animal == 'Other' ? 'Other pets' : animal),
            value: _suitableFor.contains(animal),
            onChanged: _isSubmitting
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _suitableFor.add(animal);
                    } else {
                      _suitableFor.remove(animal);
                    }
                  }),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textInput(_nameController, 'Item / Accessory Name', required: true),
        const SizedBox(height: 12),
        Text(
          'Who can use this item? *',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        ..._animalTypes.map(
          (animal) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(animal == 'Other' ? 'Other pets' : animal),
            value: _suitableFor.contains(animal),
            onChanged: _isSubmitting
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _suitableFor.add(animal);
                    } else {
                      _suitableFor.remove(animal);
                    }
                  }),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Item Photos (3 to 5 images required) *',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _images.isEmpty
                ? 'Choose 3 - 5 photos'
                : 'Choose photos (${_images.length}/$_maxImages)',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FutureBuilder<Uint8List>(
                      future: _images[index].readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const SizedBox(
                            width: 104,
                            height: 104,
                            child: Icon(Icons.broken_image_outlined),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            width: 104,
                            height: 104,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Image.memory(
                          snapshot.data!,
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filledTonal(
                      tooltip: 'Remove image',
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _images.removeAt(index)),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _textInput(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return '$label is required.';
        if (number && text.isNotEmpty) {
          final parsed = double.tryParse(text);
          if (parsed == null || parsed <= 0) {
            return 'Enter a price greater than zero.';
          }
        }
        return null;
      },
    );
  }
}
