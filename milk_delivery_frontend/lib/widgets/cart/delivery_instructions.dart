import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/ui_tokens.dart';

class DeliveryInstructions extends StatefulWidget {
  final ValueChanged<List<String>> onChanged;
  final bool isTelugu;

  const DeliveryInstructions({
    super.key,
    required this.onChanged,
    this.isTelugu = false,
  });

  @override
  State<DeliveryInstructions> createState() => _DeliveryInstructionsState();
}

class _DeliveryInstructionsState extends State<DeliveryInstructions> {
  final List<Map<String, dynamic>> _options = [
    {'key': "dont_ring_bell", 'en': "Don't ring bell", 'te': "డోర్‌బెల్ మోగించవద్దు", 'icon': Icons.notifications_off_outlined},
    {'key': 'leave_at_door', 'en': 'Leave at door', 'te': 'తలుపు వద్ద ఉంచండి', 'icon': Icons.door_front_door_outlined},
    {'key': 'avoid_calling', 'en': 'Avoid calling', 'te': 'కాల్ చేయవద్దు', 'icon': Icons.phone_disabled_outlined},
    {'key': 'leave_with_guard', 'en': 'Leave with security', 'te': 'సెక్యూరిటీ గార్డు వద్ద ఉంచండి', 'icon': Icons.shield_outlined},
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isTelugu ? 'డెలివరీ సూచనలు' : 'Delivery Instructions',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: UiTone.ink,
                    ),
                  ),
                  Text(
                    widget.isTelugu ? 'డోర్‌స్టెప్ వద్ద డెలివరీ పార్టనర్‌కు సూచనలు' : 'Guidance for your delivery partner at doorstep',
                    style: const TextStyle(
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
              final key = opt['key'] as String;
              final label = widget.isTelugu ? (opt['te'] as String) : (opt['en'] as String);
              final icon = opt['icon'] as IconData;
              final isSelected = _selected.contains(key);

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _selected.remove(key);
                    } else {
                      _selected.add(key);
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
