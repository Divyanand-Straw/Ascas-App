import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/localized_text.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

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
                  Icons.lock_outline_rounded,
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
                  'Unlock Thaai Seyali to continue.',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (service.enabled)
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
                const SizedBox(height: 14),
                TextField(
                  controller: _pinController,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Security PIN',
                    hintText: 'Enter 4-digit PIN',
                    counterText: '',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed:
                      service.isAuthenticating ||
                          _pinController.text.length != 4
                      ? null
                      : () async {
                          await service.unlockWithPin(_pinController.text);
                          if (mounted) setState(() {});
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: const LocalizedText('Unlock using Security PIN'),
                ),
                if (service.state == AppLockState.authenticationFailed)
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
