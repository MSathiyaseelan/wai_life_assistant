import 'package:flutter/material.dart';
import '../../../data/models/pantry/groceryitem.dart';
import 'grocerycontroller.dart';

class ConsumeItemSheet extends StatefulWidget {
  final GroceryItem item;
  final GroceryController controller;

  const ConsumeItemSheet({
    super.key,
    required this.item,
    required this.controller,
  });

  @override
  State<ConsumeItemSheet> createState() => _ConsumeItemSheetState();
}

class _ConsumeItemSheetState extends State<ConsumeItemSheet> {
  late double _amountUsed;

  @override
  void initState() {
    super.initState();
    _amountUsed = 1; // default usage
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Consume ${widget.item.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),

            // Available quantity
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Available: ${widget.item.quantity} ${widget.item.unit}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            const SizedBox(height: 16),

            // Amount selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Quantity used:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: _amountUsed,
                      min: 0,
                      max: widget.item.quantity,
                      divisions: widget.item.quantity.toInt(),
                      label: _amountUsed.toString(),
                      onChanged: (val) {
                        setState(() => _amountUsed = val);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(_amountUsed.toStringAsFixed(0)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _amountUsed > 0
                          ? () {
                              widget.controller.consumeItem(
                                widget.item,
                                _amountUsed,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${widget.item.name} updated. $_amountUsed ${widget.item.unit} used.',
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          : null,
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
