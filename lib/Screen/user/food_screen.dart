import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/marketplace_cart.dart';
import '../../services/payment_api_service.dart';
import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';
import 'add_cart.dart';

class FoodScreen extends StatefulWidget {
  final String? userLookup;

  const FoodScreen({super.key, this.userLookup});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  static const _refreshInterval = Duration(seconds: 30);

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _foodProducts = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchFoodProducts();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _fetchFoodProducts(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFoodProducts({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final products = await PaymentApiService.fetchMarketplaceProducts();
      if (!mounted) return;
      setState(() {
        _foodProducts = products
            .where(
              (product) =>
                  product['listing_type']?.toString().toLowerCase() == 'food',
            )
            .toList();
        _isLoading = false;
        _error = null;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      if (_foodProducts.isEmpty || showLoading) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _foodProducts;
    return _foodProducts.where((product) {
      return (product['name']?.toString() ?? '').toLowerCase().contains(
            query,
          ) ||
          (product['brand']?.toString() ?? '').toLowerCase().contains(query);
    }).toList();
  }

  void _openCart() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const UserAddCartScreen()),
    );
  }

  void _addProduct(Map<String, dynamic> product) {
    if (!MarketplaceCart.instance.addProduct(product)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product cannot be added or is out of stock.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.surface,
        title: Text(
          'Food & Nutrition',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh food listings',
            onPressed: _isLoading ? null : _fetchFoodProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
          AnimatedBuilder(
            animation: MarketplaceCart.instance,
            builder: (context, _) {
              final count = MarketplaceCart.instance.itemCount;
              return IconButton(
                tooltip: count == 0 ? 'Open cart' : 'Open cart ($count items)',
                onPressed: _openCart,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFoodProducts,
        color: PawStayTheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search seller-listed food...',
                prefixIcon: const Icon(Icons.search_rounded),
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
                filled: true,
                fillColor: PawStayTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Seller Food Listings (${products.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _fetchFoodProducts,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    _foodProducts.isEmpty
                        ? 'No seller-listed food is available yet.'
                        : 'No food listings match your search.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: PawStayResponsive.width(context) > 600
                      ? 3
                      : 2,
                  childAspectRatio: PawStayResponsive.gridAspectRatio(
                    context: context,
                    baseRatio: 0.62,
                    compactRatio: 0.54,
                    tabletRatio: 0.70,
                  ),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final id = int.tryParse(product['id']?.toString() ?? '');
                  final stock = MarketplaceCartItem.parseStock(
                    product['stock_quantity'] ?? product['stock'],
                  );
                  final price = product['price'] is num
                      ? (product['price'] as num).toDouble()
                      : double.tryParse(product['price']?.toString() ?? '') ??
                            0;
                  final imageUrl = product['image_url']?.toString();

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: PawStayTheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: imageUrl == null || imageUrl.isEmpty
                                  ? const Icon(
                                      Icons.restaurant_rounded,
                                      size: 42,
                                      color: PawStayTheme.primary,
                                    )
                                  : Image.network(
                                      SellerApiService.mediaUrl(imageUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.restaurant_rounded,
                                        size: 42,
                                        color: PawStayTheme.primary,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product['brand']?.toString() ?? 'PawStay Seller',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: PawStayTheme.primary,
                            ),
                          ),
                          Text(
                            product['name']?.toString() ?? 'Pet food',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stock > 0 ? 'In stock ($stock)' : 'Out of stock',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: stock > 0
                                  ? PawStayTheme.secondary
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${price.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedBuilder(
                            animation: MarketplaceCart.instance,
                            builder: (context, _) {
                              final quantity = id == null
                                  ? 0
                                  : MarketplaceCart.instance.quantityFor(id);
                              if (quantity == 0) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: id == null || stock < 1
                                        ? null
                                        : () => _addProduct(product),
                                    icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                    ),
                                    label: const Text('Add to cart'),
                                  ),
                                );
                              }
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    tooltip: 'Remove one',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        MarketplaceCart.instance.decrement(id!),
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                    ),
                                  ),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Add one',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: quantity >= stock
                                        ? null
                                        : () => _addProduct(product),
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: MarketplaceCart.instance,
        builder: (context, _) {
          final cart = MarketplaceCart.instance;
          if (cart.isEmpty) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _openCart,
                  child: Text(
                    'Checkout ${cart.itemCount} items • ₹${cart.subtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
