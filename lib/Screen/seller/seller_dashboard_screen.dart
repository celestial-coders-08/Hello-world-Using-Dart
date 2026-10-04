import 'package:flutter/material.dart';

import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../user/home.dart';
import 'add_product_screen.dart';
import 'analytics_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_products_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  final String sellerLookup;

  const SellerDashboardScreen({super.key, required this.sellerLookup});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  static const _destinations = [
    (label: 'Overview', icon: Icons.dashboard_outlined),
    (label: 'My listings', icon: Icons.storefront_outlined),
    (label: 'Add listing', icon: Icons.add_box_outlined),
    (label: 'Orders', icon: Icons.receipt_long_outlined),
    (label: 'Analytics', icon: Icons.query_stats_outlined),
  ];

  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _analytics = const {};
  String? _listingTypeFilter;
  String? _animalTypeFilter;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final analytics = await SellerApiService.fetchAnalytics(
        widget.sellerLookup,
      );
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showListings({String? type, String? animal}) {
    setState(() {
      _listingTypeFilter = type;
      _animalTypeFilter = animal;
      _selectedIndex = 1;
    });
    _closeDrawerIfNeeded();
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
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
          'Seller ${_destinations[_selectedIndex].label}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh overview',
            onPressed: _selectedIndex == 0 && !_isLoading
                ? _loadOverview
                : null,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Customer view',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(userLookup: widget.sellerLookup),
              ),
            ),
            icon: const Icon(Icons.pets_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wideLayout) _buildSidebar(context),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildOverview(context),
                SellerProductsScreen(
                  key: ValueKey('$_listingTypeFilter-$_animalTypeFilter'),
                  sellerLookup: widget.sellerLookup,
                  listingTypeFilter: _listingTypeFilter,
                  animalTypeFilter: _animalTypeFilter,
                  onAddProduct: () => _selectPage(2),
                  onProductsChanged: _loadOverview,
                ),
                AddProductScreen(
                  sellerLookup: widget.sellerLookup,
                  onCancel: () => _selectPage(0),
                  onSuccess: () {
                    _loadOverview();
                    _selectPage(1);
                  },
                ),
                SellerOrdersScreen(
                  sellerLookup: widget.sellerLookup,
                  onOrdersChanged: _loadOverview,
                ),
                AnalyticsScreen(sellerLookup: widget.sellerLookup),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 248,
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
                  CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    child: Icon(Icons.pets, color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seller Center',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            for (var index = 0; index < _destinations.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: ListTile(
                  selected: _selectedIndex == index,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(_destinations[index].icon),
                  title: Text(_destinations[index].label),
                  onTap: () => _selectPage(index),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'LISTING CATEGORIES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            _categoryNavItem(
              context,
              icon: Icons.restaurant,
              title: 'Pet food',
              onTap: () => _showListings(type: 'food'),
            ),
            _categoryNavItem(
              context,
              icon: Icons.pets,
              title: 'Dogs',
              onTap: () => _showListings(type: 'pets', animal: 'Dog'),
            ),
            _categoryNavItem(
              context,
              icon: Icons.pets_outlined,
              title: 'Cats',
              onTap: () => _showListings(type: 'pets', animal: 'Cat'),
            ),
            _categoryNavItem(
              context,
              icon: Icons.shopping_bag_outlined,
              title: 'Other items',
              onTap: () => _showListings(type: 'other'),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.sellerLookup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final analytics = _analytics;
    final categories =
        analytics['category_counts'] as Map<String, dynamic>? ?? const {};
    final revenueByDay =
        analytics['revenue_by_day'] as List<dynamic>? ?? const [];
    final maxRevenue = revenueByDay.fold<double>(0, (currentMax, rawDay) {
      final value =
          ((rawDay as Map<String, dynamic>)['revenue'] as num? ?? 0)
              .toDouble();
      return value > currentMax ? value : currentMax;
    });
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
              FilledButton.icon(
                onPressed: _loadOverview,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your shop at a glance',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Payments count only when an order is explicitly marked Paid.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 570
                  ? 2
                  : 1;
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _overviewMetric(
                    context,
                    width: itemWidth,
                    title: 'Payments received',
                    value: '${analytics['payments_received_count'] ?? 0}',
                    subtitle:
                        '₹${((analytics['payments_received'] as num?) ?? 0).toStringAsFixed(2)} received',
                    icon: Icons.payments_outlined,
                    color: colors.primary,
                  ),
                  _overviewMetric(
                    context,
                    width: itemWidth,
                    title: 'Products added',
                    value: '${analytics['total_products'] ?? 0}',
                    subtitle: '${analytics['total_orders'] ?? 0} total orders',
                    icon: Icons.add_box_outlined,
                    color: Colors.teal,
                  ),
                  _overviewMetric(
                    context,
                    width: itemWidth,
                    title: 'Food listings',
                    value: '${categories['food'] ?? 0}',
                    subtitle: 'Pet food and treats',
                    icon: Icons.restaurant,
                    color: Colors.deepOrange,
                    onTap: () => _showListings(type: 'food'),
                  ),
                  _overviewMetric(
                    context,
                    width: itemWidth,
                    title: 'Pets listed',
                    value: '${categories['pets'] ?? 0}',
                    subtitle:
                        '${categories['dogs'] ?? 0} dogs · ${categories['cats'] ?? 0} cats',
                    icon: Icons.pets,
                    color: Colors.indigo,
                    onTap: () => _showListings(type: 'pets'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Browse your listings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _categoryCard(
                context,
                'Food',
                '${categories['food'] ?? 0} listings',
                Icons.restaurant,
                () => _showListings(type: 'food'),
              ),
              _categoryCard(
                context,
                'Dogs',
                '${categories['dogs'] ?? 0} listings',
                Icons.pets,
                () => _showListings(type: 'pets', animal: 'Dog'),
              ),
              _categoryCard(
                context,
                'Cats',
                '${categories['cats'] ?? 0} listings',
                Icons.pets_outlined,
                () => _showListings(type: 'pets', animal: 'Cat'),
              ),
              _categoryCard(
                context,
                'Other pets',
                '${(categories['pets'] as int? ?? 0) - (categories['dogs'] as int? ?? 0) - (categories['cats'] as int? ?? 0)} listings',
                Icons.cruelty_free_outlined,
                () => _showListings(type: 'pets', animal: 'Other'),
              ),
              _categoryCard(
                context,
                'Other items',
                '${categories['other'] ?? 0} listings',
                Icons.shopping_bag_outlined,
                () => _showListings(type: 'other'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payments received · last 7 days',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (revenueByDay.isEmpty)
                    const Text('No payment history yet.')
                  else
                    ...revenueByDay.map((rawDay) {
                      final day = rawDay as Map<String, dynamic>;
                      final amount =
                          (day['revenue'] as num? ?? 0).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                _shortDate(day['date']?.toString() ?? ''),
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: maxRevenue == 0 ? 0 : amount / maxRevenue,
                                minHeight: 12,
                                borderRadius: BorderRadius.circular(8),
                                backgroundColor: colors.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 104,
                              child: Text(
                                '₹${amount.toStringAsFixed(2)}',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _selectPage(2),
              icon: const Icon(Icons.add),
              label: const Text('Create a listing'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewMetric(
    BuildContext context, {
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    String title,
    String count,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 185,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: PawStayTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(count),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
}
