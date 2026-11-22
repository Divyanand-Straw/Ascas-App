import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import 'package:flutter/services.dart';

import '../../../core/widgets/step_progress_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/biometric_service.dart';
import 'registration_complete_screen.dart';

class AppSecurityScreen extends StatefulWidget {
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

  const AppSecurityScreen({
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
  });

  @override
  State<AppSecurityScreen> createState() => _AppSecurityScreenState();
}

class _AppSecurityScreenState extends State<AppSecurityScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

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
              borderSide: const BorderSide(color: AppColors.divider),
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
    final currentStep = widget.isExistingPatient ? 7 : 8;
    final totalSteps = widget.isExistingPatient ? 8 : 9;
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
                  Expanded(
                    child: Column(
                      children: [
                        LocalizedText(
                          'STEP $currentStep OF $totalSteps',
                          style: const TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        LocalizedText(
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
              StepProgressBar(currentStep: currentStep, totalSteps: totalSteps),
              const SizedBox(height: 28),
              const LocalizedText(
                'APP SECURITY',
                style: TextStyle(
                  color: AppColors.dustyPink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              const LocalizedText(
                'Create your app PIN',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const LocalizedText(
                'This PIN protects Thaai Seyali information on your device.',
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
                  child: LocalizedText(
                    'PINs do not match. Please try again.',
                    style: TextStyle(color: AppColors.error, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.divider),
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
                          LocalizedText(
                            'Use biometric authentication',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          LocalizedText(
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
                height: 48,
                child: ElevatedButton(
                  onPressed: _isPinValid
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegistrationCompleteScreen(
                                fullName: widget.fullName,
                                dateOfBirth: widget.dateOfBirth,
                                email: widget.email,
                                mobileNumber: widget.mobileNumber,
                                emergencyContact: widget.emergencyContact,
                                preferredLanguage: widget.preferredLanguage,
                                gender: widget.gender,
                                isExistingPatient: widget.isExistingPatient,
                                patientId: widget.patientId,
                                accountId: widget.accountId,
                                securityPin: _pinController.text,
                                biometricEnabled: _biometricEnabled,
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
                    'Complete security setup',
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

class SecurityPinSettingsScreen extends StatelessWidget {
  final String accountId;

  const SecurityPinSettingsScreen({super.key, required this.accountId});

  Future<String?> _askPin(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LocalizedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length == 4) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const LocalizedText('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _askNewPin(BuildContext context) => _askPin(
    context,
    title: 'Create a new Security PIN',
    label: 'New 4-digit PIN',
  );

  Future<bool> _changePin(BuildContext context) async {
    final service = BiometricService.instance;
    final current = await _askPin(
      context,
      title: 'Verify current Security PIN',
      label: 'Current PIN',
    );
    if (current == null) return false;
    if (!context.mounted) return false;
    final next = await _askNewPin(context);
    if (next == null) return false;
    if (!context.mounted) return false;
    final confirmation = await _askPin(
      context,
      title: 'Confirm new Security PIN',
      label: 'Confirm PIN',
    );
    if (confirmation != next) {
      throw StateError('PINs do not match. Please try again.');
    }
    await service.changePin(
      accountId: accountId,
      currentPin: current,
      newPin: next,
    );
    return true;
  }

  Future<bool> _resetPin(BuildContext context) async {
    final service = BiometricService.instance;
    if (!await service.authenticateForSensitiveAction(
      'Authenticate to reset your Thaai Seyali Security PIN.',
    )) {
      throw StateError(
        'Biometric verification is required to reset the Security PIN.',
      );
    }
    if (!context.mounted) return false;
    final next = await _askNewPin(context);
    if (next == null) return false;
    if (!context.mounted) return false;
    final confirmation = await _askPin(
      context,
      title: 'Confirm new Security PIN',
      label: 'Confirm PIN',
    );
    if (confirmation != next) {
      throw StateError('PINs do not match. Please try again.');
    }
    await service.setPin(accountId: accountId, pin: next);
    return true;
  }

  Future<void> _run(
    BuildContext context,
    Future<bool> Function(BuildContext) action,
  ) async {
    try {
      if (await action(context) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LocalizedText('Security PIN updated.')),
        );
      }
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LocalizedText(error.message.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = BiometricService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const LocalizedText('Security PIN'),
      ),
      body: AnimatedBuilder(
        animation: service,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const LocalizedText(
              'Manage your Security PIN, biometrics and app lock in one place.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<bool>(
              future: service.hasPin(accountId),
              builder: (context, snapshot) => _securityCard(
                icon: Icons.pin_outlined,
                title: 'Security PIN',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: LocalizedText(
                            'Your PIN protects access to Thaai Seyali on this device.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusPill(
                          label: snapshot.data == true
                              ? 'Configured'
                              : 'Not configured',
                          active: snapshot.data == true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: snapshot.data == true
                                ? () => _run(context, _changePin)
                                : null,
                            child: const LocalizedText('Change Security PIN'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            onPressed: snapshot.data == true
                                ? () => _run(context, _resetPin)
                                : null,
                            child: const LocalizedText('Reset Security PIN'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _securityCard(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Authentication',
              child: FutureBuilder<BiometricAvailability>(
                future: service.availability(),
                builder: (context, snapshot) {
                  final available =
                      snapshot.data?.available == true &&
                      snapshot.data?.enrolled == true;
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: service.enabled,
                    title: const LocalizedText('Fingerprint or Face ID'),
                    subtitle: LocalizedText(
                      available
                          ? 'Use biometrics before falling back to your PIN.'
                          : 'Biometrics are not available on this device.',
                    ),
                    onChanged: available
                        ? (value) async {
                            final success = value
                                ? await service.enable()
                                : await service.disable();
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: LocalizedText(
                                    'Biometric authentication could not be changed.',
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    activeThumbColor: const Color(0xFF6B1837),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _securityCard(
              icon: Icons.lock_outline_rounded,
              title: 'App Lock',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: service.appLockEnabled,
                title: const LocalizedText('Enable App Lock'),
                subtitle: const LocalizedText(
                  'Protect the app when it returns from another application.',
                ),
                onChanged: (value) async {
                  final pin = value
                      ? null
                      : await _askPin(
                          context,
                          title: 'Verify current Security PIN',
                          label: 'Current PIN',
                        );
                  if (!value && pin == null) return;
                  final success = await service.setAppLockEnabled(
                    value,
                    pin: pin,
                  );
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: LocalizedText(
                          'Authentication was not completed.',
                        ),
                      ),
                    );
                  }
                },
                activeThumbColor: const Color(0xFF6B1837),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _securityCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      color: const Color(0xFFFFF5F7),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFF0D9E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8E9EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Color(0xFFC9879D)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LocalizedText(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF6B1837),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusPill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFF8E9EE) : const Color(0xFFEDE7E9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: LocalizedText(
      label,
      style: TextStyle(
        color: active ? const Color(0xFF6B1837) : AppColors.secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
