import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../../auth/presentation/consent_privacy_screen.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import 'dashboard_card.dart';
import 'dashboard_home_content.dart';

class PatientProfileData {
  final String name;
  final String mobile;
  final String dateOfBirth;
  final String language;

  const PatientProfileData({
    required this.name,
    required this.mobile,
    required this.dateOfBirth,
    required this.language,
  });
}

class PatientProfileScreen extends StatefulWidget {
  final String patientName;
  final String patientInitials;
  final DashboardPatientState patientState;
  final String mobileNumber;
  final String dateOfBirth;
  final String preferredLanguage;
  final String accountId;
  final ValueChanged<PatientProfileData>? onProfileUpdated;

  const PatientProfileScreen({
    super.key,
    required this.patientName,
    required this.patientInitials,
    required this.patientState,
    required this.mobileNumber,
    required this.dateOfBirth,
    required this.preferredLanguage,
    this.accountId = '',
    this.onProfileUpdated,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late String _name;
  late String _mobile;
  late String _dateOfBirth;
  late String _language;
  Map<String, bool> _partnerPermissions = {
    'Appointments': false,
    'Treatment overview': false,
    'Health records': false,
  };

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isEmpty ? '' : parts.first[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _name = widget.patientName.isEmpty ? 'Priya Sharma' : widget.patientName;
    _mobile = widget.mobileNumber;
    _dateOfBirth = widget.dateOfBirth;
    _language = widget.preferredLanguage.isEmpty
        ? 'English'
        : widget.preferredLanguage;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = preferences.getString('profile_name') ?? _name;
      _mobile = preferences.getString('profile_mobile') ?? _mobile;
      _dateOfBirth = preferences.getString('profile_dob') ?? _dateOfBirth;
      for (final entry in _partnerPermissions.entries) {
        _partnerPermissions[entry.key] =
            preferences.getBool('partner_${entry.key}') ?? false;
      }
    });
  }

  Future<void> _saveProfile(PatientProfileData profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('profile_name', profile.name);
    await preferences.setString('profile_mobile', profile.mobile);
    await preferences.setString('profile_dob', profile.dateOfBirth);
    if (!mounted) return;
    setState(() {
      _name = profile.name;
      _mobile = profile.mobile;
      _dateOfBirth = profile.dateOfBirth;
      _language = profile.language;
    });
    widget.onProfileUpdated?.call(profile);
  }

