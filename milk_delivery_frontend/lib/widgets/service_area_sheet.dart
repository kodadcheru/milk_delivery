import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class ServiceAreaSheet extends StatefulWidget {
  final AppState state;

  const ServiceAreaSheet({super.key, required this.state});

  static void show(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ServiceAreaSheet(state: state),
    );
  }

  @override
  State<ServiceAreaSheet> createState() => _ServiceAreaSheetState();
}

class _ServiceAreaSheetState extends State<ServiceAreaSheet> {
  final TextEditingController _pincodeCtrl = TextEditingController();
  String? _checkResult;
  bool _isServiceable = false;

  void _checkPincode() {
    final pin = _pincodeCtrl.text.trim();
    if (pin.length < 6) {
      setState(() {
        _checkResult = 'Please enter a valid 6-digit PIN code';
        _isServiceable = false;
      });
      return;
    }

    final match = widget.state.serviceAreas.where((a) => a.pincodes.contains(pin)).firstOrNull;

    if (match != null && match.status == 'ACTIVE') {
      setState(() {
        _isServiceable = true;
        _checkResult = '🎉 Great news! We deliver fresh daily milk to ${match.name} from ${match.hubName}.';
      });
      widget.state.selectServiceArea(match);
    } else if (match != null && match.status == 'EXPANDING') {
      setState(() {
        _isServiceable = false;
        _checkResult = '🚀 ${match.name} is launching next week! Join the priority waitlist for ₹500 welcome credits.';
      });
    } else {
      setState(() {
        _isServiceable = false;
        _checkResult = '📍 PIN code $pin is currently outside our immediate morning route. We are expanding rapidly across Hyderabad!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.state.serviceAreas;
    final selected = widget.state.selectedServiceArea;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Delivery Service Area 📍',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Geofenced 05:30 AM morning doorstep delivery routes',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Pincode Quick Checker
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check Your Pincode Serviceability:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Enter 6-digit Pincode (e.g. 500033)',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          prefixIcon: const Icon(Icons.pin_drop_rounded, size: 18, color: Color(0xFF0D7C66)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _checkPincode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Text('Check', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                if (_checkResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isServiceable ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isServiceable ? const Color(0xFF10B981) : Colors.amber),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isServiceable ? Icons.check_circle_rounded : Icons.info_rounded,
                          color: _isServiceable ? const Color(0xFF10B981) : Colors.amber[800],
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _checkResult!,
                            style: TextStyle(
                              color: _isServiceable ? const Color(0xFF065F46) : Colors.amber[900],
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Active Service Area Clusters List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: areas.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final area = areas[idx];
                final isSelected = area.id == selected.id;
                final isActive = area.status == 'ACTIVE';

                return InkWell(
                  onTap: () {
                    if (isActive) {
                      widget.state.selectServiceArea(area);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0D7C66),
                          content: Text('📍 Switched delivery service zone to ${area.name}'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0284C7),
                          content: Text('🔔 You have been added to the priority waitlist for ${area.name}!'),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0D7C66).withValues(alpha: 0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  area.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF0D7C66), size: 16),
                                ],
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.15) : (area.status == 'EXPANDING' ? Colors.amber.withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? '🟢 ACTIVE' : (area.status == 'EXPANDING' ? '🟡 EXPANDING' : '🔴 WAITLIST'),
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF059669) : (area.status == 'EXPANDING' ? Colors.amber[900] : Colors.redAccent),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pincodes: ${area.pincodes} • ${area.radiusKm} km radius from ${area.hubName}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '🏢 ${area.popularSocieties}',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
