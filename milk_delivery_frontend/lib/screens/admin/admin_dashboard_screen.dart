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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Admin Web Console Launch Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7C66).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🖥️', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Operations Web Console',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'http://127.0.0.1:8000/admin-console/',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🌐 Open http://127.0.0.1:8000/admin-console/ in your browser for full Web Console!')),
                    );
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Web Portal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // ── Executive KPI Metrics Grid ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildKpiCard('Total Daily Demand', '${vol.toInt()} Units/Liters', Icons.water_drop_rounded, const Color(0xFF0D7C66)),
              _buildKpiCard('Today\'s Revenue', '₹${rev.toStringAsFixed(2)}', Icons.currency_rupee_rounded, const Color(0xFF0D7C66)),
              _buildKpiCard('Active Subscribers', '${widget.state.subscriptions.length} Users', Icons.people_alt_rounded, Colors.purple.shade700),
              _buildKpiCard('Today\'s Deliveries', '${widget.state.deliveries.length} Tasks', Icons.local_shipping_rounded, Colors.amber.shade900),
            ],
          ),
          const SizedBox(height: 24),

          // ── Delivery Partner Fleet Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Partner Fleet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Manage driver accounts & morning routes',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddDriverDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Driver'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF0D7C66), size: 20),
                    ),
                    title: const Text('Suresh Kumar (Primary Driver)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Phone: 9123456789 • Route: Jubilee & Banjara Hills', style: TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Text('ONLINE 🟢', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assigned Tasks: ${widget.state.deliveries.length} Deliveries', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      Text('Rating: 4.9 ★ (184 deliveries)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Dairy Demand Forecast breakdown ──
          const Text(
            'Morning Milk Procurement Forecast',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const Text(
            'Volume required from dairy processing plant for morning batch:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDemandRow('Farm Fresh A2 Cow Milk', '250 Liters (Pouch)', '71.4%'),
                  const Divider(height: 20),
                  _buildDemandRow('Pure Buffalo Milk (High Fat)', '120 Liters (Pouch)', '24.2%'),
                  const Divider(height: 20),
                  _buildDemandRow('Farm Fresh Set Curd (Dahi)', '45 Tubs (500g)', '4.4%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Catalog Management ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Catalog & Inventory',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Manage prices, stock status & 4 core categories',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddProductDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
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
              return Card(
                child: ListTile(
                  leading: Text(p.icon, style: const TextStyle(fontSize: 26)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${p.category.replaceAll('_', ' ')} • ₹${p.pricePerUnit} / ${p.unitQuantity}', style: const TextStyle(fontSize: 11)),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCatChip(String key, String label) {
    final isSelected = _catalogCategoryFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: const Color(0xFF0D7C66),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      onSelected: (val) {
        setState(() => _catalogCategoryFilter = key);
      },
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
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
            const SizedBox(height: 6),
            Text(
              val,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemandRow(String item, String volume, String pct) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(volume, style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(pct, style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 11)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
