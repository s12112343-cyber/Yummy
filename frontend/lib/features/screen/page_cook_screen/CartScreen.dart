import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/cart_service.dart';
import 'checkout_screen.dart';
import '../../../core/config/app_config.dart';

// ─── Colors ────────────────────────────────────────────────────────────────
const Color _kNavy = Color(0xFF001F3F);
const Color _kBlue = Color(0xFF005EB2);
const Color _kBluePale = Color(0xFFD5E3FF);
const Color _kCard = Color(0xFFFFFFFF);
const Color _kSurface = Color(0xFFF8F9FA);
const Color _kText = Color(0xFF191C1D);
const Color _kTextDim = Color(0xFF43474E);
const Color _kOutline = Color(0xFFC4C6CF);
const Color _kError = Color(0xFFBA1A1A);
const Color _kSuccess = Color(0xFF10B981);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ════════════════════════════════════════════════════════════════════════
  // 🎨 BUILD CART ITEM WIDGET
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildCartItem(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
    List<Map<String, dynamic>> cartItems,
  ) {
    final image = item['image'] ?? '';
    final name = item['name'] ?? 'Recipe';
    final chefName = item['chefName'] ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final quantity = (item['quantity'] ?? 1);
    final note = item['note'] ?? '';

    return Dismissible(
      key: ValueKey(item['id'] ?? index),

      direction: DismissDirection.endToStart,

      onDismissed: (_) {
        HapticFeedback.mediumImpact();

        setState(() {
          CartService.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item removed from cart'),
            backgroundColor: _kError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },

      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: _kError,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),

      child: Center(
        child: Container(
          width: 290,
          margin: const EdgeInsets.only(bottom: 18),

          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 18),

              /// bigger centered image
              _buildProductImage(image, name),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),

                    if (chefName.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'by $chefName',
                        style: const TextStyle(fontSize: 12, color: _kTextDim),
                      ),
                    ],

                    const SizedBox(height: 10),

                    Text(
                      '\$${(price * quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildQuantitySelector(
                  quantity: quantity,

                  onDecrement: () {
                    if (quantity > 1) {
                      setState(() {
                        item['quantity'] = quantity - 1;
                      });
                      CartService.saveCart(cartItems);
                    }
                  },

                  onIncrement: () {
                    setState(() {
                      item['quantity'] = quantity + 1;
                    });

                    CartService.saveCart(cartItems);
                  },
                ),
              ),

              if (note.isNotEmpty) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildNoteDisplay(note),
                ),
              ],

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.note_add_outlined,
                        label: 'Add Note',
                        color: _kBlue,
                        onTap: () {
                          _showNoteDialog(context, item);
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.delete_outline,
                        label: 'Remove',
                        color: _kError,
                        onTap: () {
                          setState(() {
                            cartItems.removeAt(index);
                          });

                          CartService.saveCart(cartItems);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🎨 HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildProductImage(String imageUrl, String productName) {
    // ✅ HANDLE ALL TYPES
    String finalImage = '';

    if (imageUrl.isNotEmpty) {
      // ✅ already full url
      if (imageUrl.startsWith('http')) {
        finalImage = imageUrl;
      } else {
        // ✅ uploads image
        finalImage = '${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl';
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),

      child: Container(
        width: 100,
        height: 100,

        color: _kBluePale,

        child: finalImage.isEmpty
            ? const Center(child: Text('🍽️', style: TextStyle(fontSize: 40)))
            : Image.network(
                finalImage,

                fit: BoxFit.cover,

                cacheWidth: 500,
                cacheHeight: 500,

                filterQuality: FilterQuality.low,

                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 32,
                          color: _kBlue,
                        ),

                        const SizedBox(height: 4),

                        Text(
                          productName,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 10,
                            color: _kTextDim,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildQuantitySelector({
    required int quantity,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOutline.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Quantity',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          Row(
            children: [
              // Decrease Button
              _buildQtyButton(icon: Icons.remove, onTap: onDecrement),

              const SizedBox(width: 16),

              // Quantity Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kOutline.withOpacity(0.2)),
                ),
                child: Text(
                  quantity.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Increase Button
              _buildQtyButton(icon: Icons.add, onTap: onIncrement),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: _kBlue),
      ),
    );
  }

  Widget _buildNoteDisplay(String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.note_outlined, size: 16, color: Color(0xFFA16207)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFA16207),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 📝 NOTE DIALOG
  // ════════════════════════════════════════════════════════════════════════

  void _showNoteDialog(BuildContext context, Map<String, dynamic> item) {
    final TextEditingController noteController = TextEditingController(
      text: item['note'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Add Special Instructions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell the chef your preferences',
              style: TextStyle(fontSize: 12, color: _kTextDim),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'e.g., No onions, extra spicy, less salt...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: _kTextDim.withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _kOutline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _kBlue, width: 2),
                ),
                filled: true,
                fillColor: _kSurface,
                counterStyle: TextStyle(
                  fontSize: 11,
                  color: _kTextDim.withOpacity(0.5),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 14, color: _kTextDim),
            ),
          ),

          // Save Button
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();

              setState(() {
                item['note'] = noteController.text.trim();
              });

              await CartService.saveCart(CartService.cartItems.value);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✨ Instructions saved!'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: _kSuccess,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kNavy,
        elevation: 0,
        centerTitle: true,

        leadingWidth: 72,

        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _kBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),

        title: const Text(
          "My Cart",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: CartService.cartItems,
        builder: (context, cartItems, _) {
          double totalPrice = 0;

          for (final item in cartItems) {
            final price = (item['price'] ?? 0).toDouble();
            final qty = (item['quantity'] ?? 1);
            totalPrice += price * qty;
          }

          // ─── Empty Cart ────────────────────────────────────────────────
          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _kBluePale,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 40,
                        color: _kBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your Cart is Empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add delicious meals from your favorite chefs',
                    style: TextStyle(fontSize: 14, color: _kTextDim),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _kBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Start Shopping',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // ─── Cart with Items ───────────────────────────────────────────
          return Column(
            children: [
              // Cart Items List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    return _buildCartItem(
                      context,
                      cartItems[index],
                      index,
                      cartItems,
                    );
                  },
                ),
              ),

              // Bottom Bar with Total and Checkout
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kText,
                          ),
                        ),
                        Text(
                          '\$${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _kBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Checkout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                total: totalPrice,
                                cartItems: cartItems,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Proceed to Checkout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
