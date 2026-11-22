import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/presentation/new_patient/create_login_credentials_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const SplashScreen({super.key, this.authRepository});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final authRepository = widget.authRepository ?? AuthRepository.instance;
      final restored = await authRepository.restoreSession();
      if (!mounted || _navigationStarted) return;

      if (restored && authRepository.isAuthenticated) {
        final session = authRepository.currentSession;
        final pending = authRepository.pendingRegistration;
        if (session != null && pending?.userId == session.user.id) {
          _navigationStarted = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => buildPendingRegistrationScreen(
                registration: pending!,
                mobileNumber: session.user.phone,
              ),
            ),
          );
        } else if (session != null &&
            session.hasCompletedProfile &&
            session.profile != null) {
          _navigationStarted = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                patientName: session.profile!.fullName,
                patientId: session.profile!.clinicMrn ?? '',
                mobileNumber: session.user.phone,
                email: session.user.email ?? '',
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
    if (_navigationStarted) return;
    _navigationStarted = true;
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
                const LocalizedText(
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
