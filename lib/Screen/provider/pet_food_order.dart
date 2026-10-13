import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/marketplace_cart.dart';
import '../../services/payment_api_service.dart';
import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/product_detail_sheet.dart';

class PetFoodOrderScreen extends StatefulWidget {
  final String? providerLookup;

  const PetFoodOrderScreen({super.key, this.providerLookup});

  @override
  State<PetFoodOrderScreen> createState() => _PetFoodOrderScreenState();
}

class _PetFoodOrderScreenState extends State<PetFoodOrderScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Food', 'Pets', 'Accessories'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await PaymentApiService.fetchMarketplaceProducts();
      if (mounted) {
        setState(() {
          _products = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onProductTap(Map<String, dynamic> product) {
    ProductDetailSheet.show(
      context,
      product,
      userLookup: widget.providerLookup,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _products.where((p) {
      final type = (p['listing_type'] ?? 'other').toString().toLowerCase();
      final matchesCategory =
          _selectedCategory == 'All' ||
          (_selectedCategory == 'Food' && type == 'food') ||
          (_selectedCategory == 'Pets' && type == 'pets') ||
          (_selectedCategory == 'Accessories' && type == 'other');

      final name = (p['name'] ?? '').toString().toLowerCase();
      final brand = (p['brand'] ?? '').toString().toLowerCase();
      final matchesQuery =
          query.isEmpty || name.contains(query) || brand.contains(query);

      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        title: Text(
          'Provider Supplies & Products',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: PawStayTheme.primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        color: const Color(0xFFD85F3D),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search seller products, kibble, supplies...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Categories bar
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFD85F3D),
                      backgroundColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Available Seller Inventory',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFD85F3D)),
                  ),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No seller listings currently available.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: PawStayResponsive.gridAspectRatio(
                      context: context,
                      baseRatio: 0.65,
                      compactRatio: 0.58,
                    ),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    final name = p['name']?.toString() ?? 'Product';
                    final brand = p['brand']?.toString() ?? 'PawStay';
                    final price = (p['price'] is num)
                        ? (p['price'] as num).toDouble()
                        : double.tryParse(p['price']?.toString() ?? '') ?? 0.0;
                    final mrp = (p['mrp'] is num)
                        ? (p['mrp'] as num).toDouble()
                        : price * 1.15;
                    final imageUrl = p['image_url']?.toString();
                    final stock = MarketplaceCartItem.parseStock(
                      p['stock_quantity'] ?? p['stock'],
                    );

                    return GestureDetector(
                      onTap: () => _onProductTap(p),
                      child: Container(
                        padding: const EdgeInsets.all(10),
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          SellerApiService.mediaUrl(imageUrl),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 36,
                                            color: Color(0xFFD85F3D),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 36,
                                          color: Color(0xFFD85F3D),
                                        ),
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
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stock > 0 ? 'In stock ($stock)' : 'Out of stock',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: stock > 0
                                    ? PawStayTheme.secondary
                                    : Theme.of(context).colorScheme.error,
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
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (mrp > price)
                                  Text(
                                    '₹${mrp.toStringAsFixed(0)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: ElevatedButton(
                                onPressed: stock > 0
                                    ? () => _onProductTap(p)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD85F3D),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Buy Now',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}
