import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../providers/app_state.dart';

class ProductDetailSheet extends StatefulWidget {
  final ProductModel product;
  final AppState state;

  const ProductDetailSheet({super.key, required this.product, required this.state});

  static void show(BuildContext context, ProductModel product, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ProductDetailSheet(product: product, state: state),
    );
  }

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _qty = 1;
  String _schedule = 'DAILY';

  @override
  Widget build(BuildContext context) {
    final item = widget.product;
    final itemTotal = item.pricePerUnit * _qty;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.84,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Icon Container with Badges
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF0D7C66).withValues(alpha: 0.1), const Color(0xFF10B981).withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D7C66),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.badgeText,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text('${item.rating} ★ (1.2k Reviews)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.brown)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(item.icon, style: const TextStyle(fontSize: 64)),
                          const SizedBox(height: 6),
                          Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${item.unitQuantity} • ₹${item.pricePerUnit.toStringAsFixed(0)} / pack', style: TextStyle(color: Colors.grey[700], fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Lab Quality & Purity Assurance Certificate ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_rounded, color: Color(0xFF0D7C66), size: 18),
                              SizedBox(width: 6),
                              Text('Certified Purity & Lab Test Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0D7C66))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPurityMetric('🧪 0% Adulterants', 'Chemical Free'),
                              _buildPurityMetric('❄️ < 4°C Chilled', 'Direct Cold Chain'),
                              _buildPurityMetric('🔬 24 Tests Passed', 'FSSAI Certified'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Farm Origin Traceability ──
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF0D7C66),
                            radius: 15,
                            child: Icon(Icons.pin_drop_rounded, color: Colors.white, size: 15),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Farm Origin & Freshness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                Text(item.farmOrigin, style: TextStyle(color: Colors.grey[700], fontSize: 10.5)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Milked Today 🟢', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Description ──
                    const Text('Product Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text(
                      item.description.isNotEmpty ? item.description : 'Sourced fresh daily from ethical, free-grazing farms and delivered in temperature-controlled vans to your doorstep before 6:00 AM.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 14),

                    // ── Quantity Configurator ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quantity per Delivery:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF0D7C66)),
                            ),
                            Text('$_qty Packs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            IconButton(
                              onPressed: () => setState(() => _qty++),
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0D7C66)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Subscription Schedule Configurator ──
                    const Text('Subscription Schedule:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildScheduleChoice('DAILY', 'Everyday 🥛', _schedule, (val) => setState(() => _schedule = val)),
                        const SizedBox(width: 6),
                        _buildScheduleChoice('ALTERNATE', 'Alternate 🟡', _schedule, (val) => setState(() => _schedule = val)),
                        const SizedBox(width: 6),
                        _buildScheduleChoice('WEEKDAYS', 'Weekdays 💼', _schedule, (val) => setState(() => _schedule = val)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Dual CTA Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.state.addToCart(item);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 1),
                            backgroundColor: const Color(0xFF0F172A),
                            content: Text('🛒 Added 1x ${item.name} to Cart!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0D7C66), size: 16),
                      label: const Text('Add to Cart', style: TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0D7C66), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.state.createNewSubscription(item, _qty, _schedule);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF0D7C66),
                            content: Text('🎉 Subscribed to ${item.name}! First delivery tomorrow 06:00 AM.'),
                          ),
                        );
                        widget.state.setTab(1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Subscribe • ₹${itemTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurityMetric(String title, String subtitle) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0D7C66))),
        const SizedBox(height: 1),
        Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildScheduleChoice(String val, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == val;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
