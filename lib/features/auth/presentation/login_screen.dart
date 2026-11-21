import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/models/auth_models.dart';
import '../data/repositories/auth_repository.dart';
import 'forgot_password/forgot_password_screen.dart';
import 'existing_patient/otp_verification_screen.dart';
import 'patient_type_screen.dart';
import 'developer_email_otp_testing_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const LoginScreen({super.key, this.authRepository});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _useEmailPassword = false;
  bool _obscurePassword = true;
  Timer? _loginCooldownTimer;
  int _loginRetryAfterSeconds = 0;

  @override
  void dispose() {
    _loginCooldownTimer?.cancel();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AuthRepository get _authRepository =>
      widget.authRepository ?? AuthRepository.instance;

  Future<void> _sendOtp() async {
    if (_loginRetryAfterSeconds > 0 || !_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authRepository.sendOtp(
        phone: phone,
        purpose: OtpPurpose.login,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            mobileNumber: phone,
            challengeId: response.challengeId,
            initialCountdownSeconds: response.retryAfterSeconds,
            authRepository: _authRepository,
          ),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      _startLoginCooldown(e.retryAfterSeconds);

      if (e.errorCode == 'USER_NOT_FOUND') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No patient account found for this mobile number.',
            ),
            action: SnackBarAction(
              label: 'Register',
              textColor: Colors.amber,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientTypeScreen()),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to request OTP: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startLoginCooldown(int? seconds) {
    if (seconds == null || seconds <= 0) return;
    _loginCooldownTimer?.cancel();
    setState(() => _loginRetryAfterSeconds = seconds);
    _loginCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _loginRetryAfterSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _loginRetryAfterSeconds = 0);
        return;
      }
      setState(() => _loginRetryAfterSeconds--);
    });
  }

  String get _formattedLoginRetryAfter {
    final minutes = (_loginRetryAfterSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_loginRetryAfterSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _loginWithEmailPassword() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final session = await _authRepository.loginWithEmailPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      final profile = session.profile;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            patientName: profile?.fullName ?? 'Patient',
            mobileNumber: session.user.phone,
            email: session.user.email ?? '',
            dateOfBirth: profile?.dob ?? '',
            preferredLanguage: profile?.preferredLanguage ?? '',
            patientId: profile?.clinicMrn ?? '',
            accountId: session.user.id,
          ),
        ),
        (_) => false,
      );
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to log in. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _phoneFieldDecoration({
    required String hint,
    bool showCountryCode = true,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
      prefixIcon: showCountryCode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: const Text(
                '+91',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            )
          : null,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burgundy, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: screenHeight * 0.34,
                child: ClipPath(
                  clipper: LoginCurveClipper(),
                  child: Container(color: AppColors.burgundy),
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    height: screenHeight * 0.32,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 95,
                            height: 95,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const LocalizedText(
                          'THAAI SEYALI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const LocalizedText(
                          'தாய் செயலி',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        Text(
                          l10n.welcome,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const LocalizedText(
                          'Log in to continue your journey.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_useEmailPassword) ...[
                                const Text(
                                  'Email address',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: const ValueKey('login-email-field'),
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return 'Email address is required';
                                    }
                                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(email)) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                  decoration: _phoneFieldDecoration(
                                    hint: 'Enter your email address',
                                    showCountryCode: false,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: const ValueKey('login-password-field'),
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? 'Password is required'
                                      : null,
                                  decoration:
                                      _phoneFieldDecoration(
                                        hint: 'Enter your password',
                                        showCountryCode: false,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          key: const ValueKey(
                                            'login-password-visibility-toggle',
                                          ),
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                  obscureText: _obscurePassword,
                                ),
                              ] else ...[
                                const Text(
                                  'Mobile Number',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: const ValueKey('login-mobile-field'),
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _phoneFieldDecoration(
                                    hint: 'Enter 10-digit mobile number',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Mobile number is required';
                                    }
                                    if (!RegExp(r'^[6-9]\d{9}$')
                                        .hasMatch(value.trim())) {
                                      return 'Enter a valid 10-digit mobile number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 53,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ||
                                          (!_useEmailPassword &&
                                              _loginRetryAfterSeconds > 0)
                                      ? null
                                      : _useEmailPassword
                                      ? _loginWithEmailPassword
                                      : _sendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.burgundy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          _useEmailPassword
                                              ? 'Log in'
                                              : _loginRetryAfterSeconds > 0
                                              ? 'Try again in $_formattedLoginRetryAfter'
                                              : 'Get OTP',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('login-method-toggle'),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _formKey.currentState?.reset();
                                  setState(() {
                                    _useEmailPassword = !_useEmailPassword;
                                  });
                                },
                          child: Text(
                            _useEmailPassword
                                ? 'Use mobile OTP instead'
                                : 'Log in with email and password',
                            style: const TextStyle(
                              color: AppColors.burgundy,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: Text(
                              l10n.forgotPasswordQuestion,
                              style: const TextStyle(
                                color: AppColors.burgundy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (kDebugMode)
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              key: const ValueKey(
                                'developer-email-otp-testing',
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const DeveloperEmailOtpTestingScreen(),
                                      ),
                                    ),
                              child: const Text('Developer Email OTP Testing'),
                            ),
                          ),
                        const SizedBox(height: 35),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              Text(
                                l10n.noAccount,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PatientTypeScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  l10n.createAccount,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.burgundy,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 45);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 35,
      size.width,
      size.height - 45,
    );
    path
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