  Future<void> _editProfile() async {
    final profile = await Navigator.push<PatientProfileData>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalDetailsScreen(
          name: _name,
          mobile: _mobile,
          dateOfBirth: _dateOfBirth,
          language: _language,
        ),
      ),
    );
    if (profile != null) await _saveProfile(profile);
  }

  Future<void> _openLanguage() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LanguageAccessibilityScreen(selectedLanguage: _language),
      ),
    );
    if (result == null) return;
    final language = result == 'Tamil' ? 'ta' : 'en';
    if (widget.accountId.isEmpty) {
      await LocaleService.setLanguage(language);
    } else {
      await LocaleService.setAccountLanguage(
        accountId: widget.accountId,
        languageCode: language,
      );
    }
    if (!mounted) return;
    final profile = PatientProfileData(
      name: _name,
      mobile: _mobile,
      dateOfBirth: _dateOfBirth,
      language: result,
    );
    setState(() => _language = result);
    widget.onProfileUpdated?.call(profile);
  }

  Future<void> _openPermissions() async {
    final result = await Navigator.push<Map<String, bool>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PartnerPermissionsScreen(permissions: _partnerPermissions),
      ),
    );
    if (result == null) return;
    final preferences = await SharedPreferences.getInstance();
    for (final entry in result.entries) {
      await preferences.setBool('partner_${entry.key}', entry.value);
    }
    if (mounted) setState(() => _partnerPermissions = result);
  }

  Future<void> _toggleBiometric(bool value) async {
    final service = BiometricService.instance;
    final availability = await service.availability();
    if (!mounted) return;
    if (!availability.available || !availability.enrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            availability.available
                ? 'No fingerprint or face is enrolled. Add one in your phone settings.'
                : 'Biometric authentication is not supported on this device.',
          ),
        ),
      );
      return;
    }
    final success = value ? await service.enable() : await service.disable();
    if (!mounted) return;
    if (success) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Authentication failed or was cancelled. The setting was not changed.',
          ),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: LocalizedText('Preparing your data...')),
    );
    try {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}thaai_seyazhi_profile.json',
      );
      await file.writeAsString(
        jsonEncode({
          'profile': {
            'name': _name,
            'patientId': 'AS-20481',
            'mobile': _mobile,
            'dateOfBirth': _dateOfBirth,
            'language': _language,
          },
          'appointments': 'Available appointment references',
          'treatment': 'Available treatment overview references',
          'healthRecords': 'No health records are available in this prototype',
        }),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LocalizedText('Export created at ${file.path}')),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: LocalizedText('Unable to export available data.'),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('Log out?'),
        content: LocalizedText('Your patient data will remain on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: LocalizedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.white,
            ),
            child: LocalizedText('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await LocaleService.resetForLogout();
      BiometricService.instance.endSession();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('Delete account?'),
        content: LocalizedText(
          'This prototype cannot permanently delete a clinic account. '
          'Account deletion requires hospital and backend processing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: LocalizedText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: LocalizedText('Request deletion'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Deletion requests require hospital/backend processing.',
          ),
        ),
      );
    }
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.burgundy,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    ),
  );

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        minVerticalPadding: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.blushPink,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppColors.burgundy, size: 21),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.secondaryText,
          size: 21,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => DashboardCard(
    padding: EdgeInsets.zero,
    child: Column(children: children),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primaryText,
        title: LocalizedText(
          'Patient profile',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _editProfile,
            child: LocalizedText(
              'Edit',
              style: TextStyle(color: AppColors.burgundy),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardCard(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.dustyPink,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.blushPink,
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          color: AppColors.burgundy,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const LocalizedText(
                          'Patient ID: AS-20481',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _sectionTitle('Care preferences'),
            _card([
              _option(
                icon: Icons.person_outline_rounded,
                title: 'Personal & Medical Details',
                subtitle: 'Update your care profile.',
                onTap: _editProfile,
              ),
              const Divider(height: 1, color: AppColors.divider),
              _option(
                icon: Icons.translate_rounded,
                title: 'Language & Accessibility',
                subtitle: '$_language - Standard text.',
                onTap: _openLanguage,
              ),
              const Divider(height: 1, color: AppColors.divider),
              _option(
                icon: Icons.people_outline_rounded,
                title: 'Partner Permissions',
                subtitle: 'Manage shared access.',
                onTap: _openPermissions,
              ),
            ]),
            _sectionTitle('Privacy & security'),
            _card([
              SwitchListTile(
                value: BiometricService.instance.enabled,
                onChanged: _toggleBiometric,
                activeThumbColor: AppColors.burgundy,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 4,
                ),
                secondary: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.burgundy,
                    size: 21,
                  ),
                ),
                title: LocalizedText(
                  'Biometric App Lock',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  BiometricService.instance.enabled ? 'Enabled' : 'Disabled',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _option(
                icon: Icons.verified_user_outlined,
                title: 'Consent Management',
                subtitle: 'Review permissions and consent preferences.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConsentManagementScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _option(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy & Consent',
                subtitle: 'Review your privacy and consent information.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConsentPrivacyScreen(
                      fullName: _name,
                      dateOfBirth: _dateOfBirth,
                      mobileNumber: _mobile,
                      preferredLanguage: _language,
                      isExistingPatient: true,
                      patientId: 'AS-20481',
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _option(
                icon: Icons.file_download_outlined,
                title: 'Export My Data',
                subtitle: 'Download your records.',
                onTap: _exportData,
              ),
            ]),
            _sectionTitle('App settings'),
            _card([
              _option(
                icon: Icons.notifications_none_rounded,
                title: 'Notification Settings',
                subtitle: 'Review your clinic reminders and updates.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _option(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'FAQs and contact details.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _option(
                icon: Icons.info_outline_rounded,
                title: 'App Information',
                subtitle: 'Thaai Seyazhi app details.',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Thaai Seyazhi',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset(
                    'assets/images/logo.png',
                    width: 42,
                    height: 42,
                  ),
                ),
              ),
            ]),
            _sectionTitle('Account actions'),
            DashboardCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.burgundy,
                      ),
                      label: LocalizedText(
                        'Log out',
                        style: TextStyle(
                          color: AppColors.burgundy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      label: LocalizedText(
                        'Delete account',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalDetailsScreen extends StatefulWidget {
  final String name;
  final String mobile;
  final String dateOfBirth;
  final String language;

  const PersonalDetailsScreen({
    super.key,
    required this.name,
    required this.mobile,
    required this.dateOfBirth,
    required this.language,
  });

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _dob;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _mobile = TextEditingController(text: widget.mobile);
    _dob = TextEditingController(text: widget.dateOfBirth);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _dob.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final mobile = _mobile.text.trim();
    if (name.length < 2 ||
        !RegExp(r'^[6-9]\d{9}$').hasMatch(mobile) ||
        _dob.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Please enter valid profile details.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      PatientProfileData(
        name: name,
        mobile: mobile,
        dateOfBirth: _dob.text.trim(),
        language: widget.language,
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Personal & Medical Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name, decoration: _dec('Full name')),
          const SizedBox(height: 14),
          TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: _dec('Mobile number'),
          ),
          const SizedBox(height: 14),
          TextField(controller: _dob, decoration: _dec('Date of birth')),
          const SizedBox(height: 18),
          LocalizedText(
            'Hospital-managed clinical records and treatment information cannot be edited here.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: LocalizedText('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: LocalizedText('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LanguageAccessibilityScreen extends StatefulWidget {
  final String selectedLanguage;

  const LanguageAccessibilityScreen({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<LanguageAccessibilityScreen> createState() =>
      _LanguageAccessibilityScreenState();
}

class _LanguageAccessibilityScreenState
    extends State<LanguageAccessibilityScreen> {
  late String _language;
  double _textScale = 1;

  @override
  void initState() {
    super.initState();
    _language = widget.selectedLanguage;
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('profile_language', _language);
    await preferences.setDouble('profile_text_scale', _textScale);
    if (mounted) Navigator.pop(context, _language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Language & Accessibility'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: InputDecoration(labelText: l10n.language),
            items: [
              DropdownMenuItem(value: 'English', child: Text(l10n.english)),
              DropdownMenuItem(value: 'Tamil', child: Text(l10n.tamil)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _language = value);
            },
          ),
          const SizedBox(height: 20),
          LocalizedText('Text size'),
          Slider(
            value: _textScale,
            min: 0.9,
            max: 1.2,
            divisions: 3,
            label: _textScale.toStringAsFixed(1),
            activeColor: AppColors.burgundy,
            onChanged: (value) => setState(() => _textScale = value),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            child: LocalizedText('Save preferences'),
          ),
        ],
      ),
    );
  }
}

class PartnerPermissionsScreen extends StatefulWidget {
  final Map<String, bool> permissions;

  const PartnerPermissionsScreen({super.key, required this.permissions});

  @override
  State<PartnerPermissionsScreen> createState() =>
      _PartnerPermissionsScreenState();
}

class _PartnerPermissionsScreenState extends State<PartnerPermissionsScreen> {
  late Map<String, bool> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = Map<String, bool>.from(widget.permissions);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: LocalizedText('Partner Permissions'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LocalizedText(
          'Only permissions you enable will be available to an approved partner.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 14),
        ..._permissions.keys.map(
          (permission) => SwitchListTile(
            value: _permissions[permission]!,
            activeThumbColor: AppColors.burgundy,
            title: Text(permission),
            onChanged: (value) =>
                setState(() => _permissions[permission] = value),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _permissions),
          child: LocalizedText('Save permissions'),
        ),
      ],
    ),
  );
}

class ConsentManagementScreen extends StatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  State<ConsentManagementScreen> createState() =>
      _ConsentManagementScreenState();
}

class _ConsentManagementScreenState extends State<ConsentManagementScreen> {
  bool _careUpdates = true;
  bool _partnerSharing = false;

  Future<void> _changeConsent(String title, bool value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('Change $title?'),
        content: LocalizedText('Review this permission change before saving.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: LocalizedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: LocalizedText('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        if (title == 'Care updates') {
          _careUpdates = value;
        } else {
          _partnerSharing = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: LocalizedText('Consent Management'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          value: _careUpdates,
          activeThumbColor: AppColors.burgundy,
          title: LocalizedText('Care updates'),
          subtitle: LocalizedText('Receive care-related app updates.'),
          onChanged: (value) => _changeConsent('Care updates', value),
        ),
        SwitchListTile(
          value: _partnerSharing,
          activeThumbColor: AppColors.burgundy,
          title: LocalizedText('Partner sharing'),
          subtitle: LocalizedText(
            'Allow sharing based on partner permissions.',
          ),
          onChanged: (value) => _changeConsent('Partner sharing', value),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: LocalizedText('Done'),
        ),
      ],
    ),
  );
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: LocalizedText('Help & Support'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _Faq(
          question: 'How do I register?',
          answer: 'Use the registration option on the login screen and follow the verification steps.',
        ),
        _Faq(
          question: 'How do appointments work?',
          answer: 'Use Appointments to request, view, reschedule, or cancel appointments.',
        ),
        _Faq(
          question: 'Where is my treatment overview?',
          answer: 'Open My Journey from the dashboard navigation.',
        ),
        _Faq(
          question: 'Are health records available?',
          answer: 'Only records published by the clinic appear in the app.',
        ),
        _Faq(
          question: 'How do I change account settings?',
          answer: 'Open your profile from the dashboard avatar.',
        ),
        SizedBox(height: 18),
        LocalizedText(
          'Contact support details are not configured in this prototype.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
      ],
    ),
  );
}

class _Faq extends StatelessWidget {
  final String question;
  final String answer;

  const _Faq({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(
      question,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          answer,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    ],
  );
}
