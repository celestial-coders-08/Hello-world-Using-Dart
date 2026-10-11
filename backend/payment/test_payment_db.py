import os
import tempfile
import unittest
from unittest.mock import patch

from seller import seller_db
from payment import payment_db


class PaymentDatabaseTests(unittest.TestCase):
    def setUp(self):
        self._temp_dir = tempfile.TemporaryDirectory()
        self._original_path = seller_db.DATABASE_PATH
        seller_db.DATABASE_PATH = os.path.join(self._temp_dir.name, "seller.db")
        seller_db.initialize_database()
        self.product = seller_db.create_product(
            "seller-one",
            {
                "name": "Pet food",
                "price": 12.5,
                "mrp": 12.5,
                "stock_quantity": 1,
            },
        )

    def tearDown(self):
        seller_db.DATABASE_PATH = self._original_path
        self._temp_dir.cleanup()

    def test_payment_is_linked_to_buyer_and_seller_order(self):
        payment_order = payment_db.create_payment_order(
            product_id=self.product["id"],
            user_id=27,
            buyer_email="buyer@example.com",
            buyer_name="Buyer Name",
            razorpay_order_id="order_abc123",
            amount_paise=1250,
        )

        self.assertIsNotNone(payment_order)
        self.assertEqual(payment_db.get_buyer_orders(27), [])
        self.assertEqual(seller_db.list_products("seller-one")[0]["stock_quantity"], 0)
        self.assertIsNone(
            payment_db.create_payment_order(
                product_id=self.product["id"],
                user_id=31,
                buyer_email="other@example.com",
                buyer_name="Other Buyer",
                razorpay_order_id="order_def456",
                amount_paise=1250,
            )
        )

        completed = payment_db.finalize_payment(
            user_id=27,
            razorpay_order_id="order_abc123",
            razorpay_payment_id="pay_abc123",
        )
        self.assertEqual(completed["payment_status"], "Paid")
        self.assertEqual(completed["amount"], 12.5)
        self.assertEqual(
            payment_db.finalize_payment(
                user_id=27,
                razorpay_order_id="order_abc123",
                razorpay_payment_id="pay_abc123",
            ),
            completed,
        )

        orders = seller_db.list_orders("seller-one")
        self.assertEqual(len(orders), 1)
        self.assertEqual(orders[0]["buyer_user_id"], 27)
        self.assertEqual(orders[0]["customer_email"], "buyer@example.com")
        self.assertEqual(orders[0]["payment_status"], "Paid")
        buyer_orders = payment_db.get_buyer_orders(27)
        self.assertEqual(buyer_orders[0]["order_code"], completed["order_code"])
        self.assertEqual(buyer_orders[0]["order_status"], "Pending")
        self.assertEqual(payment_db.get_buyer_orders(31), [])

    def test_marketplace_products_includes_zero_stock_listings(self):
        from fastapi import HTTPException

        from payment.main import (
            CreateOrderRequest,
            create_checkout_order,
            marketplace_products,
        )
        from payment import main as payment_main

        out_of_stock = seller_db.create_product(
            "seller-two",
            {
                "name": "Out of stock toy",
                "price": 5,
                "mrp": 5,
                "stock_quantity": 0,
            },
        )

        products = marketplace_products()
        products_by_id = {product["id"]: product for product in products}
        self.assertIn(out_of_stock["id"], products_by_id)
        self.assertEqual(products_by_id[out_of_stock["id"]]["stock_quantity"], 0)
        self.assertEqual(products_by_id[self.product["id"]]["stock_quantity"], 1)

        user = type(
            "CheckoutUser",
            (),
            {
                "id": 27,
                "email": "buyer@example.com",
                "full_name": "Buyer Name",
                "phone_number": "",
            },
        )()
        payload = CreateOrderRequest(
            items=[{"product_id": out_of_stock["id"], "quantity": 1}]
        )
        with patch.object(payment_main, "_current_user", return_value=user):
            with patch.object(payment_main, "_razorpay_request") as create_gateway_order:
                with self.assertRaises(HTTPException) as error:
                    create_checkout_order(payload, authorization="Bearer test")

        self.assertEqual(error.exception.status_code, 409)
        create_gateway_order.assert_not_called()
        self.assertEqual(
            seller_db.list_products("seller-two")[0]["stock_quantity"], 0
        )

    def test_expired_checkout_releases_inventory(self):
        payment_db.create_payment_order(
            product_id=self.product["id"],
            user_id=27,
            buyer_email="buyer@example.com",
            buyer_name="Buyer Name",
            razorpay_order_id="order_expired1",
            amount_paise=1250,
        )
        with seller_db.connection() as db:
            db.execute(
                """
                UPDATE marketplace_payments
                SET created_at = datetime('now', '-16 minutes')
                WHERE razorpay_order_id = 'order_expired1'
                """
            )
            db.commit()

        payment_db.expire_pending_payments()
        self.assertEqual(seller_db.list_products("seller-one")[0]["stock_quantity"], 1)
        self.assertEqual(payment_db.get_buyer_orders(27), [])

    def test_cart_checkout_uses_one_payment_for_multiple_seller_orders(self):
        second_product = seller_db.create_product(
            "seller-two",
            {
                "name": "Dog toy",
                "price": 8.25,
                "mrp": 8.25,
                "stock_quantity": 4,
            },
        )
        with seller_db.connection() as db:
            db.execute(
                "UPDATE seller_products SET stock_quantity = 5 WHERE id = ?",
                (self.product["id"],),
            )
            db.commit()

        payment_order = payment_db.create_payment_order(
            items=[
                {"product_id": self.product["id"], "quantity": 2},
                {"product_id": second_product["id"], "quantity": 3},
            ],
            user_id=27,
            buyer_email="buyer@example.com",
            buyer_name="Buyer Name",
            razorpay_order_id="order_cart123",
            amount_paise=4975,
        )

        self.assertIsNotNone(payment_order)
        self.assertEqual(
            seller_db.list_products("seller-one")[0]["stock_quantity"], 3
        )
        self.assertEqual(
            seller_db.list_products("seller-two")[0]["stock_quantity"], 1
        )

        completed = payment_db.finalize_payment(
            user_id=27,
            razorpay_order_id="order_cart123",
            razorpay_payment_id="pay_cart123",
        )
        self.assertEqual(completed["amount"], 49.75)
        self.assertEqual(len(completed["items"]), 2)
        self.assertEqual(
            {order["seller_lookup"] for order in seller_db.list_orders("seller-one")},
            {"seller-one"},
        )
        seller_orders = seller_db.list_orders("seller-one") + seller_db.list_orders(
            "seller-two"
        )
        self.assertEqual(len(seller_orders), 2)
        self.assertEqual(
            {
                (order["seller_lookup"], order["product_id"], order["quantity"])
                for order in seller_orders
            },
            {
                ("seller-one", self.product["id"], 2),
                ("seller-two", second_product["id"], 3),
            },
        )

        buyer_order = payment_db.get_buyer_orders(27)[0]
        self.assertEqual(buyer_order["total_amount"], 49.75)
        self.assertEqual(len(buyer_order["items"]), 2)

    def test_expired_cart_restores_all_reserved_quantities(self):
        second_product = seller_db.create_product(
            "seller-two",
            {
                "name": "Dog toy",
                "price": 8.25,
                "mrp": 8.25,
                "stock_quantity": 4,
            },
        )
        with seller_db.connection() as db:
            db.execute(
                "UPDATE seller_products SET stock_quantity = 5 WHERE id = ?",
                (self.product["id"],),
            )
            db.commit()
        payment_db.create_payment_order(
            items=[
                {"product_id": self.product["id"], "quantity": 2},
                {"product_id": second_product["id"], "quantity": 3},
            ],
            user_id=27,
            buyer_email="buyer@example.com",
            buyer_name="Buyer Name",
            razorpay_order_id="order_expired_cart",
            amount_paise=4975,
        )
        with seller_db.connection() as db:
            db.execute(
                """
                UPDATE marketplace_payments
                SET created_at = datetime('now', '-16 minutes')
                WHERE razorpay_order_id = 'order_expired_cart'
                """
            )
            db.commit()

        payment_db.expire_pending_payments()
        self.assertEqual(
            seller_db.list_products("seller-one")[0]["stock_quantity"], 5
        )
        self.assertEqual(
            seller_db.list_products("seller-two")[0]["stock_quantity"], 4
        )

    def test_cart_reservation_rolls_back_if_any_product_lacks_stock(self):
        second_product = seller_db.create_product(
            "seller-two",
            {
                "name": "Dog toy",
                "price": 8.25,
                "mrp": 8.25,
                "stock_quantity": 1,
            },
        )
        with seller_db.connection() as db:
            db.execute(
                "UPDATE seller_products SET stock_quantity = 5 WHERE id = ?",
                (self.product["id"],),
            )
            db.commit()

        payment_order = payment_db.create_payment_order(
            items=[
                {"product_id": self.product["id"], "quantity": 2},
                {"product_id": second_product["id"], "quantity": 2},
            ],
            user_id=27,
            buyer_email="buyer@example.com",
            buyer_name="Buyer Name",
            razorpay_order_id="order_failed_cart",
            amount_paise=4150,
        )

        self.assertIsNone(payment_order)
        self.assertEqual(
            seller_db.list_products("seller-one")[0]["stock_quantity"], 5
        )
        self.assertEqual(
            seller_db.list_products("seller-two")[0]["stock_quantity"], 1
        )


if __name__ == "__main__":
    unittest.main()
