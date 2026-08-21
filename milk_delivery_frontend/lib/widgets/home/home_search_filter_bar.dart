import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class HomeSearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedCategory;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onClearSearch;

  const HomeSearchFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onClearSearch,
  });

  static const List<Map<String, dynamic>> _filters = [
    {'key': 'ALL', 'label': 'All Products', 'icon': Icons.grid_view_rounded},
    {'key': 'MILK', 'label': 'Milk', 'icon': Icons.local_drink_rounded},
    {'key': 'MEAT', 'label': 'Meat', 'icon': Icons.restaurant_rounded},
    {'key': 'EGGS', 'label': 'Eggs', 'icon': Icons.egg_rounded},
    {'key': 'WATER_CAN', 'label': 'Water', 'icon': Icons.water_drop_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = selectedCategory == filter['key'];

          return GestureDetector(
            onTap: () => onCategorySelected(filter['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF0D7C66), Color(0xFF14A38B)],
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(UiRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0D7C66)
                      : UiTone.surfaceBorder,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 15,
                    color: isSelected ? Colors.white : const Color(0xFF0D7C66),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
