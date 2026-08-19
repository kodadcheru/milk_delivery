import 'package:flutter/material.dart';
import '../../providers/app_state.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppState state;

  const AdminDashboardScreen({super.key, required this.state});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _catalogCategoryFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final vol = widget.state.totalDailyMilkVolume;
    final rev = widget.state.totalDailyRevenue;

    final filteredProducts = widget.state.products.where((p) {
      return _catalogCategoryFilter == 'ALL' || p.category == _catalogCategoryFilter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. ADMIN WEB CONSOLE LAUNCH BANNER ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D7C66)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7C66).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Text('🖥️', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Full Operations Web Console',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('🟢 LIVE', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'http://127.0.0.1:8000/admin-console/',
                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF0D7C66),
                        content: Text('🌐 Open http://127.0.0.1:8000/admin-console/ in your browser for full Web Console!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Launch Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── 2. EXECUTIVE KPI METRICS GRID ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _buildKpiCard('Total Daily Demand', '${vol.toInt()} Units/L', '↑ 12% today', Icons.water_drop_rounded, const Color(0xFF0D7C66)),
              _buildKpiCard('Today\'s Revenue', '₹${rev.toStringAsFixed(2)}', '↑ 8% growth', Icons.currency_rupee_rounded, const Color(0xFF10B981)),
              _buildKpiCard('Active Subscribers', '${widget.state.subscriptions.length} Users', '100% active', Icons.people_alt_rounded, const Color(0xFF0284C7)),
              _buildKpiCard('Today\'s Deliveries', '${widget.state.deliveries.length} Drops', 'On-time target', Icons.local_shipping_rounded, const Color(0xFFF59E0B)),
            ],
          ),

          const SizedBox(height: 22),

          // ── 3. DELIVERY PARTNER FLEET SECTION ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Partner Fleet',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage driver accounts & morning route dispatches',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddDriverDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 15),
                label: const Text('Add Driver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7C66),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF0D7C66), size: 22),
                  ),
                  title: const Text('Suresh Kumar (Primary Partner)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A))),
                  subtitle: const Text('Phone: 9876543210 • Route: Jubilee & Banjara Hills', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Text('ONLINE 🟢', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assigned Drops: ${widget.state.deliveries.length} Deliveries',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Rating: 4.9 ★ (184 Drops)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── 4. DAIRY DEMAND FORECAST BREAKDOWN ──
          const Text(
            'Morning Milk Procurement Forecast',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
          ),
          const SizedBox(height: 2),
          const Text(
            'Volume required from dairy processing plant for morning batch:',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildDemandRow('Farm Fresh A2 Desi Cow Milk', '250 Liters (Pouch)', '71.4%', 0.714, const Color(0xFF0D7C66)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildDemandRow('Pure Buffalo Milk (High Fat)', '120 Liters (Pouch)', '24.2%', 0.242, const Color(0xFF0284C7)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildDemandRow('Farm Fresh Set Curd (Dahi)', '45 Tubs (500g)', '4.4%', 0.044, const Color(0xFFF59E0B)),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── 5. CATALOG & INVENTORY MANAGEMENT ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Catalog & Inventory',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage prices, stock status & 4 core categories',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddProductDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7C66),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCatChip('ALL', 'All Items (${widget.state.products.length})'),
                const SizedBox(width: 8),
                _buildCatChip('MILK', '🥛 Milk'),
                const SizedBox(width: 8),
                _buildCatChip('MEAT', '🥩 Meat'),
                const SizedBox(width: 8),
                _buildCatChip('EGGS', '🥚 Eggs'),
                const SizedBox(width: 8),
                _buildCatChip('WATER_CAN', '💧 Water Can'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredProducts.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final p = filteredProducts[idx];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(p.icon, style: const TextStyle(fontSize: 24)),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                  subtitle: Text('${p.category.replaceAll('_', ' ')} • ₹${p.pricePerUnit.toStringAsFixed(0)} / ${p.unitQuantity}', style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
                  trailing: Switch(
                    value: p.isAvailable,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${p.name} stock status toggled.')),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCatChip(String key, String label) {
    final isSelected = _catalogCategoryFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0D7C66),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
      ),
      showCheckmark: false,
      onSelected: (val) {
        setState(() => _catalogCategoryFilter = key);
      },
    );
  }

  Widget _buildKpiCard(String title, String val, String trend, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            val,
            style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            trend,
            style: TextStyle(color: Colors.grey[500], fontSize: 9.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandRow(String item, String volume, String pctText, double pctValue, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                Text(volume, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(pctText, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pctValue,
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showAddDriverDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Ramesh Reddy');
    final phoneCtrl = TextEditingController(text: '9848022338');
    final vehicleCtrl = TextEditingController(text: 'TS 09 EA 4892');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🛵', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Add Delivery Partner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Register driver phone number. The delivery partner can log in using this phone number.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            TextField(controller: vehicleCtrl, decoration: const InputDecoration(labelText: 'Vehicle Number (e.g. Scooter)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0D7C66),
                  content: Text('🛵 Driver ${nameCtrl.text} (${phoneCtrl.text}) registered! Enabled for Driver Login.'),
                ),
              );
            },
            child: const Text('Register Driver'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Farm Fresh Paneer (Cottage Cheese)');
    final descCtrl = TextEditingController(text: 'Organic fresh malai paneer rich in protein.');
    final priceCtrl = TextEditingController(text: '95.00');
    final qtyCtrl = TextEditingController(text: '200 g Pack');
    String selectedCategory = 'MILK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Core Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'MILK', child: Text('🥛 Fresh Milk & Dairy')),
                    DropdownMenuItem(value: 'MEAT', child: Text('🥩 Meat & Poultry')),
                    DropdownMenuItem(value: 'EGGS', child: Text('🥚 Farm Eggs')),
                    DropdownMenuItem(value: 'WATER_CAN', child: Text('💧 Water Cans')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedCategory = val ?? 'MILK'),
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Unit Quantity (e.g. 500 mL / 200 g)', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final double p = double.tryParse(priceCtrl.text) ?? 50.0;
                widget.state.addNewProduct(
                  nameCtrl.text,
                  descCtrl.text,
                  p,
                  qtyCtrl.text,
                  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
                  category: selectedCategory,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✨ ${nameCtrl.text} added to catalog & synced with Django!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
              child: const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }
}
