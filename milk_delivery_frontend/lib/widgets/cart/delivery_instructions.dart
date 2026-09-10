import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<Map<String, dynamic>> _options = [
    {'label': "Don't ring bell", 'icon': Icons.notifications_off_outlined},
    {'label': 'Leave at door', 'icon': Icons.door_front_door_outlined},
    {'label': 'Avoid calling', 'icon': Icons.phone_disabled_outlined},
    {'label': 'Leave with security', 'icon': Icons.shield_outlined},
  ];
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: UiTone.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.electric_moped_outlined,
                  size: 16,
                  color: UiTone.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Instructions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: UiTone.ink,
                    ),
                  ),
                  Text(
                    'Guidance for your delivery partner at doorstep',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: UiTone.softText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.map((opt) {
              final label = opt['label'] as String;
              final icon = opt['icon'] as IconData;
              final isSelected = _selected.contains(label);

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _selected.remove(label);
                    } else {
                      _selected.add(label);
                    }
                  });
                  widget.onChanged(_selected.toList());
                },
                borderRadius: BorderRadius.circular(UiRadius.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? UiTone.primarySoft : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    border: Border.all(
                      color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : icon,
                        size: 14,
                        color: isSelected ? UiTone.primaryDark : UiTone.softText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? UiTone.primaryDark : UiTone.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
