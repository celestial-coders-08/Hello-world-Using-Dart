import 'package:flutter/material.dart';

import '../../services/seller_api_service.dart';

class SellerOrderRequestScreen extends StatefulWidget {
  final String sellerLookup;
  final VoidCallback onOrdersChanged;

  const SellerOrderRequestScreen({
    super.key,
    required this.sellerLookup,
    required this.onOrdersChanged,
  });

  @override
  State<SellerOrderRequestScreen> createState() =>
      _SellerOrderRequestScreenState();
}

class _SellerOrderRequestScreenState extends State<SellerOrderRequestScreen> {
  static const _statuses = [
    'Pending',
    'Confirmed',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _isLoading ? null : _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _message(
              _error!,
              action: FilledButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            )
          : _orders.isEmpty
          ? _message('No order requests yet.')
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final orderId = _readOrderId(order['id']);
                  final orderCode = _value(
                    order['order_code'],
                    fallback: orderId == null ? 'Order' : 'Order #$orderId',
                  );
                  final customerName = _value(
                    order['customer_name'],
                    fallback: 'Customer',
                  );
                  final transactionId = _value(
                    order['razorpay_payment_id'],
                    fallback: 'Not available',
                  );
                  final shippingAddress = _value(
                    order['shipping_address'],
                    fallback: 'No delivery address recorded',
                  );
                  final status = _value(
                    order['order_status'],
                    fallback: 'Pending',
                  );
                  final paymentStatus = _value(
                    order['payment_status'],
                    fallback: 'Pending',
                  );
                  final isUpdating =
                      orderId != null && _updatingOrderId == orderId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  orderCode,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                _currency(order['total_amount']),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _detail(
                            context,
                            Icons.person_outline,
                            'Customer',
                            customerName,
                          ),
                          if (_value(order['customer_email']).isNotEmpty)
                            _detail(
                              context,
                              Icons.email_outlined,
                              'Email',
                              _value(order['customer_email']),
                            ),
                          if (_value(order['product_name']).isNotEmpty)
                            _detail(
                              context,
                              Icons.shopping_bag_outlined,
                              'Product',
                              _value(order['product_name']),
                            ),
                          _detail(
                            context,
                            Icons.payments_outlined,
                            'Payment',
                            paymentStatus,
                          ),
                          _detail(
                            context,
                            Icons.receipt_long_outlined,
                            'Transaction ID',
                            transactionId,
                            selectable: true,
                          ),
                          if (_value(order['razorpay_order_id']).isNotEmpty)
                            _detail(
                              context,
                              Icons.confirmation_number_outlined,
                              'Payment order ID',
                              _value(order['razorpay_order_id']),
                              selectable: true,
                            ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest.withValues(
                                alpha: 0.45,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Delivery address',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(shippingAddress),
                              ],
                            ),
                          ),
                          const Divider(height: 28),
                          Row(
                            children: [
                              const Text('Order status'),
                              const SizedBox(width: 8),
                              if (isUpdating)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else if (orderId != null)
                                Expanded(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _statuses.contains(status)
                                        ? status
                                        : _statuses.first,
                                    items: _statuses
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
                                )
                              else
                                Text(status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool selectable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(child: selectable ? SelectableText(value) : Text(value)),
        ],
      ),
    );
  }

  Widget _message(String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }

  int? _readOrderId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _value(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _currency(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }
}
