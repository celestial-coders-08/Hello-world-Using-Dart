import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/marketplace_cart.dart';
import '../../services/payment_api_service.dart';
import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/razorpay_checkout_sheet.dart';

class UserAddCartScreen extends StatelessWidget {
  const UserAddCartScreen({super.key});

  @override
  Widget build(BuildContext context) => const MarketplaceCartScreen();
}

class MarketplaceCartScreen extends StatefulWidget {
  const MarketplaceCartScreen({super.key});

  @override
  State<MarketplaceCartScreen> createState() => _MarketplaceCartScreenState();
}

class _MarketplaceCartScreenState extends State<MarketplaceCartScreen> {
  final MarketplaceCart _cart = MarketplaceCart.instance;
  bool _isCheckingOut = false;

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _isCheckingOut) return;
    setState(() => _isCheckingOut = true);
    try {
      final latestProducts = await PaymentApiService.fetchMarketplaceProducts();
      if (!mounted) return;
      _cart.refreshProducts(latestProducts);
      final stockIssue = _cart.stockIssue;
      if (stockIssue != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$stockIssue Update your cart to continue.')),
        );
        return;
      }

      final items = _cart.items
          .map(
            (item) => {
              'product_id': item.productId,
              'quantity': item.quantity,
            },
          )
          .toList();
      final title = _cart.itemCount == 1
          ? _cart.items.first.product['name']?.toString() ?? 'Marketplace item'
          : '${_cart.itemCount} items in your cart';

      await RazorpayCheckoutSheet.show(
        context: context,
        cartItems: items,
        amount: _cart.subtotal,
        productTitle: title,
        onPaymentSuccess: (result) {
          _cart.clear();
          if (mounted) _showOrderConfirmedDialog(result);
        },
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  void _showOrderConfirmedDialog(Map<String, dynamic> result) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF2E7D32),
          size: 48,
        ),
        title: const Text('Payment successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PawStay Order ${result['order_code'] ?? ''}'),
            const SizedBox(height: 8),
            Text(
              '₹${_number(result['amount']).toStringAsFixed(2)} paid for your cart.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('You can track the order in Your Orders.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continue shopping'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        title: Text(
          'Your Cart',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBuilder(
        animation: _cart,
        builder: (context, _) {
          if (_cart.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                      color: Color(0xFFD85F3D),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Add products from the shop to get started.'),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _cart.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _CartItemCard(
              item: _cart.items[index],
              onDecrease: () => _cart.decrement(_cart.items[index].productId),
              onIncrease: () {
                if (!_cart.increment(_cart.items[index].productId)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You have reached the available stock.'),
                    ),
                  );
                }
              },
              onRemove: () => _cart.remove(_cart.items[index].productId),
            ),
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _cart,
        builder: (context, _) {
          if (_cart.isEmpty) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: PawStayTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_cart.itemCount} items',
                        style: GoogleFonts.plusJakartaSans(
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${_cart.subtotal.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isCheckingOut ? null : _checkout,
                      icon: _isCheckingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_rounded),
                      label: Text(
                        _isCheckingOut ? 'Preparing payment...' : 'Pay securely',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD85F3D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final MarketplaceCartItem item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.product['image_url']?.toString();
    final name = item.product['name']?.toString() ?? 'Marketplace item';

    return Card(
      color: PawStayTheme.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: imageUrl == null || imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF8FAFC),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFFD85F3D),
                        ),
                      )
                    : Image.network(
                        SellerApiService.mediaUrl(imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFFF8FAFC),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: Color(0xFFD85F3D),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '₹${item.unitPrice.toStringAsFixed(2)} each',
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '₹${item.totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.availableStock == 0
                        ? 'Out of stock'
                        : item.availableStock < item.quantity
                        ? 'Only ${item.availableStock} left'
                        : 'In stock (${item.availableStock})',
                    style: GoogleFonts.plusJakartaSans(
                      color: item.availableStock < item.quantity
                          ? const Color(0xFFC62828)
                          : const Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Remove $name',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QuantityButton(
                      icon: Icons.remove_rounded,
                      onPressed: onDecrease,
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add_rounded,
                      onPressed: item.quantity >= item.availableStock
                          ? null
                          : onIncrease,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}