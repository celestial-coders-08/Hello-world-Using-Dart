import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/pawstay_theme.dart';

class ShopScreen extends StatefulWidget {
  final String? userLookup;

  const ShopScreen({super.key, this.userLookup});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'All Products',
    'Food & Treats',
    'Toys',
    'Care & Wellness',
    'Accessories',
  ];

  final List<Map<String, dynamic>> _products = [
    {
      'name': 'Premium Salmon Crunch',
      'category': 'Food & Treats',
      'price': '\$18.99',
      'rating': 4.9,
      'icon': Icons.set_meal_rounded,
      'color': Color(0xFFFFECE5),
      'iconColor': Color(0xFFD9531E),
    },
    {
      'name': 'Interactive Rope Toy',
      'category': 'Toys',
      'price': '\$12.50',
      'rating': 4.8,
      'icon': Icons.sports_tennis_rounded,
      'color': Color(0xFFEBF7ED),
      'iconColor': Color(0xFF27AE60),
    },
    {
      'name': 'Organic Pet Shampoo',
      'category': 'Care & Wellness',
      'price': '\$15.00',
      'rating': 4.7,
      'icon': Icons.clean_hands_rounded,
      'color': Color(0xFFE8F4FD),
      'iconColor': Color(0xFF2980B9),
    },
    {
      'name': 'Comfort Leather Harness',
      'category': 'Accessories',
      'price': '\$24.99',
      'rating': 4.9,
      'icon': Icons.pets_rounded,
      'color': Color(0xFFFFF7E6),
      'iconColor': Color(0xFFD35400),
    },
    {
      'name': 'Chew Resistant Bone',
      'category': 'Toys',
      'price': '\$9.99',
      'rating': 4.6,
      'icon': Icons.extension_rounded,
      'color': Color(0xFFF3E5F5),
      'iconColor': Color(0xFF8E24AA),
    },
    {
      'name': 'Healthy Grain Kibble',
      'category': 'Food & Treats',
      'price': '\$32.00',
      'rating': 5.0,
      'icon': Icons.restaurant_menu_rounded,
      'color': Color(0xFFEFEBE9),
      'iconColor': Color(0xFF6D4C41),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _selectedCategoryIndex == 0
        ? _products
        : _products
              .where(
                (p) => p['category'] == _categories[_selectedCategoryIndex],
              )
              .toList();

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'PawStay Shop',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: PawStayTheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: PawStayTheme.primary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Your cart is empty',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                  backgroundColor: PawStayTheme.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                decoration: InputDecoration(
                  hintText: 'Search food, toys, accessories...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                  icon: const Icon(
                    Icons.search,
                    color: PawStayTheme.onSurfaceVariant,
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
                    selectedColor: PawStayTheme.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? PawStayTheme.primary
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

            Text(
              'Featured Products',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),

            const SizedBox(height: 14),

            // Product Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PawStayTheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: product['color'] as Color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              product['icon'] as IconData,
                              size: 42,
                              color: product['iconColor'] as Color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        product['name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product['rating'].toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PawStayTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product['price'].toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: PawStayTheme.primary,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${product['name']} added to cart!',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: PawStayTheme.primary,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: PawStayTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
