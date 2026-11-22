import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/step_progress_bar.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';
import 'patient_details_screen.dart';

class NewPatientCredentialsDraft {
  String email;
  String password;
  String confirmPassword;
  bool isConfigured;

  NewPatientCredentialsDraft({
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.isConfigured = false,
  });
}

Widget buildPendingRegistrationScreen({
  required PendingNewPatientRegistration registration,
  required String mobileNumber,
}) {
  if (registration.step == PendingRegistrationStep.credentials) {
    return CreateLoginCredentialsScreen(
      mobileNumber: mobileNumber,
      draft: NewPatientCredentialsDraft(email: registration.email),
    );
  }
  final session = AuthRepository.instance.currentSession;
  final backendEmail = session?.user.id == registration.userId
      ? session?.user.email?.trim()
      : null;
  final email = backendEmail != null && backendEmail.isNotEmpty
      ? backendEmail
      : registration.email;
  return PatientDetailsScreen(mobileNumber: mobileNumber, email: email);
}

class CreateLoginCredentialsScreen extends StatefulWidget {
  final String mobileNumber;
  final NewPatientCredentialsDraft draft;
  final AuthRepository? authRepository;

  const CreateLoginCredentialsScreen({
    super.key,
    required this.mobileNumber,
    required this.draft,
    this.authRepository,
  });

  @override
  State<CreateLoginCredentialsScreen> createState() =>
      _CreateLoginCredentialsScreenState();
}

class _CreateLoginCredentialsScreenState
    extends State<CreateLoginCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _isLoading = false;
  bool _isNavigating = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  AuthRepository get _authRepository =>
      widget.authRepository ?? AuthRepository.instance;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.draft.email);
    _passwordController = TextEditingController(text: widget.draft.password);
    _confirmPasswordController = TextEditingController(
      text: widget.draft.confirmPassword,
    );
    _emailController.addListener(() {
      widget.draft.email = _emailController.text;
    });
    _passwordController.addListener(() {
      widget.draft.password = _passwordController.text;
    });
    _confirmPasswordController.addListener(() {
      widget.draft.confirmPassword = _confirmPasswordController.text;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = normalizeEmail(value ?? '');
    if (email.isEmpty) return 'Please enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 12) {
      return 'Password must be at least 12 characters.';
    }
    if (password.length > 128 || utf8.encode(password).length > 72) {
      return 'Password must not exceed 72 UTF-8 bytes.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _continue() async {
    if (_isLoading || _isNavigating) return;
    if (widget.draft.isConfigured) {
      await _openPatientDetails(widget.draft.email);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final email = normalizeEmail(_emailController.text);
    setState(() => _isLoading = true);
    try {
      await _authRepository.setupRegistrationCredentials(
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        widget.draft
          ..email = email
          ..isConfigured = true;
        _emailController.text = email;
        _isLoading = false;
      });
      await _openPatientDetails(email);
    } on ApiError catch (error) {
      if (!mounted) return;
      final message = error.statusCode == 409
          ? 'This email address is already associated with an account.'
          : error.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save credentials. Please try again.'),
        ),
      );
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPatientDetails(String email) async {
    if (!mounted || _isNavigating) return;
    setState(() => _isNavigating = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PatientDetailsScreen(
            mobileNumber: widget.mobileNumber,
            email: email,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  InputDecoration _decoration({required String label, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.white,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burgundy, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = widget.draft.isConfigured;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
          child: Form(
            key: _formKey,
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
                            'STEP 4 OF 9',
                            style: TextStyle(
                              color: AppColors.dustyPink,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          LocalizedText(
                            'Create login credentials',
                            style: TextStyle(
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
                const StepProgressBar(currentStep: 4, totalSteps: 9),
                const SizedBox(height: 30),
                const LocalizedText(
                  'CREATE LOGIN CREDENTIALS',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const LocalizedText(
                  'Use your email and password to sign in.',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const LocalizedText(
                  'Your email will remain unverified. Mobile OTP remains available, and these credentials do not verify clinic identity or grant access to clinic records.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  key: const ValueKey('new-patient-credential-email'),
                  controller: _emailController,
                  enabled: !configured,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: configured ? null : _validateEmail,
                  decoration: _decoration(label: 'Email address'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('new-patient-credential-password'),
                  controller: _passwordController,
                  enabled: !configured,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.next,
                  validator: configured ? null : _validatePassword,
                  decoration: _decoration(
                    label: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey(
                    'new-patient-credential-confirm-password',
                  ),
                  controller: _confirmPasswordController,
                  enabled: !configured,
                  obscureText: !_showConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: configured ? null : _validateConfirmPassword,
                  decoration: _decoration(
                    label: 'Confirm password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      ),
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                if (configured) ...[
                  const SizedBox(height: 14),
                  const LocalizedText(
                    'Login credentials saved.',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || _isNavigating ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const LocalizedText('Continue'),
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
