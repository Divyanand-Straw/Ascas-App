import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../consent_privacy_screen.dart';
import '../app_security_screen.dart';
import '../../../../core/widgets/step_progress_bar.dart';

import '../../../../core/theme/app_colors.dart';

class ProfileConfirmationScreen extends StatelessWidget {
  final String fullName;
  final String dateOfBirth;
  final String mobileNumber;
  final String preferredLanguage;
  final String gender;
  final bool isExistingPatient;
  final String patientId;
  final String accountId;

  const ProfileConfirmationScreen({
    super.key,
    required this.fullName,
    required this.dateOfBirth,
    required this.mobileNumber,
    required this.preferredLanguage,
    this.gender = '',
    this.isExistingPatient = false,
    this.patientId = '',
    this.accountId = '',
  });

  String get _initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) {
      return '';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get _formattedDate {
    final parts = dateOfBirth.split('/');

    if (parts.length == 3) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }

    return dateOfBirth;
  }

  String get _maskedMobile {
    if (mobileNumber.length != 10) {
      return mobileNumber;
    }

    return '+91 •••••• ${mobileNumber.substring(6)}';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primaryText,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        LocalizedText(
                          'STEP 5 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        LocalizedText(
                          'Profile confirmation',
                          style: TextStyle(
                            color: AppColors.burgundy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const LocalizedText(
                      'Exit',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Divider(color: AppColors.divider, height: 1),

              const SizedBox(height: 16),
              const StepProgressBar(currentStep: 5),
              const SizedBox(height: 32),

              const LocalizedText(
                'IDENTITY VERIFIED',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              const LocalizedText(
                'Confirm your profile',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              const LocalizedText(
                'Confirm these details before access is linked.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.blushPink,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: AppColors.burgundy,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const LocalizedText(
                                'New Thaai Seyazhi patient',
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const Divider(color: AppColors.divider, height: 1),

                    _detailRow('Date of birth', _formattedDate),

                    const Divider(color: AppColors.divider, height: 1),

                    _detailRow('Mobile', _maskedMobile),

                    const Divider(color: AppColors.divider, height: 1),

                    _detailRow(
                      'Gender',
                      gender.isEmpty ? 'Not provided' : gender,
                    ),

                    const Divider(color: AppColors.divider, height: 1),

                    _detailRow('Language', preferredLanguage),

                    const Divider(color: AppColors.divider, height: 1),

                    _detailRow('Clinic', 'Thaai Seyazhi Clinic'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.blushPink.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: AppColors.burgundy,
                      size: 19,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: LocalizedText(
                        'Clinical information remains protected until you confirm identity and consent.',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => isExistingPatient
                            ? AppSecurityScreen(
                                fullName: fullName,
                                dateOfBirth: dateOfBirth,
                                mobileNumber: mobileNumber,
                                preferredLanguage: preferredLanguage,
                                gender: gender,
                                isExistingPatient: true,
                                patientId: patientId,
                                accountId: accountId,
                              )
                            : ConsentPrivacyScreen(
                                fullName: fullName,
                                dateOfBirth: dateOfBirth,
                                mobileNumber: mobileNumber,
                                preferredLanguage: preferredLanguage,
                                gender: gender,
                              ),
                      ),
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
                  child: const LocalizedText(
                    'Yes, this is me',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                    side: const BorderSide(color: AppColors.burgundy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const LocalizedText(
                    'Details are incorrect',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
