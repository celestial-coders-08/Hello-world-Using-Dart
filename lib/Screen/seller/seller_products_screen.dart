import 'package:flutter/material.dart';

import '../../services/seller_api_service.dart';

class SellerProductsScreen extends StatefulWidget {
  final String sellerLookup;
  final String? listingTypeFilter;
  final String? animalTypeFilter;
  final VoidCallback onAddProduct;
  final VoidCallback onProductsChanged;

  const SellerProductsScreen({
    super.key,
    required this.sellerLookup,
    required this.onAddProduct,
    required this.onProductsChanged,
    this.listingTypeFilter,
    this.animalTypeFilter,
  });

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  bool _isLoading = true;
  String? _error;
  String _listingType = 'all';
  String _animalType = 'all';
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _listingType = widget.listingTypeFilter ?? 'all';
    _animalType = widget.animalTypeFilter ?? 'all';
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await SellerApiService.fetchProducts(
        widget.sellerLookup,
        listingType: _listingType,
        animalType: _animalType,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
      widget.onProductsChanged();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _changeFilter(String listingType, String animalType) {
    setState(() {
      _listingType = listingType;
      _animalType = animalType;
    });
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My listings',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage the food, pets, and other items you sell.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh listings',
                onPressed: _isLoading ? null : _loadProducts,
                icon: const Icon(Icons.refresh),
              ),
              FilledButton.icon(
                onPressed: widget.onAddProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add listing'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('All', 'all', 'all'),
              _filterChip('Food', 'food', 'all'),
              _filterChip('Dogs', 'pets', 'Dog'),
              _filterChip('Cats', 'pets', 'Cat'),
              _filterChip('Other pets', 'pets', 'Other'),
              _filterChip('Other items', 'other', 'all'),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _emptyState(
                    _error!,
                    action: FilledButton.icon(
                      onPressed: _loadProducts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  )
                : _products.isEmpty
                ? _emptyState(
                    'No listings in this category yet.',
                    action: FilledButton.icon(
                      onPressed: widget.onAddProduct,
                      icon: const Icon(Icons.add),
                      label: const Text('Add a listing'),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1000
                          ? 3
                          : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 320,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) => _productCard(
                          context,
                          colors,
                          _products[index],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String type, String animal) {
    final selected = _listingType == type && _animalType == animal;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _changeFilter(type, animal),
    );
  }

  Widget _productCard(
    BuildContext context,
    ColorScheme colors,
    Map<String, dynamic> product,
  ) {
    final images = (product['image_urls'] as List<dynamic>? ?? const [])
        .map((image) => image.toString())
        .toList();
    final price = product['price'] as num? ?? 0;
    final type = product['listing_type']?.toString() ?? 'other';
    final title = product['name']?.toString() ?? 'Listing';
    final subtitle = switch (type) {
      'food' =>
        'Food · ${product['brand'] ?? ''} · Suitable for ${(product['suitable_for'] as List<dynamic>? ?? const []).join(', ')}',
      'pets' =>
        '${product['animal_type'] ?? 'Pet'} · Breed: ${product['breed'] ?? '—'}',
      _ => product['description']?.toString() ?? '',
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: images.isEmpty
                ? ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  )
                : PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (context, index) => Image.network(
                      SellerApiService.mediaUrl(images[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, {Widget? action}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }
}
