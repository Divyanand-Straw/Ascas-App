import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/localized_text.dart';
import '../data/account_identity_service.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../partner_access/data/partner_link_service.dart';
import '../../../l10n/app_localizations.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _demoOtp = '123456';

  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isSigningIn = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isSigningIn || !_formKey.currentState!.validate()) return;

    setState(() => _isSigningIn = true);
    try {
      final identity = await AccountIdentityService().accountForMobile(
        _mobileController.text.trim(),
      );
      if (identity == null) {
        throw StateError(
          'No account is registered with this mobile number. Register or verify your existing clinic record first.',
        );
      }

      if (identity.role == AccountRole.patient) {
        await _openPatientDashboard(identity);
        return;
      }

      final link = await PartnerLinkService().activeLinkForPartner(
        identity.mobileNumber,
        partnerUserId: identity.accountId,
      );
      if (link == null) {
        throw StateError(
          'This partner account has no active patient link yet. Ask the patient to approve your request.',
        );
      }
      await _openPartnerDashboard(identity, link);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizedText(context, error.message.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _openPatientDashboard(AccountIdentity identity) async {
    await _setAccountLanguage(identity);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          patientName: identity.fullName,
          patientId: identity.patientId,
          mobileNumber: identity.mobileNumber,
          dateOfBirth: identity.dateOfBirth,
          preferredLanguage: identity.preferredLanguage,
          accountId: identity.accountId,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _openPartnerDashboard(
    AccountIdentity identity,
    PartnerRelationship link,
  ) async {
    await _setAccountLanguage(identity);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          patientName: link.patientName,
          patientId: link.patientId,
          mobileNumber: link.patientMobile,
          accountId: identity.accountId,
          isLinkedPartner: true,
          partnerUserName: identity.fullName,
          partnerMobile: identity.mobileNumber,
          partnerLinkId: link.linkId,
          partnerPermissions: link.permissions,
          dataOwnerAccountId: link.patientUserId,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _setAccountLanguage(AccountIdentity identity) =>
      LocaleService.setAccountLanguage(
        accountId: identity.accountId,
        languageCode:
            identity.preferredLanguage == 'Tamil' ||
                identity.preferredLanguage == 'தமிழ்'
            ? 'ta'
            : 'en',
      );

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
    prefixIcon: Icon(icon, color: AppColors.secondaryText),
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
                        const Text(
                          'THAAI SEYAZHI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'தாய் செயழி',
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 18),
                          Text(
                            l10n.login,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const LocalizedText(
                            'Sign in with the mobile number registered to your patient account.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.mobileNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const ValueKey('login-mobile-field'),
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _fieldDecoration(
                              hint: l10n.enterMobileNumber,
                              icon: Icons.phone_outlined,
                            ).copyWith(counterText: ''),
                            validator: (value) =>
                                RegExp(r'^[6-9]\d{9}$')
                                    .hasMatch(value?.trim() ?? '')
                                ? null
                                : l10n.validMobileNumber,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.otpVerification,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const ValueKey('login-otp-field'),
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _fieldDecoration(
                              hint: localizedText(context, '6-digit demo code'),
                              icon: Icons.lock_outline,
                            ).copyWith(counterText: ''),
                            validator: (value) => value == _demoOtp
                                ? null
                                : localizedText(
                                    context,
                                    'Enter demo code 123456.',
                                  ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.blushPink.withValues(alpha: .5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const LocalizedText(
                              'Local demo sign-in only · OTP: 123456 · Not secure for production use.',
                              style: TextStyle(
                                color: AppColors.burgundy,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 53,
                            child: ElevatedButton(
                              onPressed: _isSigningIn ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.burgundy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSigningIn
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      l10n.login,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 25),
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
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
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
