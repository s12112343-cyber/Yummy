import 'package:flutter/material.dart';

// ============================================================================
// INGREDIENT CONFIRMATION WIDGET
// Displays confirmed/rejected ingredients in an interactive UI
// ============================================================================

class IngredientItem {
  final String id;
  String name;
  String quantity;
  String unit;
  IngredientStatus status; // confirmed, rejected, pending

  IngredientItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.status = IngredientStatus.pending,
  });

  IngredientItem.fromJson(Map<String, dynamic> json)
    : id = json['id'] ?? '',
      name = json['name'] ?? '',
      quantity = (json['quantity'] ?? 0).toString(),
      unit = json['unit'] ?? 'g',
      status = _parseStatus(json['status']);

  static IngredientStatus _parseStatus(dynamic status) {
    if (status is String) {
      return IngredientStatus.values.firstWhere(
        (e) => e.toString().split('.').last == status,
        orElse: () => IngredientStatus.pending,
      );
    }
    return IngredientStatus.pending;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'status': status.toString().split('.').last,
  };

  IngredientItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? unit,
    IngredientStatus? status,
  }) => IngredientItem(
    id: id ?? this.id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    status: status ?? this.status,
  );
}

enum IngredientStatus { pending, confirmed, rejected }

class IngredientConfirmationWidget extends StatefulWidget {
  final String mealName;
  final List<IngredientItem> ingredients;
  final Function(List<IngredientItem> confirmedIngredients) onConfirm;
  final VoidCallback onAddMissing;
  final VoidCallback onCancel;

  const IngredientConfirmationWidget({
    super.key,
    required this.mealName,
    required this.ingredients,
    required this.onConfirm,
    required this.onAddMissing,
    required this.onCancel,
  });

  @override
  State<IngredientConfirmationWidget> createState() =>
      _IngredientConfirmationWidgetState();
}

class _IngredientConfirmationWidgetState
    extends State<IngredientConfirmationWidget> {
  late List<IngredientItem> _ingredients;

  static const Color _navy = Color(0xFF061A40);
  static const Color _navy2 = Color(0xFF0B2A5B);
  static const Color _pageBg = Color(0xFFF8FAFD);
  static const Color _cardBorder = Color(0xFFE7EEF8);
  static const Color _mutedText = Color(0xFF66758A);
  static const Color _white = Colors.white;
  static const Color _greenConfirm = Color(0xFF10B981);
  static const Color _redReject = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.ingredients);
  }

  void _confirmIngredient(String id) {
    setState(() {
      final index = _ingredients.indexWhere((e) => e.id == id);
      if (index != -1) {
        _ingredients[index] = _ingredients[index].copyWith(
          status: IngredientStatus.confirmed,
        );
      }
    });
  }

  void _rejectIngredient(String id) {
    setState(() {
      final index = _ingredients.indexWhere((e) => e.id == id);
      if (index != -1) {
        _ingredients[index] = _ingredients[index].copyWith(
          status: IngredientStatus.rejected,
        );
      }
    });
  }

  void _editIngredient(String id) {
    final index = _ingredients.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final ingredient = _ingredients[index];
    final nameCtrl = TextEditingController(text: ingredient.name);
    final quantityCtrl = TextEditingController(text: ingredient.quantity);
    final unitCtrl = TextEditingController(text: ingredient.unit);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Ingredient'),
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Ingredient Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              setState(() {
                _ingredients[index] = _ingredients[index].copyWith(
                  name: nameCtrl.text.trim(),
                  quantity: quantityCtrl.text.trim(),
                  unit: unitCtrl.text.trim(),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: _white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmedCount = _ingredients
        .where((e) => e.status == IngredientStatus.confirmed)
        .length;
    final totalCount = _ingredients
        .where((e) => e.status != IngredientStatus.rejected)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with meal name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, _navy2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We recognized: ${widget.mealName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Confirm, edit, or remove ingredients:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ingredients list
          Expanded(
            child: _ingredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 48,
                          color: _mutedText.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No ingredients found',
                          style: TextStyle(
                            color: _mutedText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _ingredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = _ingredients[index];
                      return _buildIngredientCard(ingredient);
                    },
                  ),
          ),

          // Add missing ingredient button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton.icon(
              onPressed: widget.onAddMissing,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _navy.withOpacity(0.2)),
                backgroundColor: _white,
                foregroundColor: _navy,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Missing Ingredient',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // Bottom action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _navy.withOpacity(0.2)),
                    backgroundColor: _white,
                    foregroundColor: _navy,
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: confirmedCount > 0
                      ? () {
                          final confirmed = _ingredients
                              .where(
                                (e) =>
                                    e.status == IngredientStatus.confirmed,
                              )
                              .toList();
                          widget.onConfirm(confirmed);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    disabledBackgroundColor: _navy.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Confirm ($confirmedCount/$totalCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(IngredientItem ingredient) {
    final isConfirmed = ingredient.status == IngredientStatus.confirmed;
    final isRejected = ingredient.status == IngredientStatus.rejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConfirmed
              ? _greenConfirm.withOpacity(0.3)
              : isRejected
              ? _redReject.withOpacity(0.2)
              : _cardBorder,
          width: isConfirmed ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ingredient info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      style: TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: isRejected
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: _redReject,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ingredient.quantity} ${ingredient.unit}',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConfirmed)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _greenConfirm.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _greenConfirm,
                    size: 20,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              // Confirm button
              Expanded(
                child: _ActionButton(
                  icon: Icons.check_rounded,
                  label: 'Confirm',
                  color: _greenConfirm,
                  isActive: isConfirmed,
                  onPressed: () => _confirmIngredient(ingredient.id),
                ),
              ),
              const SizedBox(width: 8),

              // Edit button
              Expanded(
                child: _ActionButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: _navy,
                  isActive: false,
                  onPressed: () => _editIngredient(ingredient.id),
                ),
              ),
              const SizedBox(width: 8),

              // Delete button
              Expanded(
                child: _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'Delete',
                  color: _redReject,
                  isActive: isRejected,
                  onPressed: () => _rejectIngredient(ingredient.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTION BUTTON COMPONENT
// ============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(isActive ? 0.5 : 0.2),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? color : color.withOpacity(0.6),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? color : color.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
