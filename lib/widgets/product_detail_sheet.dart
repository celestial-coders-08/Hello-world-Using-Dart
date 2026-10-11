import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/marketplace_cart.dart';
import '../services/seller_api_service.dart';
import '../theme/pawstay_theme.dart';
import 'razorpay_checkout_sheet.dart';

class ProductDetailSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final String? userLookup;
  final bool showBuyButton;

  const ProductDetailSheet({
    super.key,
    required this.product,
    this.userLookup,
    this.showBuyButton = true,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> product, {
    String? userLookup,
    bool showBuyButton = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductDetailSheet(
        product: product,
        userLookup: userLookup,
        showBuyButton: showBuyButton,
      ),
    );
  }

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _selectedImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getImageUrls() {
    final rawUrls = widget.product['image_urls'];
    if (rawUrls is List && rawUrls.isNotEmpty) {
      return rawUrls
          .map((e) => SellerApiService.mediaUrl(e.toString()))
          .toList();
    }
    final singleUrl = widget.product['image_url']?.toString();
    if (singleUrl != null && singleUrl.isNotEmpty) {
      return [SellerApiService.mediaUrl(singleUrl)];
    }
    return [];
  }

  double _getNumeric(dynamic val, double fallback) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '') ?? fallback;
  }

  void _onBuyNowPressed() {
    final productId = int.tryParse(widget.product['id']?.toString() ?? '');
    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This listing cannot be purchased.')),
      );
      return;
    }
    final price = _getNumeric(widget.product['price'], 0.0);
    final title = widget.product['name']?.toString() ?? 'PawStay Listing';

    RazorpayCheckoutSheet.show(
      context: context,
      productId: productId,
      amount: price,
      productTitle: title,
      onPaymentSuccess: (paymentResult) {
        _showOrderConfirmedDialog(paymentResult);
      },
    );
  }

  void _showOrderConfirmedDialog(Map<String, dynamic> result) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Successful!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: PawStayTheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PawStay Order ${result['order_code'] ?? ''}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: PawStayTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PawStayTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Item:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12),
                        ),
                        Expanded(
                          child: Text(
                            widget.product['name']?.toString() ?? '',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment ID:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12),
                        ),
                        Text(
                          result['razorpay_payment_id']?.toString() ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12),
                        ),
                        Text(
                          '₹${_getNumeric(result['amount'], _getNumeric(widget.product['price'], 0.0)).toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Track payment confirmation and order progress in Your Orders.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: PawStayTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.pop(context);
                  },
                  child: const Text('Back to Marketplace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _getImageUrls();
    final price = _getNumeric(widget.product['price'], 0.0);
    final mrp = _getNumeric(widget.product['mrp'], price);
    final discount = mrp > price ? (((mrp - price) / mrp) * 100).round() : 0;
    final brand = widget.product['brand']?.toString().trim();
    final name = widget.product['name']?.toString() ?? 'Listing Details';
    final description = widget.product['description']?.toString() ?? '';
    final stock = MarketplaceCartItem.parseStock(
      widget.product['stock_quantity'] ??
          widget.product['stock'] ??
          (widget.product['in_stock'] == true ? 1 : 0),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Gallery Slider
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: const Color(0xFFF8FAFC),
                    child: images.isNotEmpty
                        ? Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: images.length,
                                onPageChanged: (idx) {
                                  setState(() => _selectedImageIndex = idx);
                                },
                                itemBuilder: (context, idx) {
                                  return Image.network(
                                    images[idx],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                          child: Icon(
                                            Icons.pets,
                                            size: 64,
                                            color: PawStayTheme.primary
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                  );
                                },
                              ),
                              if (images.length > 1)
                                Positioned(
                                  bottom: 12,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      images.length,
                                      (idx) => AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        width: _selectedImageIndex == idx
                                            ? 18
                                            : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _selectedImageIndex == idx
                                              ? PawStayTheme.primary
                                              : Colors.grey.shade400,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              size: 72,
                              color: PawStayTheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                  ),

                  // Content details
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brand != null && brand.isNotEmpty) ...[
                          Text(
                            brand.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD85F3D),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSurface,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              color: PawStayTheme.primary,
                              size: 17,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.product['seller_lookup']?.toString() ??
                                  'PawStay seller',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PawStayTheme.onSurfaceVariant,
                              ),
                            ),
                            if (widget.showBuyButton) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: stock > 0
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  stock > 0
                                      ? 'Stock available ($stock)'
                                      : 'Out of stock',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: stock > 0
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const Divider(height: 28),

                        // Price & Discount
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${price.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: PawStayTheme.onSurface,
                              ),
                            ),
                            if (mrp > price) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${mrp.toStringAsFixed(0)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  color: PawStayTheme.onSurfaceVariant,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD85F3D,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$discount% OFF',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD85F3D),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Product Description
                        Text(
                          'Product Overview',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description.isNotEmpty
                              ? description
                              : 'The seller has not added a description.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: PawStayTheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar with Buy Now (only for customers/providers, hidden for sellers)
          if (widget.showBuyButton)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: stock > 0 ? _onBuyNowPressed : null,
                        icon: const Icon(
                          Icons.flash_on_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          stock > 0
                              ? 'Buy Now • ₹${price.toStringAsFixed(0)}'
                              : 'Out of stock',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD85F3D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
