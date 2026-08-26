import 'package:flutter/material.dart';
import '../theme/ui_tokens.dart';
import 'common/app_cached_image.dart';

class DoorstepProofModal extends StatelessWidget {
  final String imageUrl;
  final String orderId;
  final String deliveryDate;
  final String slotTime;
  final String address;
  final String driverName;

  const DoorstepProofModal({
    super.key,
    required this.imageUrl,
    this.orderId = '#MD-4821',
    this.deliveryDate = 'Today',
    this.slotTime = '05:30 AM - 07:00 AM',
    this.address = 'Doorstep Delivery Location',
    this.driverName = 'Assigned Partner',
  });

  static void show(
    BuildContext context, {
    required String imageUrl,
    String orderId = '#MD-4821',
    String deliveryDate = 'Today',
    String slotTime = '05:30 AM - 07:00 AM',
    String address = 'Doorstep Delivery Location',
    String driverName = 'Assigned Partner',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => DoorstepProofModal(
        imageUrl: imageUrl,
        orderId: orderId,
        deliveryDate: deliveryDate,
        slotTime: slotTime,
        address: address,
        driverName: driverName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Doorstep Delivery Proof',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '$orderId • $deliveryDate',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Photo with GPS & Timestamp Watermark
            ClipRRect(
              child: AspectRatio(
                aspectRatio: 1.1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3.0,
                      child: AppCachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: '🥛',
                        fallbackBgColor: const Color(0xFF1E293B),
                        memCacheWidth: 800,
                        memCacheHeight: 800,
                      ),
                    ),

                    // Top Gradient Vignette
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Watermark HUD
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 6),
                                Text(
                                  'Delivered: $deliveryDate • $slotTime',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('GPS LOCKED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFF43F5E)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.badge_rounded, size: 13, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  'Partner: $driverName',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
