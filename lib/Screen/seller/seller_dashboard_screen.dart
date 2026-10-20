import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/seller_api_service.dart';
import '../../services/session_service.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/animated_ai_nav_icon.dart';
import '../auth/login.dart';
import 'add_product_screen.dart';
import 'analytics_screen.dart';
import 'order_request.dart';
import 'profile.dart';
import 'seller_ai_assistant_screen.dart';
import 'seller_products_screen.dart';
import 'seller_verification_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  final String sellerLookup;

  const SellerDashboardScreen({super.key, required this.sellerLookup});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  final Set<int> _loadedSections = {0};
  bool _isLoading = true;
  String? _error;
  late String _displayName;

  Map<String, dynamic> _analytics = const {};
  bool _isVerified = false;
  bool _isShopOwner = false;

  String? _listingTypeFilter;
  String? _animalTypeFilter;

  @override
  void initState() {
    super.initState();
    _displayName = _nameFromLookup(widget.sellerLookup);
    _loadOverview();
    _loadSellerName();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _nameFromLookup(String lookup) {
    final name = lookup
        .trim()
        .split('@')
        .first
        .replaceAll(RegExp(r'[._-]+'), ' ');
    if (name.isEmpty) return 'Seller';
    return name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Future<void> _loadSellerName() async {
    try {
      final profile = await SellerApiService.fetchSellerProfile(
        widget.sellerLookup,
      );
      final fullName = profile['full_name']?.toString().trim();
      final username = profile['username']?.toString().trim();
      final name = (fullName != null && fullName.isNotEmpty)
          ? fullName.split(RegExp(r'\s+')).first
          : (username != null && username.isNotEmpty ? username : null);
      if (name != null && mounted) setState(() => _displayName = name);
    } on Exception catch (error) {
      debugPrint('Could not load seller name: $error');
    }
  }

  Future<void> _loadOverview() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final analyticsFuture = SellerApiService.fetchAnalytics(
        widget.sellerLookup,
      );
      final verificationFuture = SellerApiService.fetchVerification(
        widget.sellerLookup,
      );

      final results = await Future.wait([analyticsFuture, verificationFuture]);
      final analytics = results[0];
      final verification = results[1];

      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _isVerified = verification['status'] == 'Approved';
        _isShopOwner = verification['is_shop_owner'] == true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _handleSellAction() {
    if (!_isVerified) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerVerificationScreen(
            sellerLookup: widget.sellerLookup,
            onVerificationComplete: () {
              Navigator.pop(context);
              _loadOverview();
              _selectPage(2);
            },
          ),
        ),
      );
    } else {
      _selectPage(2);
    }
  }

  void _showListings({String? type, String? animal}) {
    setState(() {
      _listingTypeFilter = type;
      _animalTypeFilter = animal;
      _selectedIndex = 1;
      _loadedSections.add(1);
    });
    _closeDrawerIfNeeded();
  }

  void _selectPage(int index) {
    if (index == 2 && !_isVerified) {
      _handleSellAction();
      return;
    }

    setState(() {
      _selectedIndex = index;
      _loadedSections.add(index);
      if (index != 1) {
        _listingTypeFilter = null;
        _animalTypeFilter = null;
      }
    });
    _closeDrawerIfNeeded();
  }

  void _closeDrawerIfNeeded() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) scaffold?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final wideLayout = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: wideLayout ? null : Drawer(child: _buildSidebar(context)),
      appBar: AppBar(
        title: Text(
          _appBarTitle,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions:
            const [], // Removed refresh button and paw logo per user request
      ),
      body: Row(
        children: [
          if (wideLayout) _buildSidebar(context),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildOverview(context),
                _loadedSections.contains(1)
                    ? SellerProductsScreen(
                        key: ValueKey('$_listingTypeFilter-$_animalTypeFilter'),
                        sellerLookup: widget.sellerLookup,
                        listingTypeFilter: _listingTypeFilter,
                        animalTypeFilter: _animalTypeFilter,
                        onAddProduct: _handleSellAction,
                        onProductsChanged: _loadOverview,
                      )
                    : const SizedBox.shrink(),
                _loadedSections.contains(2)
                    ? AddProductScreen(
                        sellerLookup: widget.sellerLookup,
                        onCancel: () => _selectPage(0),
                        onSuccess: () {
                          _loadOverview();
                          _selectPage(1);
                        },
                      )
                    : const SizedBox.shrink(),
                _loadedSections.contains(3)
                    ? AnalyticsScreen(sellerLookup: widget.sellerLookup)
                    : const SizedBox.shrink(),
                _loadedSections.contains(4)
                    ? SellerAiAssistantScreen(sellerLookup: widget.sellerLookup)
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: wideLayout
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectPage,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Listings',
                ),
                NavigationDestination(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: PawStayTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                  label: 'Sell',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
                const NavigationDestination(
                  icon: AnimatedAiNavIcon(),
                  label: 'AI',
                ),
              ],
            ),
    );
  }

  String get _appBarTitle => switch (_selectedIndex) {
    0 => 'Seller Dashboard',
    1 => 'My Products',
    2 => 'Sell Item',
    3 => 'Analytics',
    _ => 'PawStay AI Assistant',
  };

  Widget _buildSidebar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: PawStayTheme.primary,
                    child: Icon(Icons.storefront, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seller Center',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ListTile(
              selected: _selectedIndex == 0,
              leading: const Icon(Icons.home_outlined),
              title: const Text('Dashboard'),
              onTap: () => _selectPage(0),
            ),
            ListTile(
              selected: _selectedIndex == 1,
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('My Products'),
              onTap: () => _selectPage(1),
            ),
            ListTile(
              selected: _selectedIndex == 2,
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Sell Item'),
              onTap: () => _selectPage(2),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Order Requests'),
              onTap: () {
                _closeDrawerIfNeeded();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SellerOrderRequestScreen(
                      sellerLookup: widget.sellerLookup,
                      onOrdersChanged: _loadOverview,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              selected: _selectedIndex == 3,
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Analytics'),
              onTap: () => _selectPage(3),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Profile'),
              onTap: () {
                _closeDrawerIfNeeded();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SellerProfileScreen(sellerLookup: widget.sellerLookup),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              onTap: _confirmLogout,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Seller: ${widget.sellerLookup}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    _closeDrawerIfNeeded();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to manage listings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SessionService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _buildOverview(BuildContext context) {
    final analytics = _analytics;
    final categories =
        analytics['category_counts'] as Map<String, dynamic>? ?? const {};
    final colors = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadOverview,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final totalProducts = analytics['total_products'] ?? 0;
    final totalFood = categories['food'] ?? 0;
    final totalSales = (analytics['payments_received'] as num?) ?? 0.0;
    final orderRequests = analytics['total_orders'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Welcome & Verification Card - Responsive Layout
          Card(
            elevation: 0,
            color: PawStayTheme.primaryContainer.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: PawStayTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: PawStayTheme.primary,
                        child: Icon(
                          _isVerified ? Icons.verified : Icons.error_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_greeting, $_displayName',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _isVerified
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isVerified
                                    ? (_isShopOwner
                                          ? 'Verified Shop'
                                          : 'Verified Individual')
                                    : 'Verification Required',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isVerified
                                      ? Colors.green
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isVerified
                        ? 'Manage listings, orders, and sales stats.'
                        : 'Verify identity to start listing pets or products.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (!_isVerified) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleSellAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.verified_user, size: 16),
                        label: const Text('Verify Profile Now'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Hero Card: SELL BUTTON - Mobile Responsive Layout
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    PawStayTheme.primary,
                    PawStayTheme.primary.withValues(alpha: 0.85),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Have a pet or product to sell?',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isShopOwner
                        ? 'List Pets, Pet Food, or Accessories.'
                        : 'List your Pets for sale securely.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _handleSellAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: PawStayTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle, size: 20),
                    label: Text(
                      'SELL NOW',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Business Overview',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 2x2 BOX (GRID) STRUCTURE FOR STAT CARDS
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: PawStayResponsive.gridAspectRatio(
              context: context,
              baseRatio: 1.15,
              compactRatio: 1.0,
            ),
            children: [
              _statBoxCard(
                context,
                title: 'Total Product List',
                value: '$totalProducts',
                subtitle: 'Active products',
                icon: Icons.inventory_2_outlined,
                color: Colors.blue.shade700,
                onTap: () => _selectPage(1),
              ),
              _statBoxCard(
                context,
                title: 'Total Food Listing',
                value: '$totalFood',
                subtitle: 'Food items',
                icon: Icons.restaurant_menu_outlined,
                color: Colors.deepOrange,
                onTap: () => _showListings(type: 'food'),
              ),
              _statBoxCard(
                context,
                title: 'Total Sell',
                value: '₹${totalSales.toStringAsFixed(2)}',
                subtitle: 'Paid revenue',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.green.shade700,
                onTap: () => _selectPage(4),
              ),
              _statBoxCard(
                context,
                title: 'Order Request',
                value: '$orderRequests',
                subtitle: 'Customer orders',
                icon: Icons.shopping_bag_outlined,
                color: Colors.purple,
                onTap: () => _selectPage(3),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Categories Quick Navigation
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Listing Categories',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _categoryChip(
                          context,
                          label: 'Pets',
                          count: '${categories['pets'] ?? 0}',
                          icon: Icons.pets,
                          onTap: () => _showListings(type: 'pets'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _categoryChip(
                          context,
                          label: 'Pet Food',
                          count: '${categories['food'] ?? 0}',
                          icon: Icons.restaurant,
                          onTap: () => _showListings(type: 'food'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _categoryChip(
                          context,
                          label: 'Items',
                          count: '${categories['other'] ?? 0}',
                          icon: Icons.shopping_bag_outlined,
                          onTap: () => _showListings(type: 'other'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statBoxCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _categoryChip(
    BuildContext context, {
    required String label,
    required String count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: PawStayTheme.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              '$count items',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
