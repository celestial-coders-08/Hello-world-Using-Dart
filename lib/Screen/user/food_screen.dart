import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/pawstay_theme.dart';

class FoodScreen extends StatefulWidget {
  final String? userLookup;

  const FoodScreen({super.key, this.userLookup});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Shopping Cart state
  final Map<String, int> _cart = {}; // product id -> quantity

  final List<String> _categories = [
    'All',
    'Dry Kibble',
    'Wet Gourmet',
    'Treats & Chews',
    'Supplements',
    'Vet Diets',
  ];

  // Nutrition calculator state
  String _calcPetType = 'Dog';
  double _calcWeight = 12.0; // in kg
  String _calcActivity = 'Normal';
  double _calculatedCalories = 620.0;

  final List<Map<String, dynamic>> _products = [
    {
      'id': 'food-1',
      'name': 'Royal Canin Adult Complete Nutrition',
      'brand': 'Royal Canin',
      'category': 'Dry Kibble',
      'price': 34.99,
      'oldPrice': 42.99,
      'rating': 4.9,
      'reviews': 210,
      'weight': '3 kg',
      'discount': '18% OFF',
      'icon': Icons.bakery_dining_rounded,
      'color': Colors.amber,
      'description':
          'Formulated with high-grade protein, omega-3 fatty acids, and essential vitamins for active dogs.',
    },
    {
      'id': 'food-2',
      'name': 'Purina Pro Plan Salmon & Rice Wet Gourmet',
      'brand': 'Purina Pro Plan',
      'category': 'Wet Gourmet',
      'price': 22.50,
      'oldPrice': 26.00,
      'rating': 4.8,
      'reviews': 165,
      'weight': '12 cans (370g)',
      'discount': '13% OFF',
      'icon': Icons.soup_kitchen_rounded,
      'color': Colors.deepOrange,
      'description':
          'Real salmon pate formula supporting digestive health and a lustrous shiny coat.',
    },
    {
      'id': 'food-3',
      'name': 'Hill\'s Science Diet Sensitive Stomach & Skin',
      'brand': 'Hill\'s Science',
      'category': 'Vet Diets',
      'price': 48.99,
      'oldPrice': 55.00,
      'rating': 4.95,
      'reviews': 320,
      'weight': '5 kg',
      'discount': 'Vet Recommended',
      'icon': Icons.health_and_safety_rounded,
      'color': PawStayTheme.secondary,
      'description':
          'Prebiotic fiber to fuel beneficial gut bacteria & support a balanced microbiome.',
    },
    {
      'id': 'food-4',
      'name': 'Organic Dental Health Bites & Dental Chews',
      'brand': 'PawStay Fresh',
      'category': 'Treats & Chews',
      'price': 14.99,
      'oldPrice': 18.00,
      'rating': 4.7,
      'reviews': 95,
      'weight': '450g Pack',
      'discount': 'Bestseller',
      'icon': Icons.cookie_rounded,
      'color': Colors.brown,
      'description':
          'Reduces tartar buildup, freshens breath, and satisfies natural chewing instincts.',
    },
    {
      'id': 'food-5',
      'name': 'Zesty Paws Multivitamin & Joint Soft Chews',
      'brand': 'Zesty Paws',
      'category': 'Supplements',
      'price': 29.95,
      'oldPrice': 34.95,
      'rating': 4.85,
      'reviews': 240,
      'weight': '90 Chews',
      'discount': '15% OFF',
      'icon': Icons.medication_liquid_rounded,
      'color': Colors.purple,
      'description':
          'Glucosamine, chondroitin, and MSM blend for joint mobility and hip support.',
    },
    {
      'id': 'food-6',
      'name': 'Orijen Six Fish Grain-Free Dry Cat Food',
      'brand': 'Orijen',
      'category': 'Dry Kibble',
      'price': 41.99,
      'oldPrice': 46.99,
      'rating': 4.9,
      'reviews': 180,
      'weight': '2.27 kg',
      'discount': 'Grain Free',
      'icon': Icons.set_meal_rounded,
      'color': Colors.blueAccent,
      'description':
          'Rich in raw wild-caught fish, providing essential protein and omega oils for cats of all ages.',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _recalculateCalories() {
    // Basic RER formula: 70 * (weight in kg)^0.75
    // Activity multiplier: Low = 1.2, Normal = 1.6, High = 2.0
    double mult = 1.6;
    if (_calcActivity == 'Low') mult = 1.2;
    if (_calcActivity == 'High') mult = 2.0;

    if (_calcPetType == 'Cat') mult *= 0.85;

    final rer = 70.0 * (double.parse((_calcWeight).toStringAsFixed(1)));
    setState(() {
      _calculatedCalories = (rer * mult * 0.45).clamp(150.0, 2500.0);
    });
  }

  int get _totalCartItems {
    int count = 0;
    _cart.forEach((_, qty) => count += qty);
    return count;
  }

  double get _cartSubtotal {
    double total = 0.0;
    _cart.forEach((id, qty) {
      final prod = _products.firstWhere((p) => p['id'] == id, orElse: () => {});
      if (prod.isNotEmpty) {
        total += (prod['price'] as double) * qty;
      }
    });
    return total;
  }

  void _addToCart(String id) {
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added item to your shopping cart!',
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: PawStayTheme.secondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCartSheet() {
    final addressController = TextEditingController(
      text: '123 Park Avenue, Apt 4B, New York',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final cartItems = _cart.entries.toList();

          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_rounded,
                        color: PawStayTheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Your Shopping Cart',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_totalCartItems items',
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  cartItems.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.remove_shopping_cart_rounded,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Your cart is currently empty.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cartItems.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final entry = cartItems[index];
                                final prod = _products.firstWhere(
                                  (p) => p['id'] == entry.key,
                                );
                                final qty = entry.value;

                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: PawStayTheme.primaryContainer
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        prod['icon'] as IconData,
                                        color: PawStayTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prod['name'],
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '\$${prod['price']} x $qty',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (_cart[entry.key]! > 1) {
                                                _cart[entry.key] =
                                                    _cart[entry.key]! - 1;
                                              } else {
                                                _cart.remove(entry.key);
                                              }
                                            });
                                            setModalState(() {});
                                          },
                                        ),
                                        Text(
                                          '$qty',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _cart[entry.key] =
                                                  _cart[entry.key]! + 1;
                                            });
                                            setModalState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),

                            const Divider(height: 24),

                            // Delivery Address
                            Text(
                              'Delivery Address',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: addressController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.location_on_rounded,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Order Summary calculation
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subtotal',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '\$${_cartSubtotal.toStringAsFixed(2)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Delivery Fee',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _cartSubtotal > 50 ? 'FREE' : '\$3.99',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _cartSubtotal > 50
                                              ? PawStayTheme.secondary
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '\$${(_cartSubtotal + (_cartSubtotal > 50 ? 0 : 3.99)).toStringAsFixed(2)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: PawStayTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _cart.clear();
                                  });
                                  Navigator.pop(ctx);
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: PawStayTheme.secondary,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Order Placed!',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Text(
                                        'Thank you for your order! Your pet food and treats will be delivered to ${addressController.text} within 24 hours.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                        ),
                                      ),
                                      actions: [
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: Text(
                                            'OK',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: Text(
                                  'Checkout & Place Order',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredProducts = _products.where((p) {
      final matchesCategory =
          _selectedCategory == 'All' || p['category'] == _selectedCategory;
      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          (p['name'] as String).toLowerCase().contains(query) ||
          (p['brand'] as String).toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Food & Nutrition',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: _showCartSheet,
              ),
              if (_totalCartItems > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: PawStayTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_totalCartItems',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _totalCartItems > 0
          ? FloatingActionButton.extended(
              onPressed: _showCartSheet,
              backgroundColor: PawStayTheme.primary,
              icon: const Icon(
                Icons.shopping_cart_rounded,
                color: Colors.white,
              ),
              label: Text(
                'Cart ($_totalCartItems) • \$${_cartSubtotal.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PawStayTheme.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interactive Calorie Calculator Widget
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PawStayTheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
                border: Border.all(
                  color: PawStayTheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PawStayTheme.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calculate_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pet Daily Portion Calculator',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Calculate exact daily calories for your pet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Pet type choice
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _calcPetType,
                          decoration: InputDecoration(
                            labelText: 'Pet Type',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: ['Dog', 'Cat']
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _calcPetType = val;
                              _recalculateCalories();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Activity choice
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _calcActivity,
                          decoration: InputDecoration(
                            labelText: 'Activity',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: ['Low', 'Normal', 'High']
                              .map(
                                (a) =>
                                    DropdownMenuItem(value: a, child: Text(a)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _calcActivity = val;
                              _recalculateCalories();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Pet Weight: ${_calcWeight.toStringAsFixed(1)} kg',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _calcWeight,
                          min: 1.0,
                          max: 45.0,
                          divisions: 88,
                          activeColor: PawStayTheme.secondary,
                          onChanged: (v) {
                            _calcWeight = v;
                            _recalculateCalories();
                          },
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target Daily Energy:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_calculatedCalories.toStringAsFixed(0)} kcal / day',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search kibble, wet food, treats, brands...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 16),

            // Category Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSel = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: theme.colorScheme.primary,
                    onSelected: (s) {
                      if (s) setState(() => _selectedCategory = cat);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Pet Foods & Products (${filteredProducts.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Products Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final p = filteredProducts[index];
                final inCartQty = _cart[p['id']] ?? 0;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Discount Badge & Graphic Icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: PawStayTheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['discount'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: PawStayTheme.primary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (p['color'] as Color).withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                p['icon'] as IconData,
                                size: 42,
                                color: p['color'] as Color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p['brand'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          p['name'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['weight'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\$${p['price']}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: PawStayTheme.primary,
                                  ),
                                ),
                                Text(
                                  '\$${p['oldPrice']}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: theme.colorScheme.outline,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _addToCart(p['id']),
                              child: inCartQty > 0
                                  ? Text(
                                      '$inCartQty',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 18,
                                    ),
                            ),
                          ],
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
    );
  }
}
