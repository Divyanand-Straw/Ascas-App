import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import '../../../../core/theme/app_colors.dart';
import '../login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String registeredMobile;
  final String registeredEmail;
  final String? resetAuthorizationToken;
  final Future<void> Function(
    String resetAuthorizationToken,
    String newPassword,
  )?
  resetPassword;

  const ResetPasswordScreen({
    super.key,
    required this.registeredMobile,
    required this.registeredEmail,
    this.resetAuthorizationToken,
    this.resetPassword,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _backendUnavailableMessage =
      'We could not update your password right now. Please try again later.';
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  int get _passwordStrength {
    final password = _passwordController.text;
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score;
  }

  String get _passwordStrengthLabel {
    if (_passwordController.text.isEmpty) return '';
    if (_passwordController.text.length < 8) return 'Weak';
    if (_passwordStrength <= 2) return 'Fair';
    if (_passwordStrength <= 4) return 'Good';
    return 'Strong';
  }

  String? get _confirmPasswordError {
    final confirmation = _confirmPasswordController.text;
    if (confirmation.isEmpty || _passwordController.text == confirmation) {
      return null;
    }
    return 'Passwords do not match.';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_isSubmitting) return;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Please fill in both password fields.');
      return;
    }

    if (password.length < 8) {
      setState(
        () => _errorMessage = 'Password must contain at least 8 characters.',
      );
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    final token = widget.resetAuthorizationToken;
    final resetPassword = widget.resetPassword;
    if (token == null || token.trim().isEmpty || resetPassword == null) {
      setState(() => _errorMessage = _backendUnavailableMessage);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await resetPassword(token, password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your password has been updated successfully. Please log in with your new password.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onVisibilityChanged,
    ValueChanged<String>? onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          key: ValueKey(
            label == 'New Password'
                ? 'reset-new-password-field'
                : 'reset-confirm-password-field',
          ),
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
            errorText: errorText,
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            suffixIcon: IconButton(
              onPressed: onVisibilityChanged,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.secondaryText,
                size: 21,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.burgundy,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),

              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.primaryText,
                ),
              ),

              const SizedBox(height: 38),

              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.burgundy,
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Center(
                child: LocalizedText(
                  'STEP 3 OF 3',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 13),

              const Center(
                child: LocalizedText(
                  'Create new password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const LocalizedText(
                'Create a strong password for your Thaai Seyali account. Make sure it is easy for you to remember.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 38),

              _registeredContact(
                label: 'Registered mobile number',
                value: '+91 ${widget.registeredMobile}',
                icon: Icons.phone_outlined,
              ),

              const SizedBox(height: 18),

              _registeredContact(
                label: 'Registered email address',
                value: widget.registeredEmail,
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.blushPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const LocalizedText(
                  'For your security, we need to confirm your account before we can change your password.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _buildPasswordField(
                label: 'New Password',
                hint: 'Enter new password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                onVisibilityChanged: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                onChanged: (_) => setState(() => _errorMessage = null),
              ),

              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _passwordStrength / 5,
                        minHeight: 5,
                        backgroundColor: AppColors.blushPink,
                        color: _passwordController.text.length < 8
                            ? AppColors.error
                            : _passwordStrength >= 4
                            ? AppColors.success
                            : AppColors.dustyPink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _passwordStrengthLabel,
                      style: TextStyle(
                        color: _passwordController.text.length < 8
                            ? AppColors.error
                            : AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              _buildPasswordField(
                label: 'Confirm Password',
                hint: 'Re-enter new password',
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                onVisibilityChanged: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                onChanged: (_) => setState(() => _errorMessage = null),
                errorText: _confirmPasswordError,
              ),

              const SizedBox(height: 15),

              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.dustyPink,
                    size: 17,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: LocalizedText(
                      'Password must contain at least 8 characters.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 38),

              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  key: const ValueKey('reset-password-submit'),
                  onPressed: _isSubmitting ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.dustyPink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const LocalizedText(
                          'Set New Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const LocalizedText(
                    'Back to Login',
                    style: TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _registeredContact({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        InputDecorator(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.secondaryText),
            filled: true,
            fillColor: AppColors.blushPink,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
          ),
          child: Text(
            value,
            style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
