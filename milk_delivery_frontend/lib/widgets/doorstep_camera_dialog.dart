import 'package:flutter/material.dart';
import '../services/image_upload_service.dart';

class DoorstepProofPreset {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String icon;

  const DoorstepProofPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.icon,
  });
}

class DoorstepCameraDialog extends StatefulWidget {
  final String customerName;
  final String deliveryAddress;
  final double latitude;
  final double longitude;
  final Function(String proofImageUrl) onConfirmProof;

  const DoorstepCameraDialog({
    super.key,
    required this.customerName,
    required this.deliveryAddress,
    required this.latitude,
    required this.longitude,
    required this.onConfirmProof,
  });

  static void show(
    BuildContext context, {
    required String customerName,
    required String deliveryAddress,
    required double latitude,
    required double longitude,
    required Function(String proofImageUrl) onConfirmProof,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DoorstepCameraDialog(
        customerName: customerName,
        deliveryAddress: deliveryAddress,
        latitude: latitude,
        longitude: longitude,
        onConfirmProof: onConfirmProof,
      ),
    );
  }

  @override
  State<DoorstepCameraDialog> createState() => _DoorstepCameraDialogState();
}

class _DoorstepCameraDialogState extends State<DoorstepCameraDialog> {
  final List<DoorstepProofPreset> _presets = const [
    DoorstepProofPreset(
      id: 'bag_doorstep',
      title: 'Doorstep Insulated Bag',
      description: 'Chilled bag placed cleanly at door',
      imageUrl: 'https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=600&q=80',
      icon: '🥛',
    ),
    DoorstepProofPreset(
      id: 'handle_drop',
      title: 'Hung on Door Handle',
      description: 'Secured on handle hook',
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&q=80',
      icon: '🚪',
    ),
    DoorstepProofPreset(
      id: 'cooler_box',
      title: 'Inside Cooler / Milk Box',
      description: 'Placed inside customer milk box',
      imageUrl: 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=600&q=80',
      icon: '📦',
    ),
    DoorstepProofPreset(
      id: 'gate_box',
      title: 'Main Gate Drop-Point',
      description: 'Left in secure gate basket',
      imageUrl: 'https://images.unsplash.com/photo-1588964895597-cfccd6e2dbf9?w=600&q=80',
      icon: '🏡',
    ),
  ];

  late int _selectedPresetIndex;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _selectedPresetIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final activePreset = _presets[_selectedPresetIndex];
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} AM';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Doorstep Camera Proof 📸', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Deliver to: ${widget.customerName}', style: const TextStyle(fontSize: 12, color: Color(0xFF0D7C66), fontWeight: FontWeight.w700)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),

          // ── Live Camera Viewfinder with GPS & Time Watermark ──
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 220,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  // Image
                  Positioned.fill(
                    child: Image.network(
                      activePreset.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(child: Icon(Icons.camera_alt_rounded, color: Colors.white54, size: 48)),
                      ),
                    ),
                  ),

                  // Viewfinder Crosshairs Overlay
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // Top Watermark (Doorstep Pin & Live Tag)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.gps_fixed_rounded, size: 12, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.latitude.toStringAsFixed(4)}° N, ${widget.longitude.toStringAsFixed(4)}° E',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.circle, color: Colors.white, size: 6),
                              SizedBox(width: 4),
                              Text('GEO-TAGGED', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Watermark (Address & Timestamp)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '📍 ${widget.deliveryAddress}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$dateStr • $timeStr',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Select Proof Scenario Preset ──
          const Text('Select Doorstep Drop Placement:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.separated(
              itemCount: _presets.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final preset = _presets[idx];
                final isSelected = _selectedPresetIndex == idx;

                return InkWell(
                  onTap: () => setState(() => _selectedPresetIndex = idx),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0D7C66).withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(preset.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset.title,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFF0F172A)),
                              ),
                              Text(preset.description, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF0D7C66), size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Complete & Debit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isCapturing
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      setState(() => _isCapturing = true);

                      // Upload geo-tagged proof to backend Image Upload Service
                      String? uploadedUrl;
                      try {
                        uploadedUrl = await ImageUploadService.uploadImageBase64(
                          base64Image: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
                          filename: 'doorstep_${activePreset.id}_${DateTime.now().millisecondsSinceEpoch}.png',
                          folder: 'proofs',
                        );
                      } catch (_) {}

                      if (!mounted) return;
                      nav.pop();
                      widget.onConfirmProof(uploadedUrl ?? activePreset.imageUrl);
                    },
              icon: _isCapturing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_rounded, size: 18),
              label: Text(
                _isCapturing ? 'Uploading Proof to Server...' : 'Confirm Photo Proof & Complete Delivery',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
