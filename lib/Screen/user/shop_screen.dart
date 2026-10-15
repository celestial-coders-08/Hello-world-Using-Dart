import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/marketplace_cart.dart';
import '../../services/payment_api_service.dart';
import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/product_detail_sheet.dart';
import '../provider/add_cart.dart';
import 'add_cart.dart';

class ShopScreen extends StatefulWidget {
  final String? userLookup;
  final bool isProvider;

  const ShopScreen({super.key, this.userLookup, this.isProvider = false});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _sellerProducts = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  List<String> get _categories => widget.isProvider
      ? ['All Products', 'Food & Treats', 'Pets', 'Accessories & Toys']
      : ['All Products', 'Pets', 'Accessories & Toys'];

  @override
  void initState() {
    super.initState();
    _fetchMarketplaceProducts();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchMarketplaceProducts(showLoading: false),
    );
  }

  Future<void> _fetchMarketplaceProducts({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final products = await PaymentApiService.fetchMarketplaceProducts();
      if (mounted) {
        setState(() {
          _sellerProducts = products.where((product) {
            final listingType = product['listing_type']
                ?.toString()
                .toLowerCase();
            if (widget.isProvider) {
              return const {'food', 'pets', 'other'}.contains(listingType);
            }
            return const {'pets', 'other'}.contains(listingType);
          }).toList();
          _isLoading = false;
          _error = null;
        });
      }
    } on Exception catch (error) {
      if (mounted && showLoading) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onProductTap(Map<String, dynamic> product) {
    ProductDetailSheet.show(context, product, userLookup: widget.userLookup);
  }

  void _openCart() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => widget.isProvider
            ? const ProviderAddCartScreen()
            : const UserAddCartScreen(),
      ),
    );
  }

  Widget _buildCartButton() {
    return AnimatedBuilder(
      animation: MarketplaceCart.instance,
      builder: (context, _) {
        final count = MarketplaceCart.instance.itemCount;
        return IconButton(
          tooltip: count == 0 ? 'Open cart' : 'Open cart ($count items)',
          onPressed: _openCart,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (count > 0)
                Positioned(
                  right: -9,
                  top: -8,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Container(
                      key: ValueKey(count),
                      constraints: const BoxConstraints(
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD85F3D),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCartButton(Map<String, dynamic> product) {
    final productId = int.tryParse(product['id']?.toString() ?? '');
    final stock = MarketplaceCartItem.parseStock(
      product['stock_quantity'] ?? product['stock'],
    );
    return AnimatedBuilder(
      animation: MarketplaceCart.instance,
      builder: (context, _) {
        final quantity = productId == null
            ? 0
            : MarketplaceCart.instance.quantityFor(productId);
        if (quantity == 0) {
          return SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: productId == null || stock < 1
                  ? null
                  : () {
                      final added = MarketplaceCart.instance.addProduct(
                        product,
                      );
                      if (!added && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This product cannot be added or is out of stock.',
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD85F3D),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                stock < 1 ? 'Out of stock' : 'Add to cart',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Remove one',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () => MarketplaceCart.instance.decrement(productId!),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '$quantity',
                  key: ValueKey(quantity),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add one',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: quantity >= stock
                    ? null
                    : () {
                        if (!MarketplaceCart.instance.increment(productId!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'You have reached the available stock.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = _sellerProducts;
    final query = _searchController.text.trim().toLowerCase();

    final filteredProducts = allProducts.where((product) {
      final listingType =
          product['listing_type']?.toString().toLowerCase() ?? 'other';
      final matchesCategory =
          _selectedCategoryIndex == 0 ||
          (widget.isProvider &&
              _selectedCategoryIndex == 1 &&
              listingType == 'food') ||
          (_selectedCategoryIndex == (widget.isProvider ? 2 : 1) &&
              listingType == 'pets') ||
          (_selectedCategoryIndex == (widget.isProvider ? 3 : 2) &&
              listingType == 'other');

      final matchesSearch =
          query.isEmpty ||
          (product['name']?.toString() ?? '').toLowerCase().contains(query) ||
          (product['brand']?.toString() ?? '').toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'PawStay Marketplace',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: PawStayTheme.primary,
          ),
        ),
        actions: [_buildCartButton(), const SizedBox(width: 8)],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: PawStayTheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search food, pets, accessories...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                  icon: Icon(
                    Icons.search,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Categories horizontal list
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategoryIndex == index;
                  return ChoiceChip(
                    label: Text(
                      _categories[index],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : PawStayTheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD85F3D),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFD85F3D)
                          : PawStayTheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategoryIndex = index);
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seller Products',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PawStayTheme.onSurface,
                  ),
                ),
                Text(
                  '${filteredProducts.length} items',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh marketplace',
                  onPressed: _isLoading ? null : _fetchMarketplaceProducts,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFFD85F3D)),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _fetchMarketplaceProducts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    allProducts.isEmpty
                        ? 'No seller listings are available yet.'
                        : 'No products found in this category.',
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
              ]),
            ),
          ),
          if (!_isLoading && _error == null && filteredProducts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: PawStayResponsive.width(context) > 600
                      ? 3
                      : 2,
                  childAspectRatio: PawStayResponsive.gridAspectRatio(
                    context: context,
                    baseRatio: 0.65,
                    compactRatio: 0.58,
                    tabletRatio: 0.72,
                  ),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = filteredProducts[index];
                  final name = product['name']?.toString() ?? 'Product';
                  final brand = product['brand']?.toString() ?? 'PawStay';
                  final price = (product['price'] is num)
                      ? (product['price'] as num).toDouble()
                      : double.tryParse(product['price']?.toString() ?? '') ??
                            0.0;
                  final mrp = (product['mrp'] is num)
                      ? (product['mrp'] as num).toDouble()
                      : price * 1.15;
                  final imageUrl = product['image_url']?.toString();
                  final stock = MarketplaceCartItem.parseStock(
                    product['stock_quantity'] ?? product['stock'],
                  );

                  return GestureDetector(
                    onTap: () => _onProductTap(product),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: PawStayTheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.025),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child:
                                        imageUrl != null && imageUrl.isNotEmpty
                                        ? Image.network(
                                            SellerApiService.mediaUrl(imageUrl),
                                            fit: BoxFit.cover,
                                            cacheWidth: 360,
                                            cacheHeight: 360,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.shopping_bag_outlined,
                                                  size: 40,
                                                  color: Color(0xFFD85F3D),
                                                ),
                                          )
                                        : const Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 40,
                                            color: Color(0xFFD85F3D),
                                          ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stock > 0
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFEBEE),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        stock > 0
                                            ? 'In stock ($stock)'
                                            : 'Out of stock',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: stock > 0
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFC62828),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            brand.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD85F3D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: PawStayTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${price.toStringAsFixed(0)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: PawStayTheme.onSurface,
                                ),
                              ),
                              if (mrp > price)
                                Text(
                                  '₹${mrp.toStringAsFixed(0)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: PawStayTheme.onSurfaceVariant,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildProductCartButton(product),
                        ],
                      ),
                    ),
                  );
                }, childCount: filteredProducts.length),
              ),
            ),
        ],
      ),
    );
  }
}
