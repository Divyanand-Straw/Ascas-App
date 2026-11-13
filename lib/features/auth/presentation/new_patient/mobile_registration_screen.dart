import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import 'package:flutter/services.dart';

import '../../../../core/widgets/step_progress_bar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'new_patient_otp_screen.dart';
import '../linked_member/linked_member_otp_screen.dart';

class MobileRegistrationScreen extends StatefulWidget {
  final String patientType;

  const MobileRegistrationScreen({super.key, required this.patientType});

  @override
  State<MobileRegistrationScreen> createState() =>
      _MobileRegistrationScreenState();
}

class _MobileRegistrationScreenState extends State<MobileRegistrationScreen> {
  final TextEditingController _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  void _continue() {
    final mobile = _mobileController.text.trim();
    final type = widget.patientType.trim().toLowerCase();

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Enter a valid 10-digit mobile number.'),
        ),
      );
      return;
    }

    if (type.contains('new patient')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewPatientOtpScreen(mobileNumber: mobile),
        ),
      );
    } else if (type.contains('existing')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewPatientOtpScreen(
            mobileNumber: mobile,
            fromExistingPatient: true,
          ),
        ),
      );
    } else if (type.contains('linked member')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LinkedMemberOtpScreen(mobileNumber: mobile),
        ),
      );
    } else {
      debugPrint('Unknown patient type: ${widget.patientType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 20),
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
                  Expanded(
                    child: Column(
                      children: [
                        LocalizedText(
                          'STEP 2 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.patientType.contains('Existing')
                              ? l10n.existingPatientMobile
                              : l10n.mobileRegistration,
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
                    child: Text(
                      l10n.exit,
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
              const StepProgressBar(currentStep: 2),
              const SizedBox(height: 28),
              Text(
                widget.patientType.contains('Existing')
                    ? l10n.existingPatient
                    : l10n.mobileRegistration,
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.patientType.contains('Existing')
                    ? l10n.registeredMobile
                    : l10n.verifyMobile,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.patientType.contains('Existing')
                    ? l10n.registeredMobileHint
                    : l10n.sendOneTimeCode,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                l10n.mobileNumber,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: LocalizedText(
                        '+91',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 25, color: AppColors.divider),
                    Expanded(
                      child: TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.enterMobileNumber,
                          hintStyle: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 13,
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.blushPink.withValues(alpha: 0.55),
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
                        'No medical information is shown until identity and record access are verified.',
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _continue,
                  child: const LocalizedText('Continue'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
