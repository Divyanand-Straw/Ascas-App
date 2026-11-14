import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import 'app_security_screen.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../../../core/theme/app_colors.dart';

class ConsentPrivacyScreen extends StatefulWidget {
  final String fullName;
  final String dateOfBirth;
  final String mobileNumber;
  final String preferredLanguage;
  final String gender;
  final bool isExistingPatient;
  final String patientId;
  final String accountId;

  const ConsentPrivacyScreen({
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

  @override
  State<ConsentPrivacyScreen> createState() => _ConsentPrivacyScreenState();
}

class _ConsentPrivacyScreenState extends State<ConsentPrivacyScreen> {
  bool _requiredConsent = false;
  bool _partnerAccess = false;

  Widget _informationCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.blushPink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.burgundy, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
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
          padding: const EdgeInsets.fromLTRB(25, 12, 25, 25),
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
                          'STEP 6 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        LocalizedText(
                          'Consent & privacy',
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
              const StepProgressBar(currentStep: 6),
              const SizedBox(height: 32),

              const LocalizedText(
                'CONSENT & PRIVACY',
                style: TextStyle(
                  color: AppColors.dustyPink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              const LocalizedText(
                'You control your information',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              const LocalizedText(
                'Required patient consent is separate from optional partner sharing.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              _informationCard(
                icon: Icons.history,
                title: 'Digital consent history',
                description: 'Consent changes are recorded with date and time.',
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _requiredConsent,
                      onChanged: (value) {
                        setState(() {
                          _requiredConsent = value ?? false;
                        });
                      },
                      activeColor: AppColors.burgundy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            'Required terms and privacy consent',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          LocalizedText(
                            'Allow secure processing needed for Thaai Seyali patient services.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LocalizedText(
                            'Optional partner access',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const LocalizedText(
                            'Enable a revocable partner invitation after setup.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _partnerAccess
                                ? 'Partner access enabled'
                                : 'You can revoke access later.',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _partnerAccess,
                      onChanged: (value) {
                        setState(() {
                          _partnerAccess = value;
                        });
                      },
                      activeThumbColor: AppColors.burgundy,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: LocalizedText(
                          'Terms and privacy information will be available here.',
                        ),
                      ),
                    );
                  },
                  child: const LocalizedText(
                    'Read Terms, Privacy and Consent',
                    style: TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _requiredConsent
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AppSecurityScreen(
                                fullName: widget.fullName,
                                dateOfBirth: widget.dateOfBirth,
                                mobileNumber: widget.mobileNumber,
                                preferredLanguage: widget.preferredLanguage,
                                gender: widget.gender,
                                isExistingPatient: widget.isExistingPatient,
                                patientId: widget.patientId,
                                accountId: widget.accountId,
                              ),
                            ),
                          );
                        }
                      : null,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    disabledBackgroundColor: AppColors.divider,
                    foregroundColor: AppColors.white,
                    disabledForegroundColor: AppColors.secondaryText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const LocalizedText(
                    'Accept and continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
