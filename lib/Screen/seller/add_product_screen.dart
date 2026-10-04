import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/seller_api_service.dart';

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
  static const int _maxImages = 5;
  static const _animalTypes = ['Dog', 'Cat', 'Other'];
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _breedController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _listingType;
  String _animalType = 'Dog';
  final Set<String> _suitableFor = {};
  List<XFile> _images = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _breedController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      _showMessage('Choose at least one image from your device.');
      return;
    }
    if (_listingType == 'food' && _suitableFor.isEmpty) {
      _showMessage('Select which animals can eat this food.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SellerApiService.createListing(
        sellerLookup: widget.sellerLookup,
        listingType: _listingType!,
        price: double.parse(_priceController.text.trim()),
        images: _images,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        animalType: _animalType,
        breed: _breedController.text.trim(),
        description: _descriptionController.text.trim(),
        suitableFor: _suitableFor.toList(),
      );
      if (!mounted) return;
      _showMessage('Listing published successfully.');
      widget.onSuccess();
    } on Exception catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create a listing',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text('First, choose what you want to sell.'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _listingTypeChoice(
                      context,
                      type: 'food',
                      title: 'Pet food',
                      description: 'Packaged food, treats, and nutrition',
                      icon: Icons.restaurant,
                    ),
                    _listingTypeChoice(
                      context,
                      type: 'pets',
                      title: 'Sell a pet',
                      description: 'Dogs, cats, and other pets',
                      icon: Icons.pets,
                    ),
                    _listingTypeChoice(
                      context,
                      type: 'other',
                      title: 'Other items',
                      description: 'Accessories, toys, care, and more',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    if (_listingType != null) ...[
                      const Divider(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _formTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            if (_listingType == 'food') _buildFoodForm(),
                            if (_listingType == 'pets') _buildPetForm(),
                            if (_listingType == 'other') _buildOtherForm(),
                            _textInput(
                              _priceController,
                              'Price (₹)',
                              number: true,
                              required: true,
                            ),
                            const SizedBox(height: 10),
                            _buildImagePicker(context),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _isSubmitting ? null : _publish,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.publish),
                              label: Text(
                                _isSubmitting
                                    ? 'Publishing...'
                                    : 'Publish listing',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _formTitle => switch (_listingType) {
    'food' => 'Food details',
    'pets' => 'Pet details',
    _ => 'Item details',
  };

  Widget _listingTypeChoice(
    BuildContext context, {
    required String type,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final selected = _listingType == type;
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: _isSubmitting
            ? null
            : () => setState(() {
                _listingType = type;
                _images = [];
              }),
      ),
    );
  }

  Widget _buildFoodForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textInput(
          _brandController,
          'Food brand name',
          required: true,
        ),
        const SizedBox(height: 8),
        Text(
          'Which animals can eat this food?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
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

  Widget _buildPetForm() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _animalType,
          decoration: const InputDecoration(
            labelText: 'Pet type',
            border: OutlineInputBorder(),
          ),
          items: _animalTypes
              .map(
                (animal) => DropdownMenuItem(
                  value: animal,
                  child: Text(animal == 'Other' ? 'Other pet' : animal),
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
      ],
    );
  }

  Widget _buildOtherForm() {
    return Column(
      children: [
        _textInput(_nameController, 'Item name', required: true),
        const SizedBox(height: 4),
        _textInput(
          _descriptionController,
          'Description',
          required: true,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos from your device (up to $_maxImages)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _images.isEmpty
                ? 'Choose photos'
                : 'Choose photos (${_images.length}/$_maxImages)',
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 10),
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
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
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
