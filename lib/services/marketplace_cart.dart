import 'package:flutter/foundation.dart';

class MarketplaceCartItem {
  final Map<String, dynamic> product;
  final int quantity;

  const MarketplaceCartItem({required this.product, required this.quantity});

  static int parseStock(dynamic stock) {
    if (stock is num) return stock.floor();
    final value = stock?.toString() ?? '';
    return int.tryParse(value) ?? double.tryParse(value)?.floor() ?? 0;
  }

  int get productId => int.parse(product['id'].toString());

  double get unitPrice {
    final price = product['price'];
    if (price is num) return price.toDouble();
    return double.tryParse(price?.toString() ?? '') ?? 0;
  }

  int get availableStock {
    final stock = product['stock_quantity'] ?? product['stock'];
    return parseStock(stock);
  }

  double get totalPrice => unitPrice * quantity;
}

class MarketplaceCart extends ChangeNotifier {
  MarketplaceCart._();

  static final MarketplaceCart instance = MarketplaceCart._();

  final Map<int, MarketplaceCartItem> _items = {};

  List<MarketplaceCartItem> get items => List.unmodifiable(_items.values);
  int get itemCount => _items.values.fold(0, (total, item) => total + item.quantity);
  double get subtotal =>
      _items.values.fold(0, (total, item) => total + item.totalPrice);
  bool get isEmpty => _items.isEmpty;
  String? get stockIssue {
    for (final item in _items.values) {
      if (item.availableStock < item.quantity) {
        final name = item.product['name']?.toString() ?? 'A cart item';
        if (item.availableStock == 0) return '$name is out of stock.';
        return 'Only ${item.availableStock} of $name available.';
      }
    }
    return null;
  }

  int quantityFor(int productId) => _items[productId]?.quantity ?? 0;

  void refreshProducts(List<Map<String, dynamic>> products) {
    final byId = <int, Map<String, dynamic>>{};
    for (final product in products) {
      final id = int.tryParse(product['id']?.toString() ?? '');
      if (id != null) byId[id] = product;
    }

    for (final entry in _items.entries.toList()) {
      final latest = byId[entry.key];
      _items[entry.key] = MarketplaceCartItem(
        product: latest == null
            ? {...entry.value.product, 'stock_quantity': 0, 'in_stock': false}
            : Map<String, dynamic>.from(latest),
        quantity: entry.value.quantity,
      );
    }
    notifyListeners();
  }

  bool addProduct(Map<String, dynamic> product) {
    final productId = int.tryParse(product['id']?.toString() ?? '');
    if (productId == null) return false;

    final current = _items[productId];
    final item = MarketplaceCartItem(
      product: Map<String, dynamic>.from(product),
      quantity: (current?.quantity ?? 0) + 1,
    );
    if (item.unitPrice <= 0 ||
        item.quantity > item.availableStock ||
        item.quantity > 1000) {
      return false;
    }

    _items[productId] = item;
    notifyListeners();
    return true;
  }

  bool decrement(int productId) {
    final current = _items[productId];
    if (current == null) return false;
    if (current.quantity == 1) {
      _items.remove(productId);
    } else {
      _items[productId] = MarketplaceCartItem(
        product: current.product,
        quantity: current.quantity - 1,
      );
    }
    notifyListeners();
    return true;
  }

  bool increment(int productId) {
    final current = _items[productId];
    if (current == null ||
        current.quantity >= current.availableStock ||
        current.quantity >= 1000) {
      return false;
    }
    _items[productId] = MarketplaceCartItem(
      product: current.product,
      quantity: current.quantity + 1,
    );
    notifyListeners();
    return true;
  }

  void remove(int productId) {
    if (_items.remove(productId) != null) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
