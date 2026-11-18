import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final restored = await AuthRepository.instance.restoreSession();
      if (!mounted) return;

      if (restored) {
        final session = AuthRepository.instance.currentSession;
        if (session != null && session.hasCompletedProfile && session.profile != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                patientName: session.profile!.fullName,
                mobileNumber: session.user.phone,
                dateOfBirth: session.profile!.dob ?? '',
                preferredLanguage: session.profile!.preferredLanguage,
                accountId: session.user.id,
              ),
            ),
          );
        }
      }
    } catch (_) {
      // If session check fails, fall through to manual splash/onboarding
    }
  }

  void _onTap() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
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
                const Text(
                  'THAAI SEYAZHI',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'தாய் செயழி',
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
                  style: const TextStyle(
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
