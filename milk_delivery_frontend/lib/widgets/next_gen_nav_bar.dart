import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/ui_tokens.dart';

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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UiRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: UiTone.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(UiRadius.xl),
              border: Border.all(
                color: UiTone.surfaceBorder,
                width: 1.2,
              ),
              boxShadow: UiShadow.floatingNav,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      AppTheme.hapticLight();
                      onItemSelected(index);
                    },
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    splashColor: UiTone.primarySoft,
                    highlightColor: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? UiTone.primarySoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(UiRadius.md),
                        border: isSelected
                            ? Border.all(
                                color: UiTone.primary.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: isSelected ? 22 : 20,
                                color: isSelected ? UiTone.primary : UiTone.softText,
                              ),
                              if (item.badgeText != null && item.badgeText!.isNotEmpty)
                                Positioned(
                                  right: -12,
                                  top: -5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: UiTone.secondary,
                                      borderRadius: BorderRadius.circular(UiRadius.pill),
                                      boxShadow: [
                                        BoxShadow(
                                          color: UiTone.secondary.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      item.badgeText!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? UiTone.primary : UiTone.softText,
                              letterSpacing: isSelected ? -0.2 : 0,
                            ),
                          ),
                        ],
                      ),
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
