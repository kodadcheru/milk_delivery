import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class HomeServingSoonView extends StatefulWidget {
  final AppState state;
  final VoidCallback onSelectZoneTap;

  const HomeServingSoonView({
    super.key,
    required this.state,
    required this.onSelectZoneTap,
  });

  @override
  State<HomeServingSoonView> createState() => _HomeServingSoonViewState();
}

class _HomeServingSoonViewState extends State<HomeServingSoonView> {
  bool _isSubmitting = false;
  bool _hasRequested = false;

  @override
  Widget build(BuildContext context) {
    final areaName = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;
    final cityOrTown = widget.state.currentCityOrTown;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Text('🚚', style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 14),
          Text(
            widget.state.isTelugu
                ? 'త్వరలో మీ ప్రాంతంలో సేవలందిస్తాము! 🚀'
                : 'We are Serving Soon in Your Area! 🚀',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: UiTone.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.state.isTelugu
                ? '"$areaName" వద్ద ఉదయం 05:30 డెలివరీ ఇంకా ప్రారంభం కాలేదు. మీరు మా ఉత్పత్తులను క్రింద చూడవచ్చు లేదా యాక్టివ్ హబ్ జోన్‌ను ఎంచుకోవచ్చు.'
                : 'Doorstep 05:30 AM delivery is not yet operational at "$areaName". You can still browse our products below, or select an active hub zone.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),

          // Operational Hub Badges
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.state.isTelugu ? '📍 ప్రస్తుతం పనిచేస్తున్న డెలివరీ హబ్‌లు:' : '📍 Active Operational Delivery Hubs:',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                if (widget.state.locationHubs.isNotEmpty)
                  ...widget.state.locationHubs.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${h['name']} (${double.tryParse(h['coverage_radius_km']?.toString() ?? '8.5') ?? 8.5} km Radius)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: UiTone.softText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.state.primaryHub['name'] ?? "Central Operations Hub"} (8.5 km Radius)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: UiTone.softText),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Select Zone Action ──
          InkWell(
            key: const ValueKey('select_zone_btn'),
            onTap: widget.onSelectZoneTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: UiTone.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: UiTone.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.state.isTelugu ? '📍 యాక్టివ్ హబ్ ప్రాంతానికి మారండి' : '📍 Switch to Operational Hub Area',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Notify Me / Expansion Request Button (Service-Mobile Pattern) ──
          _hasRequested
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.state.isTelugu
                              ? 'మీ ఆసక్తి నమోదు చేయబడింది! ఇక్కడ డెలివరీలు ప్రారంభమైనప్పుడు మీకు తెలియజేస్తాము.'
                              : 'Interest Recorded! We\'ll notify you when early morning drops start here.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                )
              : InkWell(
                  key: const ValueKey('notify_me_btn'),
                  onTap: _isSubmitting
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          await widget.state.requestCoverageExpansion();
                          if (mounted) {
                            setState(() {
                              _isSubmitting = false;
                              _hasRequested = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: UiTone.primary,
                                content: Text(widget.state.isTelugu
                                    ? '🔔 ధన్యవాదాలు! $cityOrTown కోసం మీ ఆసక్తి నమోదైంది.'
                                    : '🔔 Thanks! We recorded your interest for $cityOrTown.'),
                              ),
                            );
                          }
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: UiTone.primary, width: 1.3),
                    ),
                    alignment: Alignment.center,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.primary),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.notifications_active_rounded, size: 16, color: UiTone.primary),
                              const SizedBox(width: 8),
                              Text(
                                widget.state.isTelugu
                                    ? 'ఇక్కడ డెలివరీ ప్రారంభమైనప్పుడు తెలియజేయండి'
                                    : 'Notify Me When Delivery Launches Here',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: UiTone.primary),
                              ),
                            ],
                          ),
                  ),
                ),
        ],
      ),
    );
  }
}
