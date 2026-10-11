import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/payment_api_service.dart';
import '../../theme/pawstay_theme.dart';

class YourOrdersScreen extends StatefulWidget {
  const YourOrdersScreen({super.key});

  @override
  State<YourOrdersScreen> createState() => _YourOrdersScreenState();
}

class _YourOrdersScreenState extends State<YourOrdersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

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
      final orders = await PaymentApiService.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
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
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        title: Text(
          'Your Orders',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _isLoading ? null : _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _message(_error!, action: 'Try again', onPressed: _loadOrders)
          : _orders.isEmpty
          ? _message('You have not placed any orders yet.')
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _orderCard(_orders[index]),
              ),
            ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final orderCode = order['order_code']?.toString() ?? 'Order';
    final productName = order['product_name']?.toString() ?? 'Marketplace item';
    final paymentStatus =
        order['payment_status']?.toString() ?? 'Pending';
    final orderStatus = order['order_status']?.toString() ?? 'Pending';
    final paymentId = order['payment_id']?.toString();
    final amount = order['total_amount'] is num
        ? (order['total_amount'] as num).toDouble()
        : double.tryParse(order['total_amount']?.toString() ?? '') ?? 0;

    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: PawStayTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              orderCode,
              style: GoogleFonts.plusJakartaSans(
                color: PawStayTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip('Payment: $paymentStatus', paymentStatus == 'Paid'),
                _statusChip('Order: $orderStatus', orderStatus == 'Delivered'),
              ],
            ),
            if (paymentId != null && paymentId.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                'Payment ID: $paymentId',
                style: GoogleFonts.plusJakartaSans(
                  color: PawStayTheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Seller: ${order['seller_lookup'] ?? 'PawStay seller'}',
              style: GoogleFonts.plusJakartaSans(
                color: PawStayTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, bool complete) {
    final color = complete ? const Color(0xFF15803D) : const Color(0xFFB45309);
    return Chip(
      avatar: Icon(
        complete ? Icons.check_circle_outline : Icons.schedule_rounded,
        size: 16,
        color: color,
      ),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontSize: 12),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _message(
    String message, {
    String? action,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
            if (action != null && onPressed != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
