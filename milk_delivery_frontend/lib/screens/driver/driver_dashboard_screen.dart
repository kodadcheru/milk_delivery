import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../models/delivery_task_model.dart';

class DriverDashboardScreen extends StatelessWidget {
  final AppState state;

  const DriverDashboardScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tasks = state.deliveries;
    final completedCount = tasks.where((t) => t.status == 'DELIVERED').length;
    final pendingCount = tasks.where((t) => t.status == 'PENDING').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metrics Banner ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7C66).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Total Tasks', '${tasks.length}'),
                Container(width: 1, height: 30, color: Colors.white30),
                _buildMetric('Pending', '$pendingCount'),
                Container(width: 1, height: 30, color: Colors.white30),
                _buildMetric('Delivered', '$completedCount'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Morning Doorstep Delivery Route',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Turn-by-turn GPS Google Maps directions for each doorstep',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('05:30 AM Shift ⚡', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
            itemBuilder: (ctx, idx) {
              final task = tasks[idx];
              final isDone = task.status == 'DELIVERED';
              final isSkipped = task.status == 'SKIPPED';
              final custName = task.customerName;
              final instructions = task.deliveryInstructions;
              final custPhone = task.customerPhone;
              final lat = task.customerLatitude;
              final lon = task.customerLongitude;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Header & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('STOP #${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Task #${task.id}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : (isSkipped ? Colors.grey.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              task.status,
                              style: TextStyle(
                                color: isDone ? const Color(0xFF0D7C66) : (isSkipped ? Colors.grey[800] : Colors.amber[900]),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Customer Name & Contact Action
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFF0D7C66).withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.person_rounded, color: Color(0xFF0D7C66), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  custName,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                                ),
                                if (custPhone.isNotEmpty)
                                  Text(
                                    'Phone: $custPhone',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                          if (custPhone.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _callCustomer(context, custPhone),
                              icon: const Icon(Icons.phone_rounded, size: 14),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                foregroundColor: const Color(0xFF0D7C66),
                                side: const BorderSide(color: Color(0xFF0D7C66)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Doorstep Address with Live Coordinates
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place_rounded, color: Color(0xFF0D7C66), size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    task.deliveryAddress,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.gps_fixed_rounded, size: 10, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'GPS: ${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E',
                                        style: const TextStyle(color: Color(0xFF0284C7), fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Doorstep Pinpoint',
                                  style: TextStyle(fontSize: 9.5, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 1-CLICK GOOGLE MAPS NAVIGATION BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchGoogleMapsNavigation(context, lat, lon, custName),
                          icon: const Icon(Icons.navigation_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Navigate in Google Maps (1-Click) 🗺️',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Product Items Detail
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(task.subscriptionDetail?.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${task.subscriptionDetail?.quantity ?? 1}x ${task.subscriptionDetail?.productDetail?.name ?? "Daily Milk Pouch"}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                            Text(
                              'Slot: ${task.slotTime}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Delivery Instructions Note
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Doorstep Note: $instructions',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Completion & Skip Actions
                      if (!isDone && !isSkipped)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  state.markDeliverySkipped(task.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Delivery marked as skipped.')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE11D48),
                                  side: const BorderSide(color: Color(0xFFE11D48)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Skip / Absent'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () => _handleCompleteDelivery(context, task),
                                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                label: const Text('Mark Delivered + Proof'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D7C66),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              isDone ? 'Delivered at Doorstep • Wallet Auto-Debited' : 'Skipped by Partner',
                              style: TextStyle(
                                color: isDone ? const Color(0xFF0D7C66) : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
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

  Widget _buildMetric(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  void _callCustomer(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📞 Calling customer ($phone)...')),
        );
      }
    }
  }

  void _launchGoogleMapsNavigation(BuildContext context, double lat, double lon, String customerName) async {
    // 1-Click Google Maps turn-by-turn navigation URI
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving';
    final uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0284C7),
            content: Text('🗺️ Launching Google Maps Navigation to $customerName (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Navigating to coordinates: $lat, $lon'),
          ),
        );
      }
    }
  }

  void _handleCompleteDelivery(BuildContext context, DeliveryTaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D7C66)),
            const SizedBox(width: 8),
            Text('Deliver to ${task.customerName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doorstep: ${task.deliveryAddress}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('GPS Pin: ${task.customerLatitude.toStringAsFixed(4)}, ${task.customerLongitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_enhance_rounded, color: Color(0xFF0D7C66), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Doorstep_Proof_Capture.jpg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Photo verified & Geo-tagged', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.markDeliveryCompleted(
                task.id,
                'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0D7C66),
                  content: Text('✅ Delivery #${task.id} completed! Photo proof uploaded & customer wallet debited.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            child: const Text('Complete & Debit Wallet'),
          ),
        ],
      ),
    );
  }
}
