import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_tokens.dart';

class HomeStoryReels extends StatelessWidget {
  const HomeStoryReels({super.key});

  static const List<Map<String, String>> stories = [
    {
      'emoji': '🚜',
      'title': 'Vedic Farm',
      'subtitle': 'A2 Gir Cows',
      'badge': 'Live',
    },
    {
      'emoji': '🔬',
      'title': 'Lab Report',
      'subtitle': '0% Preservative',
      'badge': 'Certified',
    },
    {
      'emoji': '❄️',
      'title': '4°C Chilled',
      'subtitle': 'Fresh in 1hr',
      'badge': 'Cold Chain',
    },
    {
      'emoji': '♻️',
      'title': 'Glass Bottle',
      'subtitle': 'Zero Plastic',
      'badge': 'Eco',
    },
    {
      'emoji': '🌅',
      'title': '5:30 AM Drop',
      'subtitle': 'Doorstep Box',
      'badge': 'Daily',
    },
  ];

  void _showStoryModal(BuildContext context, Map<String, String> story) {
    AppTheme.hapticLight();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkSlate,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: UiTone.surface.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: UiTone.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppTheme.emeraldGradient,
                shape: BoxShape.circle,
                boxShadow: UiShadow.card,
              ),
              alignment: Alignment.center,
              child: Text(story['emoji']!, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),
            Text(
              story['title']!,
              style: const TextStyle(
                color: UiTone.surface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryMint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(UiRadius.sm),
                border: Border.all(color: AppTheme.primaryMint.withValues(alpha: 0.4)),
              ),
              child: Text(
                '⭐ ${story['badge']} Quality Assurance',
                style: const TextStyle(
                  color: AppTheme.primaryMint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Every drop of our ${story['title']} milk is ethically sourced directly from heritage Gir cows grazing freely on organic clover pastures. Processed and laboratory certified daily before 04:00 AM dispatch.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  AppTheme.hapticLight();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryMint,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                  elevation: 0,
                ),
                child: const Text(
                  'Explore Farm Fresh Products 🥛',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final s = stories[index];
          return GestureDetector(
            onTap: () => _showStoryModal(context, s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryMint,
                        AppTheme.primaryTeal,
                        AppTheme.accentAmber,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: UiShadow.card,
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.darkSlate,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(s['emoji']!, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  s['title']!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
