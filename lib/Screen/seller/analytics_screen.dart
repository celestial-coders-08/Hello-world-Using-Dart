import 'package:flutter/material.dart';

import '../../services/seller_api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final String sellerLookup;

  const AnalyticsScreen({super.key, required this.sellerLookup});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _analytics = const {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dailyRevenue =
        _analytics['revenue_by_day'] as List<dynamic>? ?? const [];
    final ordersByStatus =
        _analytics['orders_by_status'] as Map<String, dynamic>? ?? const {};
    final maxRevenue = dailyRevenue.fold<double>(
      0,
      (maximum, entry) =>
          ((entry as Map<String, dynamic>)['revenue'] as num? ?? 0) >
              maximum
          ? ((entry)['revenue'] as num).toDouble()
          : maximum,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seller Sales & Performance',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payments count only when an order is explicitly marked Paid.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh analytics',
                onPressed: _isLoading ? null : _loadAnalytics,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadAnalytics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 900
                            ? (constraints.maxWidth - 36) / 4
                            : constraints.maxWidth >= 600
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _metric(
                              context,
                              'Payments received',
                              '${_analytics['payments_received_count'] ?? 0}',
                              Icons.payments_outlined,
                              colors.primary,
                              width,
                            ),
                            _metric(
                              context,
                              'Amount received',
                              _currency(
                                _analytics['payments_received'] as num? ?? 0,
                              ),
                              Icons.account_balance_wallet_outlined,
                              Colors.teal,
                              width,
                            ),
                            _metric(
                              context,
                              'Total orders',
                              '${_analytics['total_orders'] ?? 0}',
                              Icons.shopping_bag_outlined,
                              Colors.green,
                              width,
                            ),
                            _metric(
                              context,
                              'Average order value',
                              _currency(
                                _analytics['average_order_value'] as num? ?? 0,
                              ),
                              Icons.show_chart,
                              Colors.deepPurple,
                              width,
                            ),
                            _metric(
                              context,
                              'Products sold',
                              '${_analytics['products_sold'] ?? 0}',
                              Icons.category_outlined,
                              Colors.orange,
                              width,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payments received over the last 7 days',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 18),
                            if (dailyRevenue.isEmpty)
                              const Text(
                                'No paid orders have been recorded yet.',
                              )
                            else
                              ...dailyRevenue.map((rawEntry) {
                                final entry =
                                    rawEntry as Map<String, dynamic>;
                                final revenue =
                                    (entry['revenue'] as num? ?? 0).toDouble();
                                final fraction = maxRevenue == 0
                                    ? 0.0
                                    : revenue / maxRevenue;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 96,
                                        child: Text(
                                          _dateLabel(
                                            entry['date']?.toString() ?? '',
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: fraction,
                                          minHeight: 12,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          backgroundColor:
                                              colors.surfaceContainerHighest,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          _currency(revenue),
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
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Orders by status',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            if (ordersByStatus.isEmpty)
                              const Text('No orders have been received yet.')
                            else
                              ...ordersByStatus.entries.map(
                                (entry) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.key),
                                  trailing: Text(
                                    '${entry.value}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
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
                    Text(title, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
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

  String _currency(num amount) => '₹${amount.toStringAsFixed(2)}';

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
}
