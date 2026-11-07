import 'package:flutter/material.dart';

import '../localization/localized_text.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';

class BiometricLockScreen extends StatelessWidget {
  const BiometricLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BiometricService.instance;
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 88,
                    height: 88,
                  ),
                ),
                const SizedBox(height: 22),
                const Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.burgundy,
                  size: 64,
                ),
                const SizedBox(height: 14),
                LocalizedText(
                  'Authentication required',
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                LocalizedText(
                  'Unlock Thaai Seyazhi to continue.',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: service.isAuthenticating ? null : service.unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const LocalizedText('Unlock using Biometrics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!service.isAuthenticating)
                  const LocalizedText(
                    'Authentication failed or was cancelled. Try again.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
