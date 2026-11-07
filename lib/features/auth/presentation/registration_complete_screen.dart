import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/locale_service.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class RegistrationCompleteScreen extends StatelessWidget {
  final String fullName;
  final String dateOfBirth;
  final String mobileNumber;
  final String preferredLanguage;
  final bool isExistingPatient;
  final String patientId;

  const RegistrationCompleteScreen({
    super.key,
    required this.fullName,
    required this.dateOfBirth,
    required this.mobileNumber,
    required this.preferredLanguage,
    this.isExistingPatient = false,
    this.patientId = '',
  });

  Widget _verificationItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 35, 25, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 35),
              Center(
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppColors.burgundy,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  isExistingPatient
                      ? 'ACCOUNT LINKED'
                      : 'REGISTRATION COMPLETE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  isExistingPatient
                      ? 'Your clinic record is linked'
                      : 'Welcome to Thaai Seyazhi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isExistingPatient
                    ? 'Your existing clinic record, identity, consent, and app security have been verified.'
                    : 'Your identity, consent, and app security have been verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _verificationItem('Mobile number verified'),
                    _verificationItem(
                      isExistingPatient
                          ? 'Existing clinic record linked'
                          : 'Patient access created',
                    ),
                    _verificationItem('Consent recorded securely'),
                    _verificationItem('App PIN protected'),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final language =
                        preferredLanguage == 'Tamil' ||
                            preferredLanguage == 'தமிழ்'
                        ? 'ta'
                        : 'en';
                    final accountId = patientId.isEmpty
                        ? mobileNumber
                        : patientId;
                    await LocaleService.setAccountLanguage(
                      accountId: accountId,
                      languageCode: language,
                    );
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardScreen(
                          patientName: fullName,
                          mobileNumber: mobileNumber,
                          dateOfBirth: dateOfBirth,
                          preferredLanguage: preferredLanguage,
                          accountId: accountId,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'Continue to patient dashboard',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
