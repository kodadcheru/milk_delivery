import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppState state;

  const AdminDashboardScreen({super.key, required this.state});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _catalogCategoryFilter = 'ALL';
  String _orderStatusFilter = 'ALL';
  List<Map<String, dynamic>> _driverList = [];
  bool _isLoadingDrivers = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoadingDrivers = true);
    final drivers = await ApiService.fetchFleet();
    if (mounted) {
      setState(() {
        _isLoadingDrivers = false;
        _driverList = drivers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vol = widget.state.totalDailyMilkVolume;
    final rev = widget.state.totalDailyRevenue;
    final activeSubsCount = widget.state.subscriptions.where((s) => s.status == 'ACTIVE').length;

    final filteredProducts = widget.state.products.where((p) {
      if (_catalogCategoryFilter == 'ALL') return true;
      final target = _catalogCategoryFilter.toLowerCase();
      final pCat = p.category.toLowerCase();
      final pCatId = p.categoryId?.toString() ?? '';
      return pCat == target || pCatId == target;
    }).toList();

    final filteredDeliveries = widget.state.deliveries.where((d) {
      return _orderStatusFilter == 'ALL' || d.status == _orderStatusFilter;
    }).toList();

    // ── Compute Dynamic Demand Forecast ──
    final Map<String, int> productDemandCounts = {};
    int grandTotalDemandUnits = 0;
    for (var s in widget.state.subscriptions) {
      final pName = s.productDetail?.name ?? 'A2 Desi Cow Milk';
      productDemandCounts[pName] = (productDemandCounts[pName] ?? 0) + s.quantity;
      grandTotalDemandUnits += s.quantity;
    }
    if (grandTotalDemandUnits == 0) grandTotalDemandUnits = 1;

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
                      Text(
                        '${ApiService.baseUrl.replaceAll('/api', '')}/admin-console/',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Build console URL from API base (strip /api suffix)
                    final apiBase = ApiService.baseUrl;
                    final baseHost = apiBase.endsWith('/api') ? apiBase.substring(0, apiBase.length - 4) : apiBase;
                    final consoleUrl = '$baseHost/admin-console/';
                    final uri = Uri.parse(consoleUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: const Color(0xFF0D7C66), content: Text('🌐 Open $consoleUrl in your browser')),
                      );
                    }
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
              _buildKpiCard('Total Daily Demand', '${vol.toInt()} Units/L', 'Live demand forecast', Icons.water_drop_rounded, const Color(0xFF0D7C66)),
              _buildKpiCard('Today\'s Revenue', '₹${rev.toStringAsFixed(2)}', 'Active subscription rev', Icons.currency_rupee_rounded, const Color(0xFF10B981)),
              _buildKpiCard('Active Subscribers', '$activeSubsCount Active', '${widget.state.subscriptions.length} total subs', Icons.people_alt_rounded, const Color(0xFF0284C7)),
              _buildKpiCard('Today\'s Deliveries', '${widget.state.deliveries.length} Drops', 'Scheduled morning drops', Icons.local_shipping_rounded, const Color(0xFFF59E0B)),
            ],
          ),

          const SizedBox(height: 20),

          // ── 3. ADMIN OPERATIONS TOOLBAR ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showBroadcastModal(context),
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: const Text('📢 Broadcast', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showStorefrontBannerDialog(context),
                  icon: const Icon(Icons.palette_rounded, size: 16),
                  label: const Text('🏪 Store Banner', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showWalletCreditDialog(context),
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                  label: const Text('⚡ Credit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── 4. DYNAMIC DELIVERY PARTNER FLEET ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Partner Fleet (${_driverList.length})',
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Real-time driver roster, status toggles & route assignments',
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

          if (_isLoadingDrivers)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF0D7C66))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _driverList.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final d = _driverList[idx];
                final isOnline = (d['is_online'] ?? true) == true;
                final dName = d['name'] ?? d['username'] ?? 'Driver Partner';
                final dPhone = d['phone']?.toString().isNotEmpty == true ? d['phone'].toString() : 'No phone';
                final dVehicle = d['vehicle_number'] ?? 'Scooter';
                final dRoute = d['route'] ?? 'Central Route';
                final dDrops = d['total_drops'] ?? widget.state.deliveries.length;
                final dRating = d['rating'] ?? 4.9;

                return Container(
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
                            color: isOnline
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.two_wheeler_rounded,
                            color: isOnline ? const Color(0xFF0D7C66) : Colors.grey,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          dName,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                        ),
                        subtitle: Text(
                          'Phone: $dPhone • $dVehicle\nRoute: $dRoute',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        trailing: InkWell(
                          onTap: () async {
                            final driverId = _driverList[idx]['id'];
                            final newStatus = isOnline ? 'INACTIVE' : 'ACTIVE';
                            final ok = await ApiService.updateDriverStatus(driverId, newStatus);
                            if (ok) {
                              setState(() {
                                _driverList[idx]['is_online'] = !isOnline;
                                _driverList[idx]['driver_status'] = newStatus;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isOnline ? const Color(0xFF10B981) : Colors.red,
                              ),
                            ),
                            child: Text(
                              isOnline ? 'ONLINE 🟢' : 'OFFLINE 🔴',
                              style: TextStyle(
                                color: isOnline ? const Color(0xFF0D7C66) : Colors.red[700],
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Assigned Route Drops: $dDrops Deliveries',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Rating: $dRating ★',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 22),

          // ── 5. DYNAMIC DAIRY DEMAND FORECAST BREAKDOWN ──
          const Text(
            'Morning Milk Procurement Forecast',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
          ),
          const SizedBox(height: 2),
          const Text(
            'Calculated dynamically from active morning customer subscriptions:',
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
            child: productDemandCounts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No active subscriptions yet. Demand forecast will appear when customers subscribe.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  )
                : Column(
                    children: productDemandCounts.entries.map((entry) {
                      final pName = entry.key;
                      final units = entry.value;
                      final double pct = units / grandTotalDemandUnits;
                      final pctStr = '${(pct * 100).toStringAsFixed(1)}%';
                      final color = pName.toLowerCase().contains('cow') || pName.toLowerCase().contains('a2')
                          ? const Color(0xFF0D7C66)
                          : (pName.toLowerCase().contains('buffalo') ? const Color(0xFF0284C7) : const Color(0xFFF59E0B));

                      return Column(
                        children: [
                          _buildDemandRow(pName, '$units Units / Liters Required', pctStr, pct, color),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                        ],
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 22),

          // ── 6. REAL-TIME ORDERS & DELIVERIES COMMAND TABLE ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Deliveries & Drops (${filteredDeliveries.length})',
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Monitor doorstep photo proofs & mark drop statuses',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: _orderStatusFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Drops', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending 🕒', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 'DELIVERED', child: Text('Delivered 🟢', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 'SKIPPED', child: Text('Skipped 🔴', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _orderStatusFilter = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (filteredDeliveries.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No delivery drops matching selected filter', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDeliveries.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final d = filteredDeliveries[idx];
                final isDelivered = d.status == 'DELIVERED';
                final isSkipped = d.status == 'SKIPPED';
                final custName = d.customerName.isNotEmpty ? d.customerName : 'Customer #${d.id}';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDelivered
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isSkipped ? Colors.red.withValues(alpha: 0.15) : const Color(0xFF0D7C66).withValues(alpha: 0.15)),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        d.subscriptionDetail?.productDetail?.icon ?? '🥛',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      custName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d.subscriptionDetail?.productDetail?.name ?? 'A2 Cow Milk'} (${d.subscriptionDetail?.quantity ?? 1}x)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Date: ${d.deliveryDate} • Slot: ${d.slotTime}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDelivered
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : (isSkipped ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          d.status,
                          style: TextStyle(
                            color: isDelivered
                                ? const Color(0xFF0D7C66)
                                : (isSkipped ? Colors.red[700] : Colors.amber[900]),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      onSelected: (val) {
                        if (val == 'DELIVERED') {
                          widget.state.markDeliveryCompleted(d.id, '');
                        } else if (val == 'SKIPPED') {
                          widget.state.markDeliverySkipped(d.id);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'DELIVERED', child: Text('Mark Delivered 🟢')),
                        const PopupMenuItem(value: 'SKIPPED', child: Text('Mark Skipped 🔴')),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 22),

          // ── 7. CATALOG & INVENTORY MANAGEMENT ──
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

          // Dynamic Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCatChip('ALL', 'All Items (${widget.state.products.length})'),
                const SizedBox(width: 8),
                if (widget.state.categories.isNotEmpty)
                  ...widget.state.categories.where((c) => c.isActive).map((c) {
                    final matchingCount = widget.state.products.where((p) =>
                      p.category.toLowerCase() == c.name.toLowerCase() ||
                      p.category.toLowerCase() == c.slug.toLowerCase() ||
                      p.categoryId == c.id
                    ).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCatChip(c.name, '${c.icon} ${c.name} ($matchingCount)'),
                    );
                  })
                else ...[
                  _buildCatChip('MILK', '🥛 Milk'),
                  const SizedBox(width: 8),
                  _buildCatChip('MEAT', '🥩 Meat'),
                  const SizedBox(width: 8),
                  _buildCatChip('EGGS', '🥚 Eggs'),
                  const SizedBox(width: 8),
                  _buildCatChip('WATER_CAN', '💧 Water Can'),
                ],
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
                    onChanged: (val) async {
                      final ok = await ApiService.toggleProductStock(p.id);
                      if (ok) {
                        await widget.state.reloadAllData();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? '${p.name} stock status toggled.' : '❌ Failed to toggle stock.')),
                        );
                      }
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
            value: pctValue.clamp(0.01, 1.0),
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showBroadcastModal(BuildContext context) {
    final titleCtrl = TextEditingController(text: '📢 Morning Batch Dispatch Alert');
    final msgCtrl = TextEditingController(text: 'All 06:00 AM morning milk & water drops are certified and on schedule.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('📢', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('System Alert Broadcast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Publish an operational announcement to all customers and delivery drivers.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Broadcast Title', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: msgCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Message Body', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.state.sendSystemBroadcast(titleCtrl.text, msgCtrl.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Color(0xFF0D7C66), content: Text('📢 Broadcast published to all users!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            child: const Text('Publish Broadcast'),
          ),
        ],
      ),
    );
  }

  void _showWalletCreditDialog(BuildContext context) {
    final userIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '500');
    final descCtrl = TextEditingController(text: 'Admin Wallet Credit');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('⚡', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Manual Wallet Adjustment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Credit or adjust customer prepaid milk wallet balance directly.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(controller: userIdCtrl, decoration: const InputDecoration(labelText: 'Customer User ID', border: OutlineInputBorder(), hintText: 'Enter customer ID number'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Reason / Description', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = int.tryParse(userIdCtrl.text);
              if (uid == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.red, content: Text('❌ Please enter a valid Customer User ID')),
                );
                return;
              }
              Navigator.pop(ctx);
              final amt = double.tryParse(amountCtrl.text) ?? 500.0;
              final ok = await ApiService.adminCreditWallet(userId: uid, amount: amt, description: descCtrl.text);
              if (ok) {
                await widget.state.reloadAllData();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: ok ? const Color(0xFF0D7C66) : Colors.red,
                    content: Text(ok ? '⚡ ₹${amt.toStringAsFixed(0)} credited to customer #$uid wallet!' : '❌ Failed to credit wallet. Check user ID.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            child: const Text('Credit Wallet'),
          ),
        ],
      ),
    );
  }

  void _showAddDriverDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();

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
            TextField(controller: vehicleCtrl, decoration: const InputDecoration(labelText: 'Vehicle & Route (e.g. Scooter)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.createDriver(
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                vehicleNumber: vehicleCtrl.text,
              );
              // Reload drivers from API instead of inserting fake local data
              await _loadDrivers();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0D7C66),
                    content: Text('🛵 Driver ${nameCtrl.text} (${phoneCtrl.text}) registered! Enabled for Driver Login.'),
                  ),
                );
              }
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
    final activeCats = widget.state.categories.where((c) => c.isActive).toList();
    String selectedCategory = activeCats.isNotEmpty ? activeCats.first.name : 'MILK';

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
                  items: activeCats.isNotEmpty
                      ? activeCats
                          .map((c) => DropdownMenuItem(
                                value: c.name,
                                child: Text('${c.icon} ${c.name}'),
                              ))
                          .toList()
                      : const [
                          DropdownMenuItem(value: 'MILK', child: Text('🥛 Fresh Milk & Dairy')),
                          DropdownMenuItem(value: 'MEAT', child: Text('🥩 Meat & Poultry')),
                          DropdownMenuItem(value: 'EGGS', child: Text('🥚 Farm Eggs')),
                          DropdownMenuItem(value: 'WATER_CAN', child: Text('💧 Water Cans')),
                        ],
                  onChanged: (val) => setDialogState(() => selectedCategory = val ?? (activeCats.isNotEmpty ? activeCats.first.name : 'MILK')),
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
                final matchedCat = activeCats.where((c) => c.name.toLowerCase() == selectedCategory.toLowerCase()).firstOrNull;
                widget.state.addNewProduct(
                  nameCtrl.text,
                  descCtrl.text,
                  p,
                  qtyCtrl.text,
                  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
                  category: selectedCategory,
                  categoryId: matchedCat?.id,
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

  void _showStorefrontBannerDialog(BuildContext context) {
    final sf = widget.state.storefrontConfig;
    final bannerUrlCtrl = TextEditingController(text: sf.rawBannerImageUrl ?? sf.bannerImageUrl);
    final headlineCtrl = TextEditingController(text: sf.headline);
    final subtitleCtrl = TextEditingController(text: sf.subtitle);
    final dispatchTagCtrl = TextEditingController(text: sf.dispatchTag);
    final promoChipCtrl = TextEditingController(text: sf.promoChip);
    final ctaCtrl = TextEditingController(text: sf.ctaText);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🏪 Storefront & Banner Config', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top Hero Banner Image URL (Cloud/Unsplash/Direct):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: bannerUrlCtrl,
                  decoration: const InputDecoration(
                    hintText: 'https://images.unsplash.com/...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Hero Headline:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: headlineCtrl,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                const Text('Subtitle & Value Prop:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: subtitleCtrl,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dispatch Tag:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(controller: dispatchTagCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Promo Chip:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(controller: promoChipCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('CTA Text:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctaCtrl,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await widget.state.updateStorefrontSettings(
                  bannerImageUrl: bannerUrlCtrl.text.trim(),
                  headline: headlineCtrl.text.trim(),
                  subtitle: subtitleCtrl.text.trim(),
                  dispatchTag: dispatchTagCtrl.text.trim(),
                  promoChip: promoChipCtrl.text.trim(),
                  ctaText: ctaCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '✅ Storefront Banner & Branding updated on live server!' : '❌ Failed to update storefront.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
              child: const Text('Publish Banner'),
            ),
          ],
        ),
      ),
    );
  }
}
