import 'package:flutter/material.dart';

import '../../services/seller_api_service.dart';

class SellerOrdersScreen extends StatefulWidget {
  final String sellerLookup;
  final VoidCallback onOrdersChanged;

  const SellerOrdersScreen({
    super.key,
    required this.sellerLookup,
    required this.onOrdersChanged,
  });

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  static const _tabs = [
    'All',
    'Pending',
    'Confirmed',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  String _selectedTab = 'All';
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  int? _updatingOrderId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
        _isLoading = false;
      });
      widget.onOrdersChanged();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(int orderId, String status) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await SellerApiService.updateOrderStatus(
        sellerLookup: widget.sellerLookup,
        orderId: orderId,
        status: status,
      );
      await _loadOrders();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filteredOrders = _selectedTab == 'All'
        ? _orders
        : _orders
              .where(
                (order) =>
                    order['order_status']?.toString().toLowerCase() ==
                    _selectedTab.toLowerCase(),
              )
              .toList();

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
                      'Seller Orders',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review purchases and update fulfillment progress.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh orders',
                onPressed: _isLoading ? null : _loadOrders,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tabs.map((tab) {
                final selected = _selectedTab == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tab),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedTab = tab),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _emptyState(
                    _error!,
                    action: FilledButton.icon(
                      onPressed: _loadOrders,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  )
                : filteredOrders.isEmpty
                ? _emptyState('No orders found for this status.')
                : ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final status =
                          order['order_status']?.toString() ?? 'Pending';
                      final orderId = order['id'] as int;
                      final isUpdating = _updatingOrderId == orderId;
                      final paymentStatus =
                          order['payment_status']?.toString() ?? 'Pending';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      order['order_code']?.toString() ??
                                          'Order #$orderId',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _currency(order['total_amount'] as num? ?? 0),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: colors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Payment'),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(paymentStatus),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 18,
                                runSpacing: 6,
                                children: [
                                  _detail(
                                    context,
                                    Icons.person_outline,
                                    'Customer',
                                    order['customer_name']?.toString() ??
                                        'Customer',
                                  ),
                                  _detail(
                                    context,
                                    Icons.pets,
                                    'Pet',
                                    _petLabel(order),
                                  ),
                                  _detail(
                                    context,
                                    Icons.shopping_bag_outlined,
                                    'Quantity',
                                    '${order['quantity'] ?? 1}',
                                  ),
                                ],
                              ),
                              if ((order['shipping_address']?.toString() ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _detail(
                                  context,
                                  Icons.location_on_outlined,
                                  'Shipping address',
                                  order['shipping_address'].toString(),
                                ),
                              ],
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Text('Status'),
                                  const SizedBox(width: 10),
                                  Chip(
                                    label: Text(status),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const Spacer(),
                                  if (isUpdating)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    DropdownButton<String>(
                                      value: _tabs.skip(1).contains(status)
                                          ? status
                                          : _tabs[1],
                                      items: _tabs
                                          .skip(1)
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null && value != status) {
                                          _updateStatus(orderId, value);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text('$label: ', style: Theme.of(context).textTheme.labelMedium),
        Flexible(child: Text(value)),
      ],
    );
  }

  Widget _emptyState(String message, {Widget? action}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }

  String _petLabel(Map<String, dynamic> order) {
    final name = order['pet_name']?.toString() ?? '';
    final breed = order['pet_breed']?.toString() ?? '';
    if (name.isEmpty && breed.isEmpty) return '—';
    if (breed.isEmpty) return name;
    return '$name ($breed)';
  }

  String _currency(num amount) => '₹${amount.toStringAsFixed(2)}';
}
