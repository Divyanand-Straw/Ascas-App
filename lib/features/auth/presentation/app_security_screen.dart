
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../../../core/theme/app_colors.dart';
import 'registration_complete_screen.dart';

class AppSecurityScreen extends StatefulWidget {
  final String fullName;
  final String dateOfBirth;
  final String mobileNumber;
  final String preferredLanguage;
  final bool isExistingPatient;
  final String patientId;
  final String accountId;

  const AppSecurityScreen({
    super.key,
    required this.fullName,
    required this.dateOfBirth,
    required this.mobileNumber,
    required this.preferredLanguage,
    this.isExistingPatient = false,
    this.patientId = '',
    this.accountId = '',
  });

  @override
  State<AppSecurityScreen> createState() => _AppSecurityScreenState();
}

class _AppSecurityScreenState extends State<AppSecurityScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController =
      TextEditingController();

  bool _biometricEnabled = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  bool get _isPinValid =>
      _pinController.text.length == 4 &&
      _confirmPinController.text.length == 4 &&
      _pinController.text == _confirmPinController.text;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Widget _pinField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onVisibilityToggle,
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
          controller: controller,
          obscureText: obscureText,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 18,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter 4-digit PIN',
            hintStyle: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              letterSpacing: 0,
            ),
            suffixIcon: IconButton(
              onPressed: onVisibilityToggle,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.secondaryText,
                size: 19,
              ),
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: AppColors.divider,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: AppColors.burgundy,
                width: 1.4,
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
                        Text(
                          'STEP 7 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'App security',
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
                    onPressed: () => Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    ),
                    child: const Text(
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
              const Divider(
                color: AppColors.divider,
                height: 1,
              ),
              const SizedBox(height: 16),
              const StepProgressBar(currentStep: 7),
              const SizedBox(height: 28),
              const Text(
                'APP SECURITY',
                style: TextStyle(
                  color: AppColors.dustyPink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Create your app PIN',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This PIN protects Thaai Seyazhi information on your device.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _pinField(
                label: 'Create 4-digit PIN  * Required',
                controller: _pinController,
                obscureText: _obscurePin,
                onVisibilityToggle: () {
                  setState(() {
                    _obscurePin = !_obscurePin;
                  });
                },
              ),
              const SizedBox(height: 22),
              _pinField(
                label: 'Confirm PIN  * Required',
                controller: _confirmPinController,
                obscureText: _obscureConfirmPin,
                onVisibilityToggle: () {
                  setState(() {
                    _obscureConfirmPin = !_obscureConfirmPin;
                  });
                },
              ),
              if (_confirmPinController.text.isNotEmpty &&
                  _confirmPinController.text.length == 4 &&
                  _pinController.text != _confirmPinController.text)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'PINs do not match. Please try again.',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blushPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: AppColors.burgundy,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use biometric authentication',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Optional fingerprint or face unlock.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _biometricEnabled,
                      onChanged: (value) {
                        setState(() {
                          _biometricEnabled = value;
                        });
                      },
                      activeThumbColor: AppColors.burgundy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPinValid
                      ? () {
                           Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegistrationCompleteScreen(
                                  fullName: widget.fullName,
                                  dateOfBirth: widget.dateOfBirth,
                                  mobileNumber: widget.mobileNumber,
                                  preferredLanguage: widget.preferredLanguage,
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
                  child: const Text(
                    'Complete security setup',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
