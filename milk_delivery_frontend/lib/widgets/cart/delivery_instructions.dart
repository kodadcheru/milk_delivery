import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class DeliveryInstructions extends StatefulWidget {
  final ValueChanged<List<String>> onChanged;

  const DeliveryInstructions({
    super.key,
    required this.onChanged,
  });

  @override
  State<DeliveryInstructions> createState() => _DeliveryInstructionsState();
}

class _DeliveryInstructionsState extends State<DeliveryInstructions> {
  final List<String> _options = [
    "🔕 Don't ring bell",
    "🚪 Leave at door",
    "📞 Avoid calling",
    "🛡️ Leave with guard",
  ];
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((option) {
        final isSelected = _selected.contains(option);
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selected.remove(option);
              } else {
                _selected.add(option);
              }
            });
            widget.onChanged(_selected.toList());
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? UiTone.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? UiTone.primary : UiTone.softText.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : UiTone.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
