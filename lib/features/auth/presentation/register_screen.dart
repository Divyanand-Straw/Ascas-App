import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _createAccount() {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and privacy policy.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registration UI completed. Backend integration pending.',
        ),
      ),
    );
  }

  void _showPendingMessage(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in integration is coming soon.')),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
      prefixIcon: prefix,
      suffixIcon: suffix,
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.divider),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 9),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    l10n.createAccount,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: AppColors.burgundy,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  l10n.newPatientRegistration,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: AppColors.dustyPink,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  l10n.letsBegin,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  l10n.encryptedPrivate,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),

                const SizedBox(height: 28),

                _buildLabel(l10n.fullName),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(
                    hint: l10n.enterFullName,
                    prefix: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.pleaseEnterName;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                _buildLabel(l10n.mobileNumber),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: _fieldDecoration(
                    hint: l10n.enterMobileNumber,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 8),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          '+91',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ).copyWith(counterText: ''),
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                      return l10n.validMobileNumber;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                _buildLabel(l10n.emailAddress),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration(
                    hint: l10n.enterEmailAddress,
                    prefix: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                            .hasMatch(value.trim())) {
                      return l10n.validEmailAddress;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                _buildLabel(l10n.password),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _fieldDecoration(
                    hint: 'Create a password',
                    prefix: const Icon(Icons.lock_outline),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      activeColor: AppColors.burgundy,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Wrap(
                          children: [
                            const Text(
                              'I agree to the ',
                              style: TextStyle(fontSize: 12),
                            ),
                            GestureDetector(
                              onTap: () => _showPendingMessage('Terms'),
                              child: const Text(
                                'Terms',
                                style: TextStyle(
                                  color: AppColors.burgundy,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Text(', '),
                            GestureDetector(
                              onTap: () =>
                                  _showPendingMessage('Privacy Policy'),
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: AppColors.burgundy,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Text(
                              ', and required patient consent.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Center(
                  child: Text(
                    'OR SIGN UP WITH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    _buildSocialButton(
                      icon: const FaIcon(FontAwesomeIcons.google, size: 17),
                      label: 'Google',
                      onPressed: () => _showPendingMessage('Google'),
                    ),
                    const SizedBox(width: 12),
                    _buildSocialButton(
                      icon: const FaIcon(FontAwesomeIcons.apple, size: 21),
                      label: 'Apple',
                      onPressed: () => _showPendingMessage('Apple'),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.burgundy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
