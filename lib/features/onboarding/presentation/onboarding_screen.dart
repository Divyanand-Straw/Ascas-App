
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const OnboardingScreen({
    super.key,
    this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  final List<String> _illustrations = [
    'assets/images/appointment.png',
    'assets/images/treatment.png',
    'assets/images/records.png',
  ];

  final List<String> _titles = [
    'Care, right on schedule.',
    'Every step, with clarity.',
    'Your health, in one place.',
  ];

  final List<String> _descriptions = [
    'Book appointments, prepare for your visits, and keep your consultations organized in one place.',
    'Follow your treatment journey with clinic-confirmed milestones, updates, and guidance along the way.',
    'Keep your medical reports, prescriptions, and visit summaries organized and easy to access.',
  ];

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // LIGHT PINK UPPER HALF WITH CURVED BOTTOM

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.53,
              child: ClipPath(
                clipper: OnboardingCurveClipper(),
                child: Container(
                  color: AppColors.blushPink,
                ),
              ),
            ),

            Column(
              children: [
                // SKIP BUTTON

                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 20,
                      top: 8,
                    ),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.burgundy,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // ONBOARDING SLIDES

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 3,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                        ),
                        child: Column(
                          children: [
                            // ILLUSTRATION WITH WHITE CIRCULAR BACKGROUND

                            Expanded(
                              flex: 5,
                              child: Center(
                                child: Container(
                                  width: 245,
                                  height: 245,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Transform.translate(
                                      offset: Offset(
                                        index == 2 ? -12.0 : 0.0,
                                        index == 2 ? 12.0 : 0.0,
                                      ),
                                      child: Image.asset(
                                        _illustrations[index],
                                        width: 190,
                                        height: 190,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // TEXT AREA

                            Expanded(
                              flex: 4,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _titles[index],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryText,
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  Text(
                                    _descriptions[index],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // PAGE INDICATORS

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.burgundy
                            : AppColors.dustyPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // BUTTONS

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      // CONTINUE / GET STARTED BUTTON

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _currentPage == 2
                              ? _finishOnboarding
                              : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burgundy,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentPage == 2
                                ? 'Choose to begin'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // BACK BUTTON

                      if (_currentPage > 0) ...[
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: TextButton(
                            onPressed: _previousPage,
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                color: AppColors.burgundy,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 46),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// CURVED BACKGROUND CLIPPER

class OnboardingCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, size.height - 45);

    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 35,
      size.width,
      size.height - 45,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
