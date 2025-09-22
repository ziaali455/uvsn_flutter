import 'package:flutter/material.dart';
import '../services/photographic_calculations.dart';

class LampConditionSelector extends StatefulWidget {
  final String? initialValue;
  final Function(String?) onChanged;

  const LampConditionSelector({
    Key? key,
    this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<LampConditionSelector> createState() => _LampConditionSelectorState();
}

class _LampConditionSelectorState extends State<LampConditionSelector> {
  String? selectedCondition;

  @override
  void initState() {
    super.initState();
    selectedCondition = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Lamp Condition',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedCondition,
            decoration: InputDecoration(
              hintText: 'Select lamp condition',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('None selected'),
              ),
              ...PhotographicCalculations.lampConditions.map((condition) {
                return DropdownMenuItem<String>(
                  value: condition,
                  child: Text(condition),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                selectedCondition = value;
              });
              widget.onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
