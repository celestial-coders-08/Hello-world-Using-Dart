import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/seller_api_service.dart';
import '../../widgets/product_detail_sheet.dart';

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
  static const _pageSize = 8;
  static const _sortOptions = {
    'newest': 'Newest',
    'oldest': 'Oldest',
    'price_low': 'Price: low to high',
    'price_high': 'Price: high to low',
    'name': 'Name: A to Z',
  };

  final _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  String _listingType = 'all';
  String _animalType = 'all';
  String _sortBy = 'newest';
  String _statusFilter = 'All';
  int _visibleCount = _pageSize;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _listingType = widget.listingTypeFilter ?? 'all';
    _animalType = widget.animalTypeFilter ?? 'all';
    _searchController.addListener(_onSearchChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _visibleCount = _pageSize);
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
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
        _visibleCount = _pageSize;
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
      _visibleCount = _pageSize;
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _products.where((product) {
      final inStock =
          product['in_stock'] == true ||
          _numeric(product['stock_quantity']) > 0;
      if (_statusFilter == 'Stock available' && !inStock) return false;
      if (_statusFilter == 'Out of stock' && inStock) return false;
      final type = product['listing_type']?.toString().toLowerCase() ?? 'other';
      final animal = product['animal_type']?.toString().toLowerCase() ?? '';
      if (_listingType != 'all' && type != _listingType) return false;
      if (_animalType != 'all' && animal != _animalType.toLowerCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        product['name'],
        product['brand'],
        product['sku'],
        product['animal_type'],
        product['breed'],
        product['listing_type'],
        product['description'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    switch (_sortBy) {
      case 'oldest':
        filtered.sort((a, b) => _createdAt(a).compareTo(_createdAt(b)));
      case 'price_low':
        filtered.sort((a, b) => _price(a).compareTo(_price(b)));
      case 'price_high':
        filtered.sort((a, b) => _price(b).compareTo(_price(a)));
      case 'name':
        filtered.sort(
          (a, b) => _productName(
            a,
          ).toLowerCase().compareTo(_productName(b).toLowerCase()),
        );
      default:
        filtered.sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
    }
    return filtered;
  }

  int _count({required String type, String animal = 'all'}) {
    return _products.where((product) {
      final productType =
          product['listing_type']?.toString().toLowerCase() ?? 'other';
      final productAnimal =
          product['animal_type']?.toString().toLowerCase() ?? '';
      return productType == type &&
          (animal == 'all' || productAnimal == animal.toLowerCase());
    }).length;
  }

  int get _lowStockCount {
    return _products.where((p) {
      final stock = _numeric(p['stock_quantity'] ?? p['stock']).toInt();
      return stock > 0 && stock <= 5;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _filteredProducts;
    final visibleProducts = filtered.take(_visibleCount).toList();

    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: const Color(0xFFD85F3D),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Section Title & Add Listing Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'My listings',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _isLoading ? null : _loadProducts,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage the food, pets, and other items you sell.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: widget.onAddProduct,
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text(
                  'Add listing',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD85F3D),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Search Bar with Grid Icon
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by title, SKU, or brand...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.grid_view_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Horizontal Filter Chips Bar
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'All',
                  count: _products.length,
                  selected: _listingType == 'all',
                  onTap: () => _changeFilter('all', 'all'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Food',
                  count: _count(type: 'food'),
                  selected: _listingType == 'food',
                  onTap: () => _changeFilter('food', 'all'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Dogs',
                  count: _count(type: 'pets', animal: 'dog'),
                  selected: _listingType == 'pets' && _animalType == 'Dog',
                  onTap: () => _changeFilter('pets', 'Dog'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Cats',
                  count: _count(type: 'pets', animal: 'cat'),
                  selected: _listingType == 'pets' && _animalType == 'Cat',
                  onTap: () => _changeFilter('pets', 'Cat'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Other pets',
                  count: _count(type: 'pets', animal: 'other'),
                  selected: _listingType == 'pets' && _animalType == 'Other',
                  onTap: () => _changeFilter('pets', 'Other'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Other items',
                  count: _count(type: 'other'),
                  selected: _listingType == 'other',
                  onTap: () => _changeFilter('other', 'all'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Status & Sort Bar
          Row(
            children: [
              // Filter Status dropdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter: Status: ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _statusFilter,
                      underline: const SizedBox(),
                      isDense: true,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      items: ['All', 'Stock available', 'Out of stock']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _statusFilter = v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Warning / Low Stock Badge
              if (_lowStockCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                      Text(
                        '$_lowStockCount Low Stock',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Sort dropdown
              PopupMenuButton<String>(
                tooltip: 'Sort listings',
                initialValue: _sortBy,
                onSelected: (value) => setState(() => _sortBy = value),
                itemBuilder: (context) => _sortOptions.entries
                    .map(
                      (entry) => PopupMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sort: ${_sortOptions[_sortBy]}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.unfold_more_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFFD85F3D),
            ),
          ],

          if (_error != null && _products.isNotEmpty) ...[
            const SizedBox(height: 12),
            _errorMessage(context, _error!),
          ],

          const SizedBox(height: 14),

          if (_isLoading && _products.isEmpty)
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFD85F3D)),
              ),
            )
          else if (_error != null && _products.isEmpty)
            SizedBox(
              height: 220,
              child: _emptyState(
                context,
                _error!,
                icon: Icons.cloud_off_outlined,
                action: OutlinedButton.icon(
                  onPressed: _loadProducts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            )
          else if (filtered.isEmpty)
            SizedBox(
              height: 220,
              child: _emptyState(
                context,
                _searchController.text.isNotEmpty
                    ? 'No listings match your search.'
                    : 'No listings in this category yet.',
                icon: Icons.inventory_2_outlined,
                action: _searchController.text.isEmpty
                    ? OutlinedButton.icon(
                        onPressed: widget.onAddProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('Add a listing'),
                      )
                    : null,
              ),
            )
          else
            // 2-Column Product Grid Cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.58,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final product = visibleProducts[index];
                return _ListingCard(
                  product: product,
                  onDetails: () => _showListingDetails(product),
                  onEdit: () => _editListing(product),
                );
              },
            ),

          if (filtered.length > visibleProducts.length) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Showing ${visibleProducts.length} of ${filtered.length} listings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton(
                onPressed: () => setState(
                  () => _visibleCount = math.min(
                    filtered.length,
                    _visibleCount + _pageSize,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Load more items ↓',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ] else if (filtered.isNotEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Showing ${visibleProducts.length} of ${filtered.length} listings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showListingDetails(Map<String, dynamic> product) {
    ProductDetailSheet.show(
      context,
      product,
      userLookup: widget.sellerLookup,
      showBuyButton: false,
    );
  }

  Future<void> _editListing(Map<String, dynamic> product) async {
    final formKey = GlobalKey<FormState>();
    final priceController = TextEditingController(
      text: _price(product).toStringAsFixed(2),
    );
    final descriptionController = TextEditingController(
      text: product['description']?.toString() ?? '',
    );
    final stockQuantityController = TextEditingController(
      text: _numeric(
        product['stock_quantity'] ?? product['stock'],
      ).toInt().toString(),
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
          title: Text('Edit ${_productName(product)}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      prefixText: '₹ ',
                    ),
                    validator: (value) {
                      final price = double.tryParse(value?.trim() ?? '');
                      if (price == null || price <= 0) {
                        return 'Enter a price greater than zero.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Available stock',
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(value?.trim() ?? '');
                      if (quantity == null || quantity < 0) {
                        return 'Enter a whole number of 0 or more.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save changes'),
            ),
          ],
      ),
    );

    if (save == true && mounted) {
      final productId = int.tryParse(product['id']?.toString() ?? '');
      if (productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This listing has no valid ID.')),
        );
      } else {
        try {
          await SellerApiService.updateProduct(
            sellerLookup: widget.sellerLookup,
            productId: productId,
            price: double.parse(priceController.text.trim()),
            description: descriptionController.text.trim(),
            stockQuantity: int.parse(stockQuantityController.text.trim()),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Listing updated successfully.')),
            );
            await _loadProducts();
          }
        } on Exception catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.toString().replaceFirst('Exception: ', '')),
              ),
            );
          }
        }
      }
    }
    priceController.dispose();
    descriptionController.dispose();
    stockQuantityController.dispose();
  }

  Widget _errorMessage(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF991B1B),
                fontSize: 12,
              ),
            ),
          ),
          TextButton(onPressed: _loadProducts, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    String message, {
    required IconData icon,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B)),
          ),
          if (action != null) ...[const SizedBox(height: 14), action],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDCFCE7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: Color(0xFF166534),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected
                    ? const Color(0xFF166534)
                    : const Color(0xFF475569),
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  color: selected
                      ? const Color(0xFF14532D)
                      : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onDetails;
  final VoidCallback onEdit;

  const _ListingCard({
    required this.product,
    required this.onDetails,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final images = (product['image_urls'] as List<dynamic>? ?? const [])
        .map((image) => image.toString())
        .toList();
    if (images.isEmpty && product['image_url'] != null) {
      final img = product['image_url'].toString().trim();
      if (img.isNotEmpty) images.add(img);
    }

    final type = product['listing_type']?.toString().toLowerCase() ?? 'other';
    final title = _productName(product);
    final price = _price(product);
    final mrp = _numeric(product['mrp']);
    final brand = product['brand']?.toString().trim();
    final stock = _numeric(
      product['stock_quantity'] ?? product['stock'],
    ).toInt();
    final inStock = stock > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image container (fixed height 135)
              Container(
                height: 135,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: images.isNotEmpty
                      ? Image.network(
                          SellerApiService.mediaUrl(images.first),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(type),
                        )
                      : _imagePlaceholder(type),
                ),
              ),

              const SizedBox(height: 10),

              // Brand tag
              Text(
                (brand != null && brand.isNotEmpty ? brand : _typeLabel(type))
                    .toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFD85F3D),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),

              const SizedBox(height: 3),

              // Product Title
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 6),

              // Price & MRP
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatCurrency(price),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (mrp > price) ...[
                    const SizedBox(width: 6),
                    Text(
                      _formatCurrency(mrp),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 5),
              Text(
                inStock ? 'Stock available ($stock)' : 'Out of stock',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: inStock
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB91C1C),
                ),
              ),

              const Spacer(),

              // Full Width Light Orange Edit Button
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Color(0xFFD85F3D),
                  ),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD85F3D),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEDD5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Widget _imagePlaceholder(String type) {
    final background = switch (type) {
      'pets' => const Color(0xFFFFF2E9),
      'food' => const Color(0xFFF2ECFA),
      _ => const Color(0xFFF1F5F9),
    };
    final icon = switch (type) {
      'pets' => Icons.pets_outlined,
      'food' => Icons.restaurant_outlined,
      _ => Icons.inventory_2_outlined,
    };
    return ColoredBox(
      color: background,
      child: Center(
        child: Icon(icon, size: 36, color: const Color(0xFFD85F3D)),
      ),
    );
  }
}

double _numeric(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _price(Map<String, dynamic> product) => _numeric(product['price']);

String _productName(Map<String, dynamic> product) {
  final name = product['name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  return 'Untitled listing';
}

DateTime _createdAt(Map<String, dynamic> product) =>
    DateTime.tryParse(product['created_at']?.toString() ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

String _typeLabel(String type) => switch (type) {
  'pets' => 'Pet',
  'food' => 'Food',
  _ => 'Other item',
};

String _formatCurrency(num amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final integer = parts.first;
  final lastThree = integer.length > 3
      ? integer.substring(integer.length - 3)
      : integer;
  final prefix = integer.length > 3
      ? integer.substring(0, integer.length - 3)
      : '';
  final groups = <String>[];
  for (var end = prefix.length; end > 0; end -= 2) {
    groups.insert(0, prefix.substring(math.max(0, end - 2), end));
  }
  groups.add(lastThree);
  final decimals = parts.last == '00' ? '' : '.${parts.last}';
  return '₹${groups.join(',')}$decimals';
}
