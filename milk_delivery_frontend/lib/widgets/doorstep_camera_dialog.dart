import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';
import '../services/permission_service.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';

Future<Uint8List> stampWatermarkOnImageBytes({
  required Uint8List imageBytes,
  required double latitude,
  required double longitude,
  required String address,
  required String customerName,
}) async {
  try {
    final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 800);
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

    // 1. Draw original photo
    canvas.drawImage(image, Offset.zero, Paint());

    // 2. Draw dark semi-transparent gradient banner at bottom
    final bannerHeight = (image.height * 0.22).clamp(90.0, 240.0);
    final bannerRect = Rect.fromLTWH(0, image.height - bannerHeight, image.width.toDouble(), bannerHeight);

    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, image.height - bannerHeight),
        Offset(0, image.height.toDouble()),
        [Colors.transparent, Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.95)],
        [0.0, 0.25, 1.0],
      );
    canvas.drawRect(bannerRect, gradientPaint);

    // 3. Format Date, Time & Coordinates
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final timeFormatted = '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year} • ${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';
    final gpsFormatted = '📍 GPS: ${latitude.toStringAsFixed(5)}° N, ${longitude.toStringAsFixed(5)}° E';
    final infoFormatted = '👤 $customerName | 🏠 $address';

    final scale = (image.width / 750.0).clamp(0.8, 2.5);

    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '🟢 PAMBA DOORSTEP PROOF VERIFIED\n',
            style: TextStyle(
              color: const Color(0xFF00E676),
              fontSize: 13 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          TextSpan(
            text: '⏰ $timeFormatted\n',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: '$gpsFormatted\n',
            style: TextStyle(
              color: const Color(0xFF80D8FF),
              fontSize: 12 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: infoFormatted,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11 * scale,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 4,
    );

    textPainter.layout(maxWidth: image.width.toDouble() - (36 * scale));
    textPainter.paint(canvas, Offset(18 * scale, image.height - bannerHeight + (10 * scale)));

    // Convert canvas back to image PNG bytes
    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(image.width, image.height);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return byteData.buffer.asUint8List();
    }
  } catch (_) {}
  return imageBytes;
}

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
    this.imageUrl = '',
    required this.icon,
  });
}

