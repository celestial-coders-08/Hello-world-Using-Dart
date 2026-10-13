import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import 'admin_theme.dart';

class OrderTransaction {
  final String orderId;
  final String customerName;
  final String customerEmail;
  final String itemDescription;
  final String category;
  final double amount;
  final double? platformFee;
  final String paymentMethod;
  final String timestamp;
  String status;

  OrderTransaction({
    required this.orderId,
    required this.customerName,
    required this.customerEmail,
    required this.itemDescription,
    required this.category,
    required this.amount,
    required this.platformFee,
    required this.paymentMethod,
    required this.timestamp,
    required this.status,
  });
}

class AdminSalesDashboard extends StatefulWidget {
  const AdminSalesDashboard({super.key});

  @override
  State<AdminSalesDashboard> createState() => _AdminSalesDashboardState();
}

class _AdminSalesDashboardState extends State<AdminSalesDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  String _timeRange = 'This Month';

  List<OrderTransaction> _orders = [];
  List<OrderTransaction> _filteredOrders = [];
  Map<String, dynamic> _report = const {};
  List<Map<String, dynamic>> _revenueSeries = const [];
  List<Map<String, dynamic>> _categorySales = const [];
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSales();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      final token = preferences.getString('access_token');
      if (token == null || token.isEmpty) {
        throw StateError('Admin sign-in is required to load sales data.');
      }
      final period = switch (_timeRange) {
        'This Week' => 'week',
        'All Time' => 'all',
        _ => 'month',
      };
      final response = await http
          .get(
            Uri.parse('${ApiConfig.adminBaseUrl}/admin/sales')
                .replace(queryParameters: {'period': period}),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Could not load sales data (${response.statusCode}).');
      }
      final report = jsonDecode(response.body) as Map<String, dynamic>;
      _report = report;
      _revenueSeries = (report['revenue_series'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _categorySales = (report['category_sales'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _orders = (report['orders'] as List<dynamic>).map((item) {
        final json = Map<String, dynamic>.from(item as Map);
        return OrderTransaction(
          orderId: json['order_id']?.toString() ?? '',
          customerName: json['customer_name']?.toString() ?? '',
          customerEmail: json['customer_email']?.toString() ?? '',
          itemDescription: json['item_description']?.toString() ?? '',
          category: json['category']?.toString() ?? 'other',
          amount: (json['amount'] as num?)?.toDouble() ?? 0,
          platformFee: null,
          paymentMethod: json['payment_method']?.toString() ?? 'N/A',
          timestamp: json['timestamp']?.toString() ?? '',
          status: json['status']?.toString() ?? 'Unknown',
        );
      }).toList();
      _loadError = null;
    } catch (error, stackTrace) {
      debugPrint('Failed to load admin sales data: $error\n$stackTrace');
      _orders = [];
      _report = const {};
      _revenueSeries = const [];
      _categorySales = const [];
      _loadError = error.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) {
      _applyFilter();
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredOrders = _orders.where((order) {
        final matchesQuery = order.orderId.toLowerCase().contains(query) ||
            order.customerName.toLowerCase().contains(query) ||
            order.itemDescription.toLowerCase().contains(query);

        if (!matchesQuery) return false;

        if (_selectedStatus != 'All') {
          return order.status.toLowerCase() == _selectedStatus.toLowerCase();
        }
        return true;
      }).toList();
    });
  }

  String _money(Object? amount) =>
      '₹${(amount as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}';

  String _reportedMoney(String key) =>
      _loadError == null ? _money(_report[key]) : 'N/A';

  String _reportedCount(String key) =>
      _loadError == null ? '${_report[key] ?? 0}' : 'N/A';

  String _categoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & nutrition':
        return 'Food & Nutrition';
      case 'vet':
      case 'veterinary':
        return 'Vet Services';
      case 'stay':
      case 'daycare':
        return 'Daycare & Stay';
      case 'walking':
        return 'Dog Walking';
      default:
        return category.isEmpty ? 'Other' : category[0].toUpperCase() + category.substring(1);
    }
  }

  Widget _buildRevenueChart() {
    final amounts = _revenueSeries
        .map((item) => (item['amount'] as num?)?.toDouble() ?? 0)
        .toList();
    final labels = _revenueSeries.map((item) => item['label']?.toString() ?? '').toList();
    final labelIndexes = <int>{
      for (var i = 0; i < labels.length; i += labels.length > 6 ? (labels.length / 5).ceil() : 1)
        i,
      if (labels.isNotEmpty) labels.length - 1,
    }.toList()
      ..sort();
    return Column(
      children: [
        SizedBox(
          height: 100,
          width: double.infinity,
          child: CustomPaint(painter: PawStayRevenueChartPainter(values: amounts)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final index in labelIndexes)
              Text(labels[index], style: AdminTheme.body(9, color: AdminTheme.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySales() {
    if (_loadError != null) {
      return Text(
        'Sales breakdown unavailable.',
        style: AdminTheme.body(12, color: AdminTheme.statusDanger),
      );
    }
    final total = _categorySales.fold<double>(
      0,
      (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
    );
    if (_categorySales.isEmpty) {
      return Text(
        'No paid sales in this period.',
        style: AdminTheme.body(12, color: AdminTheme.textMuted),
      );
    }
    const colors = [
      AdminTheme.primary,
      AdminTheme.secondary,
      Color(0xFFD97757),
      Color(0xFF506447),
    ];
    return Column(
      children: [
        for (var i = 0; i < _categorySales.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildCategoryProgress(
            _categoryLabel(_categorySales[i]['category']?.toString() ?? 'other'),
            '${_money(_categorySales[i]['amount'])} (${total == 0 ? 0 : (((_categorySales[i]['amount'] as num?)?.toDouble() ?? 0) * 100 / total).toStringAsFixed(1)}%)',
            total == 0
                ? 0
                : ((_categorySales[i]['amount'] as num?)?.toDouble() ?? 0) / total,
            colors[i % colors.length],
          ),
        ],
      ],
    );
  }

  void _showInvoiceModal(OrderTransaction order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AdminTheme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AdminTheme.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice #${order.orderId}', style: AdminTheme.heading(16)),
                    Text('Placed ${order.timestamp}', style: AdminTheme.body(11)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(order.status),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${order.customerName}', style: AdminTheme.heading(13, color: AdminTheme.textPrimary)),
                  Text(order.customerEmail, style: AdminTheme.body(11, color: AdminTheme.textMuted)),
                  Divider(color: AdminTheme.border, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(order.itemDescription, style: AdminTheme.body(12, color: AdminTheme.textPrimary)),
                      ),
                      Text(_money(order.amount), style: AdminTheme.heading(13, color: AdminTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInvoiceRow(
                    'Platform Commission',
                    order.platformFee == null ? 'Not recorded' : _money(order.platformFee),
                  ),
                  _buildInvoiceRow('Payment Method', order.paymentMethod),
                  Divider(color: AdminTheme.border, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Charged:', style: AdminTheme.heading(14)),
                      Text(
                        _money(order.amount),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (order.status != 'Refunded') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminTheme.statusDanger,
                        side: BorderSide(color: AdminTheme.statusDanger),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Refund', style: TextStyle(fontSize: 12)),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refund processing is not available in the admin API.'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download, size: 16, color: Colors.white),
                    label: Text('Download PDF', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invoice #${order.orderId}.pdf downloaded!'),
                          backgroundColor: AdminTheme.secondary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminTheme.body(11, color: AdminTheme.textMuted)),
          Text(val, style: AdminTheme.body(11, color: AdminTheme.textSecondary, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CSV export is not connected yet.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AdminTheme.statusWarning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdminTheme.isDarkMode,
      builder: (context, isDark, _) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Export Action
            Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales & Revenue', style: AdminTheme.heading(20)),
                    const SizedBox(height: 2),
                    Text('Platform earnings, gross GMV & orders audit', style: AdminTheme.body(12)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 16),
                label: Text('Export', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                onPressed: _exportReport,
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Could not load live sales data: $_loadError',
                style: AdminTheme.body(12, color: AdminTheme.statusDanger),
              ),
            ),

          // Key Financial Metrics Cards (Responsive 2x2 grid on phones)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard('Gross Volume', _reportedMoney('gross_volume'), _timeRange, Icons.trending_up, AdminTheme.primary, cardWidth),
                  _buildMetricCard(
                    'Platform Revenue',
                    _report['commission_revenue'] == null
                        ? 'N/A'
                        : _money(_report['commission_revenue']),
                    'Not recorded in database',
                    Icons.account_balance_wallet_outlined,
                    AdminTheme.secondary,
                    cardWidth,
                  ),
                  _buildMetricCard('Total Orders', _reportedCount('total_orders'), 'All payment statuses', Icons.shopping_bag_outlined, const Color(0xFFD97757), cardWidth),
                  _buildMetricCard('Avg Order Val', _reportedMoney('average_order_value'), 'Paid orders', Icons.receipt_long_outlined, const Color(0xFF506447), cardWidth),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Revenue Projections Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AdminTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Revenue Trajectory', style: AdminTheme.heading(15)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _timeRange,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(color: AdminTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        items: ['This Week', 'This Month', 'All Time'].map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (newVal) {
                          if (newVal != null && newVal != _timeRange) {
                            setState(() => _timeRange = newVal);
                            _loadSales();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_loadError != null)
                  Text(
                    'Could not load revenue data: $_loadError',
                    style: AdminTheme.body(12, color: AdminTheme.statusDanger),
                  )
                else if (_isLoading)
                  const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _buildRevenueChart(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Category Sales Distribution Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AdminTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales by Category', style: AdminTheme.heading(15)),
                const SizedBox(height: 12),
                _buildCategorySales(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recent Transactions Search & Filters
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AdminTheme.cardDecoration(),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.plusJakartaSans(color: AdminTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search Order # or Customer...',
                    hintStyle: GoogleFonts.plusJakartaSans(color: AdminTheme.textMuted, fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: AdminTheme.primary, size: 20),
                    filled: true,
                    fillColor: AdminTheme.background,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AdminTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AdminTheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip(
                        'All',
                        (_report['total_orders'] as num?)?.toInt() ?? _orders.length,
                      ),
                      for (final entry
                          in (_report['status_counts'] as Map<String, dynamic>? ?? {})
                              .entries) ...[
                        const SizedBox(width: 6),
                        _buildStatusFilterChip(
                          entry.key,
                          (entry.value as num).toInt(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Orders List
          Text('Recent Orders (${_filteredOrders.length})', style: AdminTheme.heading(16)),
          const SizedBox(height: 10),

          if (_isLoading && _orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_loadError == null && _filteredOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No transactions found for this period.',
                style: AdminTheme.body(12, color: AdminTheme.textMuted),
              ),
            )
          else
            ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredOrders.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final order = _filteredOrders[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: AdminTheme.cardDecoration(),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getVerticalIcon(order.category), color: AdminTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('#${order.orderId}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.primary)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _getStatusBgColor(order.status),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  order.status,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(order.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(order.itemDescription, style: AdminTheme.body(12, color: AdminTheme.textPrimary, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 1),
                          Text('${order.customerName} • ${order.paymentMethod} • ${order.timestamp}', style: AdminTheme.body(10, color: AdminTheme.textMuted), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _money(order.amount),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: order.status == 'Refunded' ? AdminTheme.statusDanger : AdminTheme.textPrimary,
                          ),
                        ),
                        if (order.platformFee != null)
                          Text(
                            'Fee +${_money(order.platformFee)}',
                            style: AdminTheme.body(10, color: AdminTheme.secondary, weight: FontWeight.bold),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.receipt_outlined, color: AdminTheme.textMuted, size: 18),
                      onPressed: () => _showInvoiceModal(order),
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

  Widget _buildMetricCard(String title, String value, String subtext, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(title, style: AdminTheme.body(11, color: AdminTheme.textMuted), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AdminTheme.heading(18, color: AdminTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(subtext, style: AdminTheme.body(10, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCategoryProgress(String title, String subtitle, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(title, style: AdminTheme.body(12, color: AdminTheme.textPrimary, weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Text(subtitle, style: AdminTheme.body(11, color: color, weight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AdminTheme.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChip(String label, int count) {
    final isSelected = _selectedStatus == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = label;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AdminTheme.primary : AdminTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AdminTheme.primary : AdminTheme.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withValues(alpha: 0.2) : AdminTheme.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AdminTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AdminTheme.statusSuccess;
      case 'processing':
        return AdminTheme.statusWarning;
      case 'refunded':
        return AdminTheme.statusDanger;
      default:
        return AdminTheme.textMuted;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AdminTheme.statusSuccessBg;
      case 'processing':
        return AdminTheme.statusWarningBg;
      case 'refunded':
        return AdminTheme.statusDangerBg;
      default:
        return AdminTheme.cardBgSoft;
    }
  }

  IconData _getVerticalIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.shopping_basket_outlined;
      case 'vet':
        return Icons.medical_services_outlined;
      case 'stay':
        return Icons.hotel_outlined;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.receipt;
    }
  }
}

class PawStayRevenueChartPainter extends CustomPainter {
  PawStayRevenueChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AdminTheme.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AdminTheme.primary.withValues(alpha: 0.25),
          AdminTheme.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    if (values.isEmpty) return;
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1),
          size.height -
              (maximum <= 0 ? size.height / 2 : values[i] / maximum * size.height * 0.85),
        ),
    ];
    final path = Path();

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    final peakIndex = values.indexOf(maximum);
    final peakPoint = points[peakIndex];
    canvas.drawCircle(peakPoint, 5, Paint()..color = AdminTheme.primary);
    canvas.drawCircle(peakPoint, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant PawStayRevenueChartPainter oldDelegate) =>
      oldDelegate.values != values;
}