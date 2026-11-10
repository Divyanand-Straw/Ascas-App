import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import '../../../../core/theme/app_colors.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String registeredMobile;
  final String registeredEmail;

  const ResetPasswordScreen({
    super.key,
    required this.registeredMobile,
    required this.registeredEmail,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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

  void _updatePassword() {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill in both password fields.');
      return;
    }

    if (password.length < 8) {
      _showMessage('Password must contain at least 8 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    _showSuccessDialog();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: AppColors.blushPink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.burgundy,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              const LocalizedText(
                'Password updated',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const LocalizedText(
                'This password change is not saved until account services are connected. You can return to login.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const LocalizedText(
                    'Back to Login',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                'Create a strong password for your Thaai Seyazhi account. Make sure it is easy for you to remember.',
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

              const SizedBox(height: 14),

              _registeredContact(
                label: 'Registered email address',
                value: widget.registeredEmail,
                icon: Icons.email_outlined,
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
                onChanged: (_) => setState(() {}),
              ),

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
                onChanged: (_) => setState(() {}),
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

              const SizedBox(height: 38),

              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  key: const ValueKey('reset-password-submit'),
                  onPressed: _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.dustyPink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const LocalizedText(
                    'Update Password',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Center(
                child: LocalizedText(
                  'Your account security matters to us.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
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
            suffixIcon: const Icon(
              Icons.verified_outlined,
              color: AppColors.success,
            ),
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
