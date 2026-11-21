import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/step_progress_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../login_screen.dart';
import 'new_patient_otp_screen.dart';
import '../linked_member/linked_member_otp_screen.dart';

class MobileRegistrationScreen extends StatefulWidget {
  final String patientType;
  final AuthRepository? authRepository;

  const MobileRegistrationScreen({
    super.key,
    required this.patientType,
    this.authRepository,
  });

  @override
  State<MobileRegistrationScreen> createState() =>
      _MobileRegistrationScreenState();
}

class _MobileRegistrationScreenState extends State<MobileRegistrationScreen> {
  final TextEditingController _mobileController = TextEditingController();
  bool _isLoading = false;
  Timer? _cooldownTimer;
  int _retryAfterSeconds = 0;

  AuthRepository get _authRepository =>
      widget.authRepository ?? AuthRepository.instance;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _mobileController.dispose();
    super.dispose();
  }

  OtpPurpose _resolvePurpose() {
    final type = widget.patientType.trim().toLowerCase();
    if (type.contains('new patient')) {
      return OtpPurpose.registration;
    } else if (type.contains('existing')) {
      return OtpPurpose.existingPatient;
    } else if (type.contains('linked member')) {
      return OtpPurpose.linkedMember;
    }
    return OtpPurpose.registration;
  }

  Future<void> _continue() async {
    final mobile = _mobileController.text.trim();
    final purpose = _resolvePurpose();
    if (purpose == OtpPurpose.registration && _retryAfterSeconds > 0) return;

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Enter a valid 10-digit mobile number.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authRepository.sendOtp(
        phone: mobile,
        purpose: purpose,
      );

      if (!mounted) return;

      if (purpose == OtpPurpose.linkedMember) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LinkedMemberOtpScreen(
              mobileNumber: mobile,
              challengeId: response.challengeId,
              initialCountdownSeconds: response.retryAfterSeconds,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewPatientOtpScreen(
              mobileNumber: mobile,
              challengeId: response.challengeId,
              initialCountdownSeconds: response.retryAfterSeconds,
              purpose: purpose,
              fromExistingPatient: purpose == OtpPurpose.existingPatient,
              authRepository: _authRepository,
            ),
          ),
        );
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      if (purpose == OtpPurpose.registration) {
        _startCooldown(e.retryAfterSeconds);
      }

      if (e.errorCode == 'USER_ALREADY_EXISTS') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'An account already exists for this mobile number. Please log in.',
            ),
            action: SnackBarAction(
              label: 'Log In',
              textColor: Colors.amber,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
        );
      } else if (e.errorCode == 'USER_NOT_FOUND') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No existing account found. Please register as a New Patient.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send verification code: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startCooldown(int? seconds) {
    if (seconds == null || seconds <= 0) return;
    _cooldownTimer?.cancel();
    setState(() {
      _retryAfterSeconds = seconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _retryAfterSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _retryAfterSeconds = 0);
        return;
      }
      setState(() => _retryAfterSeconds--);
    });
  }

  String get _formattedRetryAfter {
    final minutes = (_retryAfterSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_retryAfterSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final purpose = _resolvePurpose();
    final totalSteps = purpose == OtpPurpose.registration ? 9 : 8;
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
                          'STEP 2 OF $totalSteps',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.otpVerification,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 12),
              StepProgressBar(currentStep: 2, totalSteps: totalSteps),
              const SizedBox(height: 24),
              Text(
                l10n.enterMobileNumber,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.sendOneTimeCode,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.mobileNumber,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text('🇮🇳', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.enterTenDigitMobile,
                          hintStyle: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 15,
                          ),
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                  onPressed:
                      _isLoading ||
                          (purpose == OtpPurpose.registration &&
                              _retryAfterSeconds > 0)
                      ? null
                      : _continue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : purpose == OtpPurpose.registration &&
                            _retryAfterSeconds > 0
                      ? Text('Try again in $_formattedRetryAfter')
                      : const LocalizedText('Continue'),
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
