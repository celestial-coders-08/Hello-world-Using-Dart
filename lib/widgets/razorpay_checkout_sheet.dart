import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/payment_api_service.dart';

class RazorpayCheckoutSheet extends StatefulWidget {
  final int? productId;
  final List<Map<String, int>>? cartItems;
  final double amount;
  final String productTitle;
  final void Function(Map<String, dynamic> paymentResult) onPaymentSuccess;

  const RazorpayCheckoutSheet({
    super.key,
    this.productId,
    this.cartItems,
    required this.amount,
    required this.productTitle,
    required this.onPaymentSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    int? productId,
    List<Map<String, int>>? cartItems,
    required double amount,
    required String productTitle,
    required void Function(Map<String, dynamic> paymentResult) onPaymentSuccess,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RazorpayCheckoutSheet(
        productId: productId,
        cartItems: cartItems,
        amount: amount,
        productTitle: productTitle,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<RazorpayCheckoutSheet> createState() => _RazorpayCheckoutSheetState();
}

class _RazorpayCheckoutSheetState extends State<RazorpayCheckoutSheet> {
  final _addressFormKey = GlobalKey<FormState>();
  final _apartmentFlatController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  WebViewController? _webViewController;
  Map<String, dynamic>? _checkoutOrder;
  Map<String, dynamic>? _buyerAddress;
  Map<String, dynamic>? _pendingPayment;
  String? _error;
  bool _isLoading = true;
  bool _isLoadingAddress = true;
  bool _isSavingAddress = false;
  bool _isEditingAddress = false;
  bool _addressConfirmed = false;
  bool _isVerifying = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadBuyerAddress();
  }

  @override
  void dispose() {
    _apartmentFlatController.dispose();
    _streetAddressController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadBuyerAddress() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      setState(() {
        _error =
            'Secure Razorpay checkout is currently supported on Android and iOS.';
        _isLoading = false;
        _isLoadingAddress = false;
      });
      return;
    }

    setState(() {
      _error = null;
      _isLoadingAddress = true;
    });
    try {
      final address = await PaymentApiService.fetchBuyerAddress();
      if (!mounted) return;
      _buyerAddress = address;
      if (address == null) {
        _isEditingAddress = true;
      } else {
        _setAddressFields(address);
      }
      setState(() {
        _isLoadingAddress = false;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoadingAddress = false;
        _isLoading = false;
      });
    }
  }

  void _setAddressFields(Map<String, dynamic> address) {
    _apartmentFlatController.text = address['apartment_flat']?.toString() ?? '';
    _streetAddressController.text = address['street_address']?.toString() ?? '';
    _stateController.text = address['state']?.toString() ?? '';
    _cityController.text = address['city']?.toString() ?? '';
    _postalCodeController.text = address['postal_code']?.toString() ?? '';
  }

  Future<void> _saveAddressAndContinue() async {
    if (_isSavingAddress ||
        !(_addressFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSavingAddress = true;
      _error = null;
    });
    try {
      final address = await PaymentApiService.saveBuyerAddress(
        apartmentFlat: _apartmentFlatController.text.trim(),
        streetAddress: _streetAddressController.text.trim(),
        state: _stateController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _buyerAddress = address;
        _isSavingAddress = false;
        _isEditingAddress = false;
        _addressConfirmed = true;
        _isLoading = true;
      });
      await _prepareCheckout();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isSavingAddress = false;
      });
    }
  }

  Future<void> _prepareCheckout() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      setState(() {
        _error =
            'Secure Razorpay checkout is currently supported on Android and iOS.';
        _isLoading = false;
      });
      return;
    }

    try {
      final cartItems = widget.cartItems;
      final productId = widget.productId;
      if ((cartItems == null) == (productId == null)) {
        if (mounted) {
          setState(() {
            _error = 'Select a product or cart before starting checkout.';
            _isLoading = false;
          });
        }
        return;
      }
      if (!_addressConfirmed) return;
      final order = cartItems != null
          ? await PaymentApiService.createCartCheckoutOrder(cartItems)
          : await PaymentApiService.createCheckoutOrder(productId!);
      if (!mounted) return;
      _checkoutOrder = order;
      _initializeWebView(order);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _initializeWebView(Map<String, dynamic> order) {
    final amountPaise = int.tryParse(order['amount_paise']?.toString() ?? '');
    final orderId = order['razorpay_order_id']?.toString();
    final keyId = order['key_id']?.toString();
    if (amountPaise == null ||
        orderId == null ||
        keyId == null ||
        orderId.isEmpty ||
        keyId.isEmpty) {
      setState(() {
        _error = 'The payment service returned an incomplete checkout order.';
        _isLoading = false;
      });
      return;
    }

    final title = widget.productTitle;
    final customerName = order['customer_name']?.toString() ?? '';
    final customerEmail = order['customer_email']?.toString() ?? '';
    final customerPhone = order['customer_phone']?.toString() ?? '';
    final htmlTitle = const HtmlEscape().convert(title);
    final safeTitle = jsonEncode(title);
    final html =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
  <style>
    body { background:#0f172a; color:#fff; font-family:Arial,sans-serif; margin:0;
      padding:24px; display:flex; align-items:center; justify-content:center;
      min-height:100vh; box-sizing:border-box; }
    .card { width:100%; max-width:360px; padding:24px; text-align:center;
      background:#1e293b; border:1px solid #334155; border-radius:16px; }
    .title { color:#cbd5e1; font-size:14px; }
    .product { margin-top:8px; font-weight:700; line-height:1.4; }
    .amount { margin:18px 0; color:#22c55e; font-size:30px; font-weight:800; }
    button { width:100%; padding:14px; border:0; border-radius:12px;
      background:#d85f3d; color:white; font-size:16px; font-weight:700; }
    .hint { margin-top:14px; color:#94a3b8; font-size:12px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="title">Secure payment for</div>
    <div class="product">$htmlTitle</div>
    <div class="amount">₹${(amountPaise / 100).toStringAsFixed(2)}</div>
    <button id="pay-btn">Pay securely with Razorpay</button>
    <div class="hint">Your order is linked to your PawStay account.</div>
  </div>
  <script>
    const options = {
      key: ${jsonEncode(keyId)},
      order_id: ${jsonEncode(orderId)},
      amount: $amountPaise,
      currency: "INR",
      name: "PawStay Marketplace",
      description: $safeTitle,
      prefill: {
        name: ${jsonEncode(customerName)},
        email: ${jsonEncode(customerEmail)},
        contact: ${jsonEncode(customerPhone)}
      },
      theme: { color: "#D85F3D" },
      handler: function(response) {
        window.PawStay.postMessage(JSON.stringify({
          type: "success",
          razorpay_order_id: response.razorpay_order_id,
          razorpay_payment_id: response.razorpay_payment_id,
          razorpay_signature: response.razorpay_signature
        }));
      },
      modal: {
        ondismiss: function() {
          window.PawStay.postMessage(JSON.stringify({type: "dismissed"}));
        }
      }
    };
    if (typeof Razorpay === "undefined") {
      window.PawStay.postMessage(JSON.stringify({
        type: "error",
        message: "Razorpay checkout could not be loaded. Check your connection."
      }));
    } else {
      const checkout = new Razorpay(options);
      checkout.on("payment.failed", function(response) {
        window.PawStay.postMessage(JSON.stringify({
          type: "error",
          message: response.error && response.error.description
            ? response.error.description : "Razorpay could not complete the payment."
        }));
      });
      document.getElementById("pay-btn").onclick = function(event) {
        event.preventDefault();
        checkout.open();
      };
      window.onload = function() {
        setTimeout(function() { checkout.open(); }, 300);
      };
    }
  </script>
</body>
</html>
''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..addJavaScriptChannel(
        'PawStay',
        onMessageReceived: (message) => _handleCheckoutMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _error =
                    'Razorpay checkout could not be loaded. Check your connection and try again.';
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(html);

    setState(() {
      _webViewController = controller;
      _isLoading = true;
      _error = null;
    });
  }

  void _handleCheckoutMessage(String message) {
    final Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(message) as Map);
    } on FormatException {
      setState(
        () => _error = 'Razorpay returned an invalid checkout response.',
      );
      return;
    } on TypeError {
      setState(
        () => _error = 'Razorpay returned an invalid checkout response.',
      );
      return;
    }

    switch (data['type']) {
      case 'success':
        _pendingPayment = data;
        _verifyPayment();
      case 'dismissed':
        if (!_finished && mounted) Navigator.pop(context);
      case 'error':
        if (mounted) {
          setState(() {
            _error =
                data['message']?.toString() ??
                'Razorpay could not complete payment.';
            _isVerifying = false;
          });
        }
    }
  }

  Future<void> _verifyPayment() async {
    final payment = _pendingPayment;
    if (payment == null || _isVerifying || _finished) return;
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      final result = await PaymentApiService.verifyCheckoutPayment(
        razorpayOrderId: payment['razorpay_order_id']?.toString() ?? '',
        razorpayPaymentId: payment['razorpay_payment_id']?.toString() ?? '',
        razorpaySignature: payment['razorpay_signature']?.toString() ?? '',
      );
      if (!mounted) return;
      _finished = true;
      Navigator.pop(context);
      widget.onPaymentSuccess(result);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isVerifying = false;
      });
    }
  }

  Widget _addressField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color.fromARGB(179, 2, 2, 2)),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF475569)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFD85F3D)),
          ),
          errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _addressEditor() {
    return Form(
      key: _addressFormKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _buyerAddress == null ? 'Delivery address' : 'Edit address',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Save your delivery address before placing the order.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          _addressField('Apartment / Flat No.', _apartmentFlatController),
          _addressField('Street address', _streetAddressController),
          _addressField('City', _cityController),
          _addressField('State', _stateController),
          _addressField(
            'Postal code',
            _postalCodeController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isSavingAddress ? null : _saveAddressAndContinue,
            child: _isSavingAddress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save address & continue to payment'),
          ),
          if (_buyerAddress != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditingAddress = false;
                  _error = null;
                });
              },
              child: const Text(
                'Cancel editing',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _savedAddressPrompt() {
    final address = _buyerAddress!;
    final addressText = [
      address['apartment_flat'],
      address['street_address'],
      address['city'],
      address['state'],
      address['postal_code'],
    ].where((part) => part != null && part.toString().isNotEmpty).join(', ');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Deliver to your saved address?',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Text(addressText, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() {
                  _addressConfirmed = true;
                  _isLoading = true;
                  _error = null;
                });
                _prepareCheckout();
              },
              child: const Text('Use this address'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditingAddress = true;
                  _error = null;
                });
              },
              child: const Text(
                'Edit address',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _checkoutOrder?['amount_paise'] is num
        ? (_checkoutOrder!['amount_paise'] as num) / 100
        : widget.amount;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Color(0xFFD85F3D)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Razorpay Secure Payment',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFFCA5A5),
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                          if (_pendingPayment != null) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isVerifying ? null : _verifyPayment,
                              child: Text(
                                _isVerifying
                                    ? 'Confirming payment...'
                                    : 'Retry payment confirmation',
                              ),
                            ),
                          ] else if (_checkoutOrder == null) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isLoading
                                  ? null
                                  : _addressConfirmed
                                  ? _prepareCheckout
                                  : _loadBuyerAddress,
                              child: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : _isLoadingAddress
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD85F3D)),
                  )
                : !_addressConfirmed && _buyerAddress != null
                ? _savedAddressPrompt()
                : _isEditingAddress
                ? _addressEditor()
                : _webViewController == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFD85F3D),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Preparing ₹${amount.toStringAsFixed(2)} checkout...',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      WebViewWidget(controller: _webViewController!),
                      if (_isLoading || _isVerifying)
                        const ColoredBox(
                          color: Color(0x880F172A),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD85F3D),
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