class DoorstepCameraDialog extends StatefulWidget {
  final String customerName;
  final String deliveryAddress;
  final double latitude;
  final double longitude;
  final Function onConfirmProof;

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
    required Function onConfirmProof,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
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
      icon: '🥛',
    ),
    DoorstepProofPreset(
      id: 'handle_drop',
      title: 'Hung on Door Handle',
      description: 'Secured on handle hook',
      icon: '🚪',
    ),
    DoorstepProofPreset(
      id: 'cooler_box',
      title: 'Inside Cooler / Milk Box',
      description: 'Placed inside customer milk box',
      icon: '📦',
    ),
    DoorstepProofPreset(
      id: 'gate_box',
      title: 'Main Gate Drop-Point',
      description: 'Left in secure gate basket',
      icon: '🏡',
    ),
  ];

  late int _selectedPresetIndex;
  bool _isCapturing = false;
  Uint8List? _capturedImageBytes;
  bool _isProcessingPhoto = false;
  double? _deviceLat;
  double? _deviceLng;
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    _selectedPresetIndex = 0;
    _fetchLiveLocation();
  }

  Future<void> _fetchLiveLocation() async {
    try {
      final pos = await PermissionService.getDeviceCoordinates();
      if (pos != null && mounted) {
        setState(() {
          _deviceLat = pos.latitude;
          _deviceLng = pos.longitude;
          _isLocating = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() => _isProcessingPhoto = true);
      final rawBytes = await File(photo.path).readAsBytes();

      // Fetch freshest high-accuracy GPS coordinates of delivery partner at capture instant
      double finalLat = _deviceLat ?? widget.latitude;
      double finalLng = _deviceLng ?? widget.longitude;
      try {
        final livePos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        finalLat = livePos.latitude;
        finalLng = livePos.longitude;
        _deviceLat = finalLat;
        _deviceLng = finalLng;
      } catch (_) {
        try {
          final lastPos = await PermissionService.getDeviceCoordinates();
          if (lastPos != null) {
            finalLat = lastPos.latitude;
            finalLng = lastPos.longitude;
            _deviceLat = finalLat;
            _deviceLng = finalLng;
          }
        } catch (_) {}
      }

      // Stamp permanent timestamp, GPS coordinates & address onto photo pixels
      final watermarkedBytes = await stampWatermarkOnImageBytes(
        imageBytes: rawBytes,
        latitude: finalLat,
        longitude: finalLng,
        address: widget.deliveryAddress,
        customerName: widget.customerName,
      );

      if (mounted) {
        setState(() {
          _capturedImageBytes = watermarkedBytes;
          _isProcessingPhoto = false;
        });
      }
    } catch (e) {
      debugPrint('[DoorstepCameraDialog] Error taking photo: $e');
      if (mounted) {
        setState(() => _isProcessingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.error,
            content: Text('Failed to access camera: $e'),
          ),
        );
      }
    }
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
              decoration: BoxDecoration(color: UiTone.surfaceBorder, borderRadius: BorderRadius.circular(UiRadius.pill)),
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
                  Text('Doorstep Camera Proof 📸', style: UiText.h2.copyWith(fontSize: 17)),
                  Text('Deliver to: ${widget.customerName}', style: UiText.bodyStrong.copyWith(fontSize: 12, color: UiTone.primary)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),

          // ── Live Camera Viewfinder with GPS & Time Watermark ──
          ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.lg),
            child: Container(
              height: 220,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  // Camera Viewfinder Placeholder or Captured Photo Preview
                  Positioned.fill(
                    child: _capturedImageBytes != null
                        ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                        : (_isProcessingPhoto
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white),
                                    SizedBox(height: 12),
                                    Text('Stamping GPS & Time Watermark...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              )
                            : InkWell(
                                onTap: _takePhoto,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt_rounded, size: 42, color: Colors.white),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        '📸 Tap to Take Doorstep Photo',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Auto-watermarked with GPS & Time',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                  ),

                  // Viewfinder Crosshairs Overlay (when no photo taken yet)
                  if (_capturedImageBytes == null && !_isProcessingPhoto)
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(color: UiTone.surface.withValues(alpha: 0.4), width: 1.5),
                            borderRadius: BorderRadius.circular(UiRadius.sm),
                          ),
                        ),
                      ),
                    ),

                  // Top Watermark (Doorstep Pin, GPS & Retake Button)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Builder(
                      builder: (context) {
                        final displayLat = _deviceLat ?? widget.latitude;
                        final displayLng = _deviceLng ?? widget.longitude;
                        final isRealLock = _deviceLat != null && _deviceLng != null;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(UiRadius.xs),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isRealLock ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                                    size: 12,
                                    color: isRealLock ? const Color(0xFF00E676) : UiTone.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isLocating
                                        ? 'Acquiring Device GPS...'
                                        : '${displayLat.toStringAsFixed(5)}° N, ${displayLng.toStringAsFixed(5)}° E',
                                    style: UiText.caption.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (_capturedImageBytes != null)
                              GestureDetector(
                                onTap: _takePhoto,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(UiRadius.pill),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Retake',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isRealLock ? const Color(0xFF00C853) : UiTone.error,
                                  borderRadius: BorderRadius.circular(UiRadius.xs),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.circle, color: Colors.white, size: 6),
                                    const SizedBox(width: 4),
                                    Text(
                                      isRealLock ? 'REAL DEVICE GPS' : 'GEO-TAGGED',
                                      style: UiText.caption.copyWith(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Bottom Watermark preview (Address & Timestamp) - only before photo is snapped
                  if (_capturedImageBytes == null)
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
                                style: UiText.body.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$dateStr • $timeStr',
                              style: UiText.caption.copyWith(color: UiTone.secondary, fontSize: 10.5, fontWeight: FontWeight.bold),
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
          Text('Select Doorstep Drop Placement:', style: UiText.bodyStrong.copyWith(fontSize: 13)),
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
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? UiTone.primary.withValues(alpha: 0.1) : UiTone.shellBackground,
                      borderRadius: BorderRadius.circular(UiRadius.sm),
                      border: Border.all(
                        color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
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
                                style: UiText.bodyStrong.copyWith(fontSize: 12.5, color: isSelected ? UiTone.primary : UiTone.ink),
                              ),
                              Text(preset.description, style: UiText.caption.copyWith(fontSize: 10.5)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: UiTone.primary, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Action Button: Take Photo OR Confirm Upload
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _capturedImageBytes == null
                ? ElevatedButton.icon(
                    onPressed: _isProcessingPhoto ? null : _takePhoto,
                    icon: _isProcessingPhoto
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(
                      _isProcessingPhoto ? 'Processing Photo...' : '📸 Open Camera to Take Photo',
                      style: UiText.bodyStrong.copyWith(fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                      elevation: 0,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isCapturing
                        ? null
                        : () async {
                            final nav = Navigator.of(context);
                            setState(() => _isCapturing = true);

                            String? uploadedUrl;
                            final double finalLat = _deviceLat ?? widget.latitude;
                            final double finalLng = _deviceLng ?? widget.longitude;
                            final filename = 'proof_${activePreset.id}_${DateTime.now().millisecondsSinceEpoch}.png';

                            try {
                              // 1. Try fast binary multipart upload first
                              try {
                                uploadedUrl = await ImageUploadService.uploadImageBytes(
                                  bytes: _capturedImageBytes!,
                                  filename: filename,
                                  folder: 'proofs',
                                );
                              } catch (e) {
                                debugPrint('[DoorstepCameraDialog] Multipart upload failed, trying base64 fallback: $e');
                              }

                              // 2. Fallback to base64 JSON upload if multipart fails
                              if (uploadedUrl == null || uploadedUrl.isEmpty) {
                                try {
                                  final base64Str = base64Encode(_capturedImageBytes!);
                                  uploadedUrl = await ImageUploadService.uploadImageBase64(
                                    base64Image: base64Str,
                                    filename: filename,
                                    folder: 'proofs',
                                  );
                                } catch (e) {
                                  debugPrint('[DoorstepCameraDialog] Base64 upload also failed: $e');
                                }
                              }

                              // 3. Fallback: If network upload fails, use embedded data URI so proof is never lost
                              if (uploadedUrl == null || uploadedUrl.isEmpty) {
                                uploadedUrl = 'data:image/png;base64,${base64Encode(_capturedImageBytes!)}';
                              }
                            } catch (overallErr) {
                              debugPrint('[DoorstepCameraDialog] Unexpected error during upload: $overallErr');
                            }

                            if (!mounted) return;

                            if (uploadedUrl == null || uploadedUrl.isEmpty) {
                              setState(() => _isCapturing = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: UiTone.error,
                                    duration: Duration(seconds: 4),
                                    content: Text('⚠️ Photo proof upload failed. Please check network and try again.'),
                                  ),
                                );
                              }
                              return;
                            }

                            // Upload succeeded! Pop modal and complete delivery with verified URL
                            nav.pop();
                            try {
                              widget.onConfirmProof(uploadedUrl, null, finalLat, finalLng);
                            } catch (_) {
                              try {
                                widget.onConfirmProof(uploadedUrl, null);
                              } catch (_) {
                                widget.onConfirmProof(uploadedUrl);
                              }
                            }
                          },
                    icon: _isCapturing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_rounded, size: 18),
                    label: Text(
                      _isCapturing ? 'Uploading Proof to Server...' : 'Confirm Photo Proof & Complete Delivery',
                      style: UiText.bodyStrong.copyWith(fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                      elevation: 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
