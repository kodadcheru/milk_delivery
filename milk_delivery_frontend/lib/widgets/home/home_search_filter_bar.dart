import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search milk, chicken, mutton, eggs, water can...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0D7C66), size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: onClearSearch,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Category Quick Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill('ALL', 'All Items ✨'),
                const SizedBox(width: 8),
                _buildCategoryPill('MILK', '🥛 Milk'),
                const SizedBox(width: 8),
                _buildCategoryPill('MEAT', '🥩 Meat'),
                const SizedBox(width: 8),
                _buildCategoryPill('EGGS', '🥚 Eggs'),
                const SizedBox(width: 8),
                _buildCategoryPill('WATER_CAN', '💧 Water Can'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String catKey, String label) {
    final isSelected = selectedCategory == catKey;
    return InkWell(
      onTap: () => onCategorySelected(catKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
