import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/marketplace_cart.dart';

void main() {
  final cart = MarketplaceCart.instance;

  setUp(cart.clear);

  test('tracks item quantities and subtotal within available stock', () {
    final product = {
      'id': 11,
      'name': 'Pet food',
      'price': 12.5,
      'stock_quantity': 2,
    };

    expect(cart.addProduct(product), isTrue);
    expect(cart.addProduct(product), isTrue);
    expect(cart.addProduct(product), isFalse);
    expect(cart.quantityFor(11), 2);
    expect(cart.itemCount, 2);
    expect(cart.subtotal, 25);
  });

  test('increments items when stock is provided as a decimal number', () {
    expect(
      cart.addProduct({
        'id': 12,
        'name': 'Pet food',
        'price': 12.5,
        'stock_quantity': 3.0,
      }),
      isTrue,
    );
    expect(cart.increment(12), isTrue);
    expect(cart.quantityFor(12), 2);
    expect(cart.items.single.totalPrice, 25);
    expect(cart.subtotal, 25);
  });

  test('decrementing the last unit removes the item from the cart', () {
    cart.addProduct({
      'id': 19,
      'name': 'Toy',
      'price': 8.25,
      'stock_quantity': 1,
    });

    expect(cart.decrement(19), isTrue);
    expect(cart.isEmpty, isTrue);
    expect(cart.subtotal, 0);
  });

  test('remove deletes an item and recalculates the cart count', () {
    cart.addProduct({
      'id': 31,
      'name': 'Treats',
      'price': 4,
      'stock_quantity': 3,
    });
    cart.addProduct({
      'id': 32,
      'name': 'Leash',
      'price': 10,
      'stock_quantity': 3,
    });

    cart.remove(31);

    expect(cart.itemCount, 1);
    expect(cart.subtotal, 10);
    expect(cart.quantityFor(31), 0);
  });

  test('refreshing stock prevents checkout when items become unavailable', () {
    cart.addProduct({
      'id': 41,
      'name': 'Pet bowl',
      'price': 7,
      'stock_quantity': 3,
    });
    cart.addProduct({
      'id': 41,
      'name': 'Pet bowl',
      'price': 7,
      'stock_quantity': 3,
    });

    cart.refreshProducts([
      {'id': 41, 'name': 'Pet bowl', 'price': 7, 'stock_quantity': 1},
    ]);
    expect(cart.stockIssue, 'Only 1 of Pet bowl available.');

    cart.refreshProducts([
      {'id': 41, 'name': 'Pet bowl', 'price': 7, 'stock_quantity': 4},
    ]);
    expect(cart.stockIssue, isNull);
    expect(cart.items.single.availableStock, 4);
  });

  test('refreshing stock marks removed products as unavailable', () {
    cart.addProduct({
      'id': 51,
      'name': 'Cat treats',
      'price': 6,
      'stock_quantity': 1,
    });

    cart.refreshProducts([]);

    expect(cart.stockIssue, 'Cat treats is out of stock.');
  });
}
