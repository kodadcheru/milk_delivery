import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: UiTone.softText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: const [
                  _OnboardingSlide(
                    icon: Icons.water_drop_rounded,
                    title: 'Farm-Fresh Milk at Your Doorstep',
                    subtitle: 'Pure, natural milk from local farms delivered fresh every morning.',
                  ),
                  _OnboardingSlide(
                    icon: Icons.calendar_month_rounded,
                    title: 'Subscribe & Save',
                    subtitle: 'Set a daily, alternate-day, or custom schedule. Skip or pause anytime.',
                  ),
                  _OnboardingSlide(
                    icon: Icons.local_shipping_rounded,
                    title: 'Track Your Delivery Live',
                    subtitle: 'Real-time driver tracking from farm to your doorstep.',
                  ),
                ],
              ),
            ),
            // Bottom Section (Dots and Button)
            Padding(
              padding: UiSpace.screen,
              child: Column(
                children: [
                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? UiTone.primary : UiTone.border,
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: UiSpace.xxl),
                  // Get Started / Next Button
                  if (_currentPage == 2)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: UiGradient.primary,
                          borderRadius: BorderRadius.circular(UiRadius.md),
                          boxShadow: UiShadow.glowPrimary,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(UiRadius.md),
                            onTap: widget.onComplete,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: Text(
                                  'Get Started',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _nextPage,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            color: UiTone.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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

class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: UiGradient.primary,
              shape: BoxShape.circle,
              boxShadow: UiShadow.glowPrimary,
            ),
            child: Icon(
              icon,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: UiSpace.xxxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: UiTone.ink,
            ),
          ),
          const SizedBox(height: UiSpace.lg),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: UiTone.softText,
            ),
          ),
        ],
      ),
    );
  }
}
