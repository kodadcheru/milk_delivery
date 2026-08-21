import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NextGenNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badgeText;

  const NextGenNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeText,
  });
}

class NextGenBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<NextGenNavItem> items;

  const NextGenBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? bottomInset : 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF0D7C66).withValues(alpha: 0.10),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x181A2B23),
                  blurRadius: 24,
                  offset: Offset(0, -2),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Color(0x0A10B766),
                  blurRadius: 40,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppTheme.hapticLight();
                      onItemSelected(index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Pill Indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 56 : 40,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF0D7C66), Color(0xFF10B766)],
                                  )
                                : null,
                            color: isSelected ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B766).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: isSelected ? 20 : 22,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                              if (item.badgeText != null &&
                                  item.badgeText!.isNotEmpty &&
                                  !isSelected)
                                Positioned(
                                  right: -14,
                                  top: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B766),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B766).withValues(alpha: 0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      item.badgeText!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 2),

                        // Label
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFF475569),
                            letterSpacing: isSelected ? -0.2 : 0,
                          ),
                        ),

                        // Bottom accent line
                        if (isSelected)
                          Container(
                            width: 20,
                            height: 3,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D7C66),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          )
                        else
                          const SizedBox(height: 5),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
