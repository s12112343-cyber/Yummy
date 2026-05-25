import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/services/auth_service.dart';
import 'package:frontend/core/services/cart_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'my_orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double total;
  final List<Map<String, dynamic>> cartItems;

  const CheckoutScreen({
    super.key,
    required this.total,
    required this.cartItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Color navy = const Color(0xff1C4D8D);
  final _formKey = GlobalKey<FormState>();

  bool _isPlacingOrder = false;
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final cityController = TextEditingController();
  final streetController = TextEditingController();
  final notesController = TextEditingController();
  final cardNameController = TextEditingController();
  final cardNumberController = TextEditingController();
  final expiryController = TextEditingController();
  final cvvController = TextEditingController();

  String payment = 'cash';
  String selectedCardType = 'Visa';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final savedName = await AuthService().getUserName();
    if (!mounted || savedName.trim().isEmpty) return;

    nameController.text = savedName;
    if (cardNameController.text.trim().isEmpty) {
      cardNameController.text = savedName;
    }
    setState(() {});
  }

  bool _isValidPhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9+]'), '');
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    streetController.dispose();
    notesController.dispose();
    cardNameController.dispose();
    cardNumberController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    super.dispose();
  }

  Widget _section(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _cardTypeButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? navy : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: selected ? Colors.white : navy),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryFee = 3.0;
    final subtotal = widget.total;
    final total = subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _isPlacingOrder
                    ? null
                    : () async {
                        final isValid =
                            _formKey.currentState?.validate() ?? false;
                        if (!isValid) return;

                        setState(() {
                          _isPlacingOrder = true;
                        });

                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('userId');
                          final token = prefs.getString('token');

                          for (final item in widget.cartItems) {
                            final response = await http.post(
                              Uri.parse('${AppConfig.baseUrl}/orders/create'),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'userId': userId,
                                'chefId': item['chefId'],
                                'recipeId':
                                    item['recipeId'] ??
                                    item['_id'] ??
                                    item['id'],
                                'dishName': item['name'],
                                'dishImage': item['image'],
                                'quantity': item['quantity'],
                                'price': item['price'],
                                'size': item['size'] ?? '',
                                'calories':
                                    item['calories'] ?? item['cal'] ?? 0,
                                'fat': item['fat'] ?? 0,
                                'protein': item['protein'] ?? 0,
                                'carbs':
                                    item['carbs'] ?? item['carbohydrates'] ?? 0,
                                'specialInstructions': notesController.text,
                                'phone': phoneController.text,
                                'city': cityController.text,
                                'street': streetController.text,
                                'paymentMethod': payment,
                                'totalPrice': item['price'] * item['quantity'],
                              }),
                            );

                            if (response.statusCode != 201) {
                              throw Exception(response.body);
                            }
                          }

                          await CartService.clear();

                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const MyOrdersScreen(),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isPlacingOrder = false;
                            });
                          }
                        }
                      },
                child: _isPlacingOrder
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Place Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _section(
                'Delivery Address',
                Column(
                  children: [
                    _field(
                      'Full Name',
                      nameController,
                      readOnly: true,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    _field(
                      'Phone',
                      phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final phone = (value ?? '').trim();
                        if (phone.isEmpty) {
                          return 'Phone number is required';
                        }
                        if (!_isValidPhone(phone)) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    _field('City', cityController),
                    _field('Street Address', streetController),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _section(
                'Payment',
                Column(
                  children: [
                    RadioListTile(
                      value: 'cash',
                      groupValue: payment,
                      title: const Text('Cash on Delivery'),
                      onChanged: (v) {
                        setState(() {
                          payment = v!;
                        });
                      },
                    ),
                    RadioListTile(
                      value: 'card',
                      groupValue: payment,
                      title: const Text('Credit Card'),
                      onChanged: (v) {
                        setState(() {
                          payment = v!;
                        });
                      },
                    ),
                    if (payment == 'card') ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Card Type',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _cardTypeButton(
                              title: 'Visa',
                              icon: Icons.credit_card,
                              selected: selectedCardType == 'Visa',
                              onTap: () {
                                setState(() {
                                  selectedCardType = 'Visa';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _cardTypeButton(
                              title: 'MasterCard',
                              icon: Icons.credit_card,
                              selected: selectedCardType == 'MasterCard',
                              onTap: () {
                                setState(() {
                                  selectedCardType = 'MasterCard';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _cardTypeButton(
                              title: 'Amex',
                              icon: Icons.credit_card,
                              selected: selectedCardType == 'Amex',
                              onTap: () {
                                setState(() {
                                  selectedCardType = 'Amex';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [navy, navy.withOpacity(.85)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: navy.withOpacity(.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedCardType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              cardNumberController.text.isEmpty
                                  ? '•••• •••• •••• ••••'
                                  : cardNumberController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CARD HOLDER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cardNameController.text.isEmpty
                                          ? 'YOUR NAME'
                                          : cardNameController.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'EXPIRES',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      expiryController.text.isEmpty
                                          ? 'MM/YY'
                                          : expiryController.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _field(
                        'Card Holder Name',
                        cardNameController,
                        validator: (value) {
                          if (payment != 'card') return null;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Card holder name is required';
                          }
                          return null;
                        },
                      ),
                      _field(
                        'Card Number',
                        cardNumberController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (payment != 'card') return null;
                          final digits = (value ?? '').replaceAll(
                            RegExp(r'\s+'),
                            '',
                          );
                          if (digits.length < 13 || digits.length > 19) {
                            return 'Enter a valid card number';
                          }
                          return null;
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'MM/YY',
                              expiryController,
                              validator: (value) {
                                if (payment != 'card') return null;
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Expiry is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              'CVV',
                              cvvController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (payment != 'card') return null;
                                final cvv = (value ?? '').trim();
                                if (cvv.length < 3 || cvv.length > 4) {
                                  return 'Invalid CVV';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xffEEF4FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 18, color: navy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Secure encrypted payment',
                                style: TextStyle(fontSize: 12, color: navy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _section(
                'Special Instructions',
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Leave at door, call on arrival...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _section(
                'Order Summary',
                Column(
                  children: [
                    _priceRow('Subtotal', subtotal),
                    _priceRow('Delivery', deliveryFee),
                    const Divider(),
                    _priceRow('Total', total, bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String hint,
    TextEditingController controller, {
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xffF6F7F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
