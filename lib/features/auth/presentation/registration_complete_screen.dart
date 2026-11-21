import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/widgets/date_of_birth_picker.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../data/account_identity_service.dart';
import '../data/models/auth_models.dart';
import '../data/repositories/auth_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import 'email_password_setup_screen.dart';

class RegistrationCompleteScreen extends StatefulWidget {
  final String fullName;
  final String dateOfBirth;
  final String mobileNumber;
  final String email;
  final String emergencyContact;
  final String preferredLanguage;
  final String? gender;
  final bool isExistingPatient;
  final String patientId;
  final String accountId;
  final String securityPin;
  final bool biometricEnabled;
  final AuthRepository? authRepository;

  const RegistrationCompleteScreen({
    super.key,
    required this.fullName,
    required this.dateOfBirth,
    required this.mobileNumber,
    this.email = '',
    this.emergencyContact = '',
    required this.preferredLanguage,
    this.gender,
    this.isExistingPatient = false,
    this.patientId = '',
    this.accountId = '',
    this.securityPin = '',
    this.biometricEnabled = false,
    this.authRepository,
  });

  @override
  State<RegistrationCompleteScreen> createState() =>
      _RegistrationCompleteScreenState();
}

class _RegistrationCompleteScreenState
    extends State<RegistrationCompleteScreen> {
  PatientProfileData? _savedProfile;
  bool _isSaving = false;
  String? _saveError;

  AuthRepository get _authRepository =>
      widget.authRepository ?? AuthRepository.instance;

  String get _registrationEmail {
    final backendEmail = _authRepository.currentSession?.user.email?.trim();
    return backendEmail != null && backendEmail.isNotEmpty
        ? backendEmail
        : widget.email;
  }

  @override
  void initState() {
    super.initState();
    if (!widget.isExistingPatient) {
      _isSaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_saveNewPatientProfile());
      });
    }
  }

  Future<void> _saveNewPatientProfile() async {
    try {
      final session = _authRepository.currentSession;
      if (session == null ||
          _authRepository.normalizePhone(session.user.phone) !=
              _authRepository.normalizePhone(widget.mobileNumber)) {
        throw StateError(
          'Your verified mobile session is unavailable. Please sign in again.',
        );
      }
      if (widget.emergencyContact.isEmpty) {
        throw StateError('Please enter an emergency contact number.');
      }
      final parsedDate = parseDateOfBirth(widget.dateOfBirth);
      if (parsedDate == null) {
        throw StateError('Please enter a valid date of birth.');
      }
      final nameParts = widget.fullName.trim().split(RegExp(r'\s+'));
      if (nameParts.first.isEmpty) {
        throw StateError('Please enter your full name.');
      }
      final profile = await _authRepository.savePatientProfile(
        firstName: nameParts.first,
        lastName: nameParts.skip(1).join(' '),
        dateOfBirth:
            '${parsedDate.year.toString().padLeft(4, '0')}-'
            '${parsedDate.month.toString().padLeft(2, '0')}-'
            '${parsedDate.day.toString().padLeft(2, '0')}',
        gender: widget.gender,
        emergencyContact: widget.emergencyContact,
        preferredLanguage:
            widget.preferredLanguage == 'Tamil' ||
                widget.preferredLanguage == 'தமிழ்'
            ? 'ta'
            : 'en',
      );
      if (profile.userId != session.user.id) {
        throw StateError(
          'The saved profile does not match the verified account.',
        );
      }
      if (widget.accountId.isNotEmpty && widget.accountId != session.user.id) {
        throw StateError(
          'The verified account changed during registration. Please sign in again.',
        );
      }
      if (!mounted) return;
      setState(() {
        _savedProfile = profile;
        _isSaving = false;
        _saveError = null;
      });
    } on ApiError catch (error) {
      _setSaveError(error.message);
    } on StateError catch (error) {
      _setSaveError(error.message.toString());
    } on FormatException catch (error) {
      _setSaveError(error.message);
    }
  }

  void _setSaveError(String message) {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saveError = message;
    });
  }

  void _retryProfileSave() {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    unawaited(_saveNewPatientProfile());
  }

  Future<void> _continue(BuildContext context) async {
    if (_isSaving || (!widget.isExistingPatient && _savedProfile == null)) {
      return;
    }
    try {
      late final String resolvedName;
      late final String resolvedMobile;
      late final String resolvedDateOfBirth;
      late final String resolvedEmail;
      late final String resolvedLanguage;
      late final String resolvedAccountId;
      late final String resolvedPatientId;

      if (widget.isExistingPatient) {
        final identity = await AccountIdentityService().resolveExistingPatient(
          mobileNumber: widget.mobileNumber,
          patientId: widget.patientId,
          dateOfBirth: widget.dateOfBirth,
        );
        if (widget.accountId.isNotEmpty &&
            identity.accountId != widget.accountId) {
          throw StateError(
            'The verified account changed during registration. Please sign in again.',
          );
        }
        resolvedName = identity.fullName;
        resolvedMobile = identity.mobileNumber;
        resolvedDateOfBirth = identity.dateOfBirth;
        resolvedEmail = identity.email;
        resolvedLanguage = identity.preferredLanguage;
        resolvedAccountId = identity.accountId;
        resolvedPatientId = identity.patientId;
      } else {
        final session = _authRepository.currentSession;
        if (session == null ||
            _authRepository.normalizePhone(session.user.phone) !=
                _authRepository.normalizePhone(widget.mobileNumber)) {
          throw StateError(
            'Your verified mobile session is unavailable. Please sign in again.',
          );
        }
        final savedProfile = _savedProfile;
        if (savedProfile == null) {
          throw StateError('Patient details have not been saved yet.');
        }
        if (savedProfile.userId != session.user.id) {
          throw StateError(
            'The saved profile does not match the verified account.',
          );
        }
        if (widget.accountId.isNotEmpty &&
            widget.accountId != session.user.id) {
          throw StateError(
            'The verified account changed during registration. Please sign in again.',
          );
        }
        resolvedName = savedProfile.fullName;
        resolvedMobile = session.user.phone;
        resolvedDateOfBirth = savedProfile.dob ?? widget.dateOfBirth;
        resolvedEmail = _registrationEmail;
        resolvedLanguage = savedProfile.preferredLanguage == 'ta'
            ? 'Tamil'
            : 'English';
        resolvedAccountId = session.user.id;
        resolvedPatientId = savedProfile.clinicMrn ?? '';
      }

      if (widget.securityPin.isNotEmpty) {
        await BiometricService.instance.setPin(
          accountId: resolvedAccountId,
          pin: widget.securityPin,
        );
        await BiometricService.instance.setBiometricPreference(
          accountId: resolvedAccountId,
          enabled: widget.biometricEnabled,
        );
      }
      final language =
          resolvedLanguage == 'Tamil' || resolvedLanguage == 'தமிழ்'
          ? 'ta'
          : 'en';
      await LocaleService.setAccountLanguage(
        accountId: resolvedAccountId,
        languageCode: language,
      );
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            patientName: resolvedName,
            mobileNumber: resolvedMobile,
            email: resolvedEmail,
            dateOfBirth: resolvedDateOfBirth,
            preferredLanguage: resolvedLanguage,
            accountId: resolvedAccountId,
            patientId: resolvedPatientId,
          ),
        ),
        (route) => false,
      );
    } on ApiError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

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
    final isComplete = widget.isExistingPatient || _savedProfile != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 35, 25, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isExistingPatient) ...[
                const Center(
                  child: LocalizedText(
                    'STEP 9 OF 9',
                    style: TextStyle(
                      color: AppColors.dustyPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const StepProgressBar(currentStep: 9, totalSteps: 9),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 35),
              Center(
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: _isSaving
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: AppColors.burgundy,
                          ),
                        )
                      : Icon(
                          _saveError != null
                              ? Icons.error_outline_rounded
                              : Icons.verified_rounded,
                          color: _saveError != null
                              ? AppColors.error
                              : AppColors.burgundy,
                          size: 48,
                        ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  widget.isExistingPatient
                      ? 'ACCOUNT LINKED'
                      : _isSaving
                      ? 'SAVING REGISTRATION'
                      : _saveError != null
                      ? 'REGISTRATION NOT SAVED'
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
                  widget.isExistingPatient
                      ? 'Your clinic record is linked'
                      : _isSaving
                      ? 'Saving your patient details'
                      : _saveError != null
                      ? 'Registration could not be completed'
                      : 'Welcome to Thaai Seyali',
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
                widget.isExistingPatient
                    ? 'Your existing clinic record, identity, consent, and app security have been verified.'
                    : _isSaving
                    ? 'Your registration details are being saved securely.'
                    : _saveError != null
                    ? 'Your patient details were not saved. You can retry without creating another account.'
                    : 'Your mobile number and patient profile have been saved, and consent and app security are set up.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              if (_saveError != null && !widget.isExistingPatient) ...[
                const SizedBox(height: 16),
                Text(
                  _saveError!,
                  key: const ValueKey('registration-save-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              if (isComplete) ...[
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
                        widget.isExistingPatient
                            ? 'Existing clinic record linked'
                            : 'New patient profile created',
                      ),
                      _verificationItem('Consent recorded securely'),
                      _verificationItem('App PIN protected'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 35),
              if (isComplete &&
                  !widget.isExistingPatient &&
                  _registrationEmail.isEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const ValueKey('optional-email-password-setup'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EmailPasswordSetupScreen(
                          initialEmail: _registrationEmail,
                        ),
                      ),
                    ),
                    child: const Text('Optional: set up email and password'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (isComplete)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _continue(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const LocalizedText(
                      'Continue to patient dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else if (_saveError != null)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    key: const ValueKey('retry-registration-save'),
                    onPressed: _retryProfileSave,
                    child: const Text('Retry saving registration'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
