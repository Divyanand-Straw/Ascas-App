import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          color: AppColors.burgundy,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 126,
                  height: 126,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                LocalizedText(
                  'THAAI SEYALI',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 1),
                const LocalizedText(
                  'தாய் செயலி',
                  style: TextStyle(fontSize: 18, color: AppColors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.journeySupportedCare,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 80),
                Text(
                  l10n.tapToContinue,
                  style: TextStyle(
                    fontSize: 20,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
