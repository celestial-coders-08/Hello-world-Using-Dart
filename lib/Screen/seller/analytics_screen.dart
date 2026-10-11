import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/seller_api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final String sellerLookup;

  const AnalyticsScreen({super.key, required this.sellerLookup});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _periodOptions = {6: 'Last 6 months', 12: 'Last 12 months'};

  bool _isLoading = true;
  bool _hasLoaded = false;
  String? _error;
  int _selectedMonths = 12;
  List<Map<String, dynamic>> _orders = const [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sellerLookup != widget.sellerLookup) {
      _orders = const [];
      _hasLoaded = false;
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final orders = await SellerApiService.fetchOrders(widget.sellerLookup);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _hasLoaded = true;
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final periodOrders = _ordersForPeriod();
    final paidOrders = periodOrders.where(_isPaid).toList();
    final paidAmount = paidOrders.fold<double>(
      0,
      (total, order) => total + _number(order['total_amount']),
    );
    final pendingAmount = periodOrders
        .where((order) => !_isPaid(order))
        .fold<double>(
          0,
          (total, order) => total + _number(order['total_amount']),
        );
    final productsSold = paidOrders.fold<int>(
      0,
      (total, order) => total + _quantity(order),
    );
    final monthlyRevenue = _monthlyRevenue();
    final peakMonth = monthlyRevenue.isEmpty
        ? null
        : monthlyRevenue.reduce((a, b) => a.revenue >= b.revenue ? a : b);
    final paymentSuccessRate = periodOrders.isEmpty
        ? 0.0
        : paidOrders.length / periodOrders.length * 100;
    final recentOrders = periodOrders.take(5).toList();

    if (_isLoading && !_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && !_hasLoaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE46C45),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'PAWSTAY PARTNER',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFFE46C45),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Revenue & Analytics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh analytics',
                onPressed: _isLoading ? null : _loadOrders,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              PopupMenuButton<int>(
                initialValue: _selectedMonths,
                onSelected: (months) =>
                    setState(() => _selectedMonths = months),
                itemBuilder: (context) => _periodOptions.entries
                    .map(
                      (entry) => PopupMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Color(0xFFE46C45),
                      ),
                      const SizedBox(width: 9),
                      Text(_periodOptions[_selectedMonths]!),
                      const SizedBox(width: 7),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF9F2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFB8EBD5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: Color(0xFF00A878)),
                    SizedBox(width: 6),
                    Text(
                      'Live order data',
                      style: TextStyle(color: Color(0xFF006B4F), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBanner(context, _error!),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _MetricCard(
                    width: cardWidth,
                    title: 'Payments received',
                    value: '${paidOrders.length}',
                    detail: 'Paid orders',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFFB54323),
                    tint: const Color(0xFFFFF0E9),
                  ),
                  _MetricCard(
                    width: cardWidth,
                    title: 'Amount received',
                    value: _currency(paidAmount),
                    detail: pendingAmount > 0
                        ? '${_currency(pendingAmount)} pending'
                        : 'All payments confirmed',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF008C7C),
                    tint: const Color(0xFFE5F7F4),
                  ),
                  _MetricCard(
                    width: cardWidth,
                    title: 'Total orders',
                    value: '${periodOrders.length}',
                    detail: '${paidOrders.length} paid',
                    icon: Icons.shopping_bag_outlined,
                    color: const Color(0xFF21823B),
                    tint: const Color(0xFFEAF7EB),
                  ),
                  _MetricCard(
                    width: cardWidth,
                    title: 'Average order value',
                    value: _currency(
                      paidOrders.isEmpty ? 0 : paidAmount / paidOrders.length,
                    ),
                    detail: 'Based on paid orders',
                    icon: Icons.trending_up,
                    color: const Color(0xFF6B35A8),
                    tint: const Color(0xFFF3EAF9),
                  ),
                  _MetricCard(
                    width: cardWidth,
                    title: 'Products & services sold',
                    value: '$productsSold',
                    detail: 'Items in paid orders',
                    icon: Icons.category_outlined,
                    color: const Color(0xFFE87500),
                    tint: const Color(0xFFFFF3E2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _RevenueCard(
            monthlyRevenue: monthlyRevenue,
            totalRevenue: paidAmount,
            peakMonth: peakMonth,
            successRate: paymentSuccessRate,
          ),
          const SizedBox(height: 16),
          _TransactionsCard(
            orders: recentOrders,
            totalCount: periodOrders.length,
            onViewAll: () => _showStatement(periodOrders),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _ordersForPeriod() {
    final end = DateTime.now();
    final start = DateTime(end.year, end.month - _selectedMonths + 1);
    final orders = _orders.where((order) {
      final createdAt = _createdAt(order);
      return createdAt != null &&
          !createdAt.isBefore(start) &&
          !createdAt.isAfter(end);
    }).toList();
    orders.sort((a, b) {
      final aDate = _createdAt(a);
      final bDate = _createdAt(b);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return orders;
  }

  List<_RevenuePoint> _monthlyRevenue() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month - _selectedMonths + 1);
    final points = List<_RevenuePoint>.generate(
      _selectedMonths,
      (index) => _RevenuePoint(
        date: DateTime(start.year, start.month + index),
        revenue: 0,
      ),
    );
    for (final order in _orders) {
      if (!_isPaid(order)) continue;
      final createdAt = _createdAt(order);
      if (createdAt == null) continue;
      final monthIndex =
          (createdAt.year - start.year) * 12 + createdAt.month - start.month;
      if (monthIndex >= 0 && monthIndex < points.length) {
        points[monthIndex] = _RevenuePoint(
          date: points[monthIndex].date,
          revenue: points[monthIndex].revenue + _number(order['total_amount']),
        );
      }
    }
    return points;
  }

  bool _isPaid(Map<String, dynamic> order) =>
      order['payment_status']?.toString().toLowerCase() == 'paid';

  DateTime? _createdAt(Map<String, dynamic> order) {
    final raw = order['created_at']?.toString();
    return raw == null ? null : _parseOrderDate(raw);
  }

  int _quantity(Map<String, dynamic> order) {
    final quantity = _number(order['quantity']).toInt();
    return quantity > 0 ? quantity : 1;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _currency(num amount) => _formatCurrency(amount);

  void _showStatement(List<Map<String, dynamic>> orders) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction statement',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_periodOptions[_selectedMonths]} · ${orders.length} orders',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: orders.isEmpty
                    ? const Center(child: Text('No orders in this date range.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) =>
                            _TransactionRow(order: orders[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          TextButton(onPressed: _loadOrders, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final Color tint;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenuePoint {
  final DateTime date;
  final double revenue;

  const _RevenuePoint({required this.date, required this.revenue});
}

class _RevenueCard extends StatelessWidget {
  final List<_RevenuePoint> monthlyRevenue;
  final double totalRevenue;
  final _RevenuePoint? peakMonth;
  final double successRate;

  const _RevenueCard({
    required this.monthlyRevenue,
    required this.totalRevenue,
    required this.peakMonth,
    required this.successRate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payments received',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Monthly payout breakdown in ₹',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Total: ${_compactCurrency(totalRevenue)}',
                  style: const TextStyle(
                    color: Color(0xFFCA5738),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 205, child: _RevenueChart(points: monthlyRevenue)),
          if (monthlyRevenue.every((point) => point.revenue == 0)) ...[
            const SizedBox(height: 6),
            Text(
              'No paid orders in this period yet.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peak month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      peakMonth == null || peakMonth!.revenue == 0
                          ? 'No paid orders'
                          : '${_monthLabel(peakMonth!.date)} (${_compactCurrency(peakMonth!.revenue)})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Payment success',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${successRate.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF008C5A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<_RevenuePoint> points;

  const _RevenueChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = math.max(constraints.maxWidth, points.length * 48.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: constraints.maxHeight,
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(painter: _RevenueChartPainter(points)),
                ),
                SizedBox(
                  height: 24,
                  child: Row(
                    children: List.generate(points.length, (index) {
                      final point = points[index];
                      final isPeak =
                          point.revenue > 0 &&
                          point.revenue ==
                              points.fold<double>(
                                0,
                                (maximum, item) =>
                                    math.max(maximum, item.revenue),
                              );
                      return Expanded(
                        child: Text(
                          _monthLabel(point.date),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isPeak
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontWeight: isPeak
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  final List<_RevenuePoint> points;

  const _RevenueChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;

    final maxRevenue = points.fold<double>(
      0,
      (maximum, point) => math.max(maximum, point.revenue),
    );
    const axisWidth = 48.0;
    const chartTop = 12.0;
    const bottomPadding = 8.0;
    final baseline = size.height - bottomPadding;
    final chartHeight = baseline - chartTop;
    final chartWidth = size.width - axisWidth;
    final scaleMaximum = maxRevenue > 0 ? maxRevenue : 1.0;
    final textStyle = const TextStyle(color: Color(0xFF77716E), fontSize: 10);
    final gridPaint = Paint()
      ..color = const Color(0xFFF0E6E0)
      ..strokeWidth = 1;
    for (var line = 0; line <= 2; line++) {
      final y = chartTop + chartHeight * line / 2;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
      final amount = maxRevenue * (1 - line / 2);
      final label = TextPainter(
        text: TextSpan(text: _compactCurrency(amount), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 4);
      label.paint(canvas, Offset(axisWidth - label.width - 6, y - 6));
    }
    final barsPaint = Paint()
      ..color = const Color(0xFFE77854)
      ..strokeCap = StrokeCap.round;
    final highlightPaint = Paint()
      ..color = const Color(0xFFB94A2C)
      ..strokeCap = StrokeCap.round;
    final slotWidth = chartWidth / points.length;
    final barWidth = math.min(22.0, slotWidth * .58);
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final barHeight = maxRevenue == 0
          ? 3.0
          : math.max(3.0, chartHeight * point.revenue / scaleMaximum);
      final x = axisWidth + slotWidth * (index + .5);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - barWidth / 2,
          baseline - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        point.revenue == maxRevenue && maxRevenue > 0
            ? highlightPaint
            : barsPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _TransactionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final int totalCount;
  final VoidCallback onViewAll;

  const _TransactionsCard({
    required this.orders,
    required this.totalCount,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RECENT TRANSACTIONS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: .5,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text('View statement ($totalCount)'),
              ),
            ],
          ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Text(
                'No orders found in this date range.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            ...orders.map(
              (order) => _TransactionRow(order: order, divider: true),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool divider;

  const _TransactionRow({required this.order, this.divider = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final amount = _parseNumber(order['total_amount']);
    final paid = order['payment_status']?.toString().toLowerCase() == 'paid';
    final customer = order['customer_name']?.toString().trim();
    final petName = order['pet_name']?.toString().trim();
    final orderCode = order['order_code']?.toString();
    final rawDate = order['created_at']?.toString();
    final date = rawDate == null ? null : _parseOrderDate(rawDate);
    final subtitle = [
      if (customer != null && customer.isNotEmpty) 'Client: $customer',
      if (petName != null && petName.isNotEmpty) 'Pet: $petName',
      if (date != null) _dateTimeLabel(date),
    ].join(' • ');
    final title = petName != null && petName.isNotEmpty
        ? petName
        : (orderCode?.isNotEmpty == true ? orderCode! : 'Seller order');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: paid
                      ? const Color(0xFFE8F9F2)
                      : const Color(0xFFFFF2E6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pets_outlined,
                  size: 19,
                  color: paid
                      ? const Color(0xFF148B68)
                      : const Color(0xFFE87500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(amount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: paid
                          ? const Color(0xFFE8F9F2)
                          : const Color(0xFFFFF3E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order['payment_status']?.toString() ?? 'Pending',
                      style: TextStyle(
                        color: paid
                            ? const Color(0xFF008C5A)
                            : const Color(0xFFAE6100),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (divider) const Divider(height: 1),
      ],
    );
  }
}

double _parseNumber(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatCurrency(num amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final integer = parts.first;
  final lastThreeDigits = integer.length > 3
      ? integer.substring(integer.length - 3)
      : integer;
  final prefix = integer.length > 3
      ? integer.substring(0, integer.length - 3)
      : '';
  final groups = <String>[];
  for (var end = prefix.length; end > 0; end -= 2) {
    final start = math.max(0, end - 2);
    groups.insert(0, prefix.substring(start, end));
  }
  groups.add(lastThreeDigits);
  return '₹${groups.join(',')}.${parts.last}';
}

String _compactCurrency(num amount) {
  if (amount >= 10000000) {
    return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
  }
  if (amount >= 100000) {
    return '₹${(amount / 100000).toStringAsFixed(1)}L';
  }
  if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}k';
  return '₹${amount.toStringAsFixed(0)}';
}

String _monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[date.month - 1];
}

String _dateTimeLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

DateTime? _parseOrderDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final hasTimezone = RegExp(
    r'(?:Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(value);
  if (hasTimezone) return parsed.toLocal();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toLocal();
}
