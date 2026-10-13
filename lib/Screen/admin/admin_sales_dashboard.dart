import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_theme.dart';

class OrderTransaction {
  final String orderId;
  final String customerName;
  final String customerEmail;
  final String itemDescription;
  final String category;
  final double amount;
  final double platformFee;
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

  @override
  void initState() {
    super.initState();
    _initOrders();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initOrders() {
    _orders = [
      OrderTransaction(
        orderId: 'PST-9842',
        customerName: 'Sarah Jenkins',
        customerEmail: 'sarah.j@gmail.com',
        itemDescription: 'Royal Canin Maxi Puppy Food (15kg)',
        category: 'Food',
        amount: 84.99,
        platformFee: 8.50,
        paymentMethod: 'Credit Card',
        timestamp: '10m ago',
        status: 'Paid',
      ),
      OrderTransaction(
        orderId: 'PST-9841',
        customerName: 'David Miller',
        customerEmail: 'david.m@yahoo.com',
        itemDescription: 'Emergency Vet Consultation - Dr. Kimberly',
        category: 'Vet',
        amount: 65.00,
        platformFee: 6.50,
        paymentMethod: 'Apple Pay',
        timestamp: '42m ago',
        status: 'Paid',
      ),
      OrderTransaction(
        orderId: 'PST-9840',
        customerName: 'Marcus Vance',
        customerEmail: 'marcus.v@tech.co',
        itemDescription: 'Weekend Luxury Dog Stay (3 Nights)',
        category: 'Stay',
        amount: 144.00,
        platformFee: 14.40,
        paymentMethod: 'UPI',
        timestamp: '2h ago',
        status: 'Processing',
      ),
      OrderTransaction(
        orderId: 'PST-9839',
        customerName: 'Elena Rostova',
        customerEmail: 'elena.r@outlook.com',
        itemDescription: 'Premium Salmon Kibble & Chews',
        category: 'Food',
        amount: 42.50,
        platformFee: 4.25,
        paymentMethod: 'Credit Card',
        timestamp: '5h ago',
        status: 'Paid',
      ),
      OrderTransaction(
        orderId: 'PST-9838',
        customerName: 'Liam O\'Connor',
        customerEmail: 'liam.oc@gmail.com',
        itemDescription: '5x Weekly Dog Walking Package',
        category: 'Walking',
        amount: 110.00,
        platformFee: 11.00,
        paymentMethod: 'Debit Card',
        timestamp: 'Yesterday',
        status: 'Paid',
      ),
      OrderTransaction(
        orderId: 'PST-9837',
        customerName: 'Chloe Bennett',
        customerEmail: 'chloe.b@apple.com',
        itemDescription: 'Dental Cleaning & Anti-Flea Treatment',
        category: 'Vet',
        amount: 95.00,
        platformFee: 9.50,
        paymentMethod: 'Credit Card',
        timestamp: 'Yesterday',
        status: 'Refunded',
      ),
    ];
    _applyFilter();
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
                      Text('\$${order.amount.toStringAsFixed(2)}', style: AdminTheme.heading(13, color: AdminTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInvoiceRow('Platform Commission (10%)', '\$${order.platformFee.toStringAsFixed(2)}'),
                  _buildInvoiceRow('Payment Method', order.paymentMethod),
                  Divider(color: AdminTheme.border, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Charged:', style: AdminTheme.heading(14)),
                      Text(
                        '\$${order.amount.toStringAsFixed(2)}',
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
                      onPressed: () {
                        setState(() {
                          order.status = 'Refunded';
                          _applyFilter();
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Refund processed for #${order.orderId}'),
                            backgroundColor: AdminTheme.statusWarning,
                          ),
                        );
                      },
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
                'PawStay_Sales_Report.csv downloaded!',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AdminTheme.secondary,
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

          // Key Financial Metrics Cards (Responsive 2x2 grid on phones)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard('Gross Volume', '\$148,920', '+22.4% this quarter', Icons.trending_up, AdminTheme.primary, cardWidth),
                  _buildMetricCard('Platform Cut (10%)', '\$14,892', 'Net profit', Icons.account_balance_wallet_outlined, AdminTheme.secondary, cardWidth),
                  _buildMetricCard('Total Orders', '4,120', '99.2% success', Icons.shopping_bag_outlined, const Color(0xFFD97757), cardWidth),
                  _buildMetricCard('Avg Order Val', '\$36.14', '+\$4.20 per order', Icons.receipt_long_outlined, const Color(0xFF506447), cardWidth),
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
                          if (newVal != null) setState(() => _timeRange = newVal);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: PawStayRevenueChartPainter(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Oct (Peak)', 'Dec']
                      .map((m) => Text(m, style: AdminTheme.body(9, color: m.contains('Peak') ? AdminTheme.primary : AdminTheme.textMuted)))
                      .toList(),
                ),
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
                _buildCategoryProgress('Food & Nutrition Shop', '\$65,520 (44%)', 0.44, AdminTheme.primary),
                const SizedBox(height: 10),
                _buildCategoryProgress('Vet Consultations & Emergency', '\$43,180 (29%)', 0.29, AdminTheme.secondary),
                const SizedBox(height: 10),
                _buildCategoryProgress('Daycare & Resort Stay', '\$26,800 (18%)', 0.18, const Color(0xFFD97757)),
                const SizedBox(height: 10),
                _buildCategoryProgress('Dog Walking & Fitness', '\$13,420 (9%)', 0.09, const Color(0xFF506447)),
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
                      _buildStatusFilterChip('All', _orders.length),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Paid', _orders.where((o) => o.status == 'Paid').length),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Processing', _orders.where((o) => o.status == 'Processing').length),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Refunded', _orders.where((o) => o.status == 'Refunded').length),
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
                          '\$${order.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: order.status == 'Refunded' ? AdminTheme.statusDanger : AdminTheme.textPrimary,
                          ),
                        ),
                        Text('Fee +\$${order.platformFee.toStringAsFixed(2)}', style: AdminTheme.body(10, color: AdminTheme.secondary, weight: FontWeight.bold)),
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

    final path = Path();
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.18, size.height * 0.65),
      Offset(size.width * 0.36, size.height * 0.55),
      Offset(size.width * 0.54, size.height * 0.45),
      Offset(size.width * 0.72, size.height * 0.25),
      Offset(size.width * 0.85, size.height * 0.1),
      Offset(size.width, size.height * 0.3),
    ];

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

    final peakPoint = points[5];
    canvas.drawCircle(peakPoint, 5, Paint()..color = AdminTheme.primary);
    canvas.drawCircle(peakPoint, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
