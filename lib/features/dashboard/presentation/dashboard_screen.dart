import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/login_screen.dart';
import '../../appointments/presentation/appointment_dashboard_screen.dart';
import '../../appointments/presentation/data/appointment_data.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../medical_records/presentation/medical_records_screen.dart';
import '../../auth/presentation/linked_member/linked_member_access_screen.dart';
import '../../partner_access/data/partner_link_service.dart';
import 'journey_screen.dart';
import 'widgets/dashboard_home_content.dart';
import 'widgets/patient_profile_screen.dart';
import 'widgets/patient_services_screen.dart';

export 'widgets/dashboard_home_content.dart' show DashboardPatientState;

class DashboardScreen extends StatefulWidget {
  final String patientName;
  final String patientId;
  final DashboardPatientState patientState;
  final String mobileNumber;
  final String dateOfBirth;
  final String preferredLanguage;
  final String accountId;
  final bool isLinkedPartner;
  final String partnerUserName;
  final String partnerMobile;
  final String partnerLinkId;
  final Map<String, bool> partnerPermissions;
  final String dataOwnerAccountId;

  const DashboardScreen({
    super.key,
    required this.patientName,
    this.patientId = '',
    this.patientState = DashboardPatientState.ivf,
    this.mobileNumber = '',
    this.dateOfBirth = '',
    this.preferredLanguage = '',
    this.accountId = '',
    this.isLinkedPartner = false,
    this.partnerUserName = '',
    this.partnerMobile = '',
    this.partnerLinkId = '',
    this.partnerPermissions = const {},
    this.dataOwnerAccountId = '',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late String _patientName;
  late String _mobileNumber;
  late String _dateOfBirth;
  late String _preferredLanguage;
  bool _partnerLinkActive = false;
  bool _partnerAuthorizationLoading = true;
  bool _accountContextLoading = true;
  Map<String, bool> _activePartnerPermissions = const {};

  @override
  void initState() {
    super.initState();
    _patientName = widget.patientName;
    _mobileNumber = widget.mobileNumber;
    _dateOfBirth = widget.dateOfBirth;
    _preferredLanguage = widget.preferredLanguage;
    if (widget.isLinkedPartner) {
      PartnerLinkService.changes.addListener(_refreshPartnerAuthorization);
    }
    final accountId = widget.accountId.isEmpty
        ? widget.mobileNumber
        : widget.accountId;
    if (accountId.isNotEmpty) {
      LocaleService.setAccount(accountId);
      BiometricService.instance.startSession(accountId);
    } else if (_preferredLanguage.isNotEmpty) {
      LocaleService.setLanguage(
        _preferredLanguage == 'Tamil' || _preferredLanguage == 'தமிழ்'
            ? 'ta'
            : 'en',
      );
    }
    _loadAccountContext();
  }

  Future<void> _loadAccountContext() async {
    final dataOwner = widget.dataOwnerAccountId.isEmpty
        ? (widget.isLinkedPartner ? '' : widget.accountId)
        : widget.dataOwnerAccountId;
    await initializeAppointmentData(
      accountId: dataOwner.isEmpty ? null : dataOwner,
    );
    await NotificationService.instance.setAccount(
      dataOwner.isEmpty ? 'guest' : dataOwner,
    );
    if (NotificationService.instance.isInitialized) {
      await scheduleActiveAppointmentReminders();
    }
    if (widget.isLinkedPartner) await _refreshPartnerAuthorization();
    if (mounted) setState(() => _accountContextLoading = false);
  }

  @override
  void dispose() {
    if (widget.isLinkedPartner) {
      PartnerLinkService.changes.removeListener(_refreshPartnerAuthorization);
    }
    super.dispose();
  }

  Future<void> _refreshPartnerAuthorization() async {
    final link = await PartnerLinkService().activeLinkForPartner(
      widget.partnerMobile,
      partnerUserId: widget.accountId,
    );
    if (!mounted) return;
    setState(() {
      _partnerLinkActive = link != null;
      _activePartnerPermissions = link?.permissions ?? const <String, bool>{};
      _partnerAuthorizationLoading = false;
    });
  }

  Map<String, bool> get _effectivePartnerPermissions => widget.isLinkedPartner
      ? _activePartnerPermissions
      : widget.partnerPermissions;

  String get _initials {
    final parts = _patientName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isEmpty ? '' : parts.first[0].toUpperCase();
  }

  Widget _placeholderPage(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _profilePage() {
    if (widget.isLinkedPartner) {
      return _PartnerAccountProfile(
        name: widget.partnerUserName,
        mobile: widget.partnerMobile,
        linkId: widget.partnerLinkId,
        onLogout: _logoutPartner,
      );
    }
    return PatientProfileScreen(
      patientName: _patientName,
      patientInitials: _initials,
      patientId: widget.patientId,
      patientState: widget.patientState,
      mobileNumber: _mobileNumber,
      dateOfBirth: _dateOfBirth,
      preferredLanguage: _currentLanguage,
      accountId: widget.accountId.isEmpty
          ? widget.mobileNumber
          : widget.accountId,
      onProfileUpdated: (profile) {
        if (!mounted) return;
        setState(() {
          _patientName = profile.name;
          _mobileNumber = profile.mobile;
          _dateOfBirth = profile.dateOfBirth;
          _preferredLanguage = profile.language;
        });
      },
    );
  }

  String get _currentLanguage =>
      LocaleService.locale.value.languageCode == 'ta' ? 'Tamil' : 'English';

  bool _hasPermission(String category) =>
      !widget.isLinkedPartner ||
      (_partnerLinkActive && _effectivePartnerPermissions[category] == true);

  Widget _restricted(String category) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: LocalizedText(
        'The patient has not shared $category with this account.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    ),
  );

  Future<void> _selectTab(int index) async {
    if (widget.isLinkedPartner) await _refreshPartnerAuthorization();
    if (mounted) setState(() => _selectedIndex = index);
  }

  Future<void> _logoutPartner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalizedText('Log out?'),
        content: const LocalizedText(
          'Your saved records remain with their patient account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LocalizedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LocalizedText('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await LocaleService.resetForLogout();
    await NotificationService.instance.resetForLogout();
    appointmentStore.clearActiveAccount();
    BiometricService.instance.endSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final navigationLabels = [
      l10n.home,
      l10n.myJourney,
      l10n.appointments,
      l10n.healthRecords,
      l10n.profile,
    ];
    final selectedContent = _accountContextLoading
        ? const Center(child: CircularProgressIndicator())
        : switch (_selectedIndex) {
            0 => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: DashboardHomeContent(
                patientName: _patientName,
                mobileNumber: _mobileNumber,
                patientId: widget.patientId,
                patientState: widget.patientState,
                isLinkedPartner: widget.isLinkedPartner,
                partnerPermissions: _effectivePartnerPermissions,
                onNavigate: (index) => setState(() => _selectedIndex = index),
              ),
            ),
            1 =>
              _hasPermission('Treatment Journey')
                  ? JourneyScreen(
                      treatmentName: _treatmentName,
                      isLinkedPartner: widget.isLinkedPartner,
                      partnerPermissions: _effectivePartnerPermissions,
                      onNavigate: (index) =>
                          setState(() => _selectedIndex = index),
                    )
                  : _restricted('the Treatment Journey'),
            2 =>
              _hasPermission('Appointments')
                  ? AppointmentDashboardScreen(
                      patientName: _patientName,
                      mobileNumber: _mobileNumber,
                    )
                  : _restricted('Appointments'),
            3 =>
              (_hasPermission('Medical Reports') ||
                      _hasPermission('Discharge Summary') ||
                      _hasPermission('Bills and Payments') ||
                      _hasPermission('IP Billing') ||
                      _hasPermission('Prescriptions'))
                  ? MedicalRecordsScreen(
                      patientName: _patientName,
                      isLinkedPartner: widget.isLinkedPartner,
                      partnerPermissions: _effectivePartnerPermissions,
                    )
                  : _restricted('Records'),
            4 => _profilePage(),
            _ => _placeholderPage(navigationLabels[_selectedIndex]),
          };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Material(
              color: AppColors.blushPink,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: widget.isLinkedPartner
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientServicesScreen(
                            patientName: _patientName,
                            patientId: widget.patientId,
                            mobileNumber: _mobileNumber,
                            dateOfBirth: _dateOfBirth,
                            preferredLanguage: _currentLanguage,
                            patientState: widget.patientState,
                            accountId: widget.accountId.isEmpty
                                ? widget.mobileNumber
                                : widget.accountId,
                          ),
                        ),
                      ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: LocalizedText(
                'Thaai Seyali',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: NotificationService.instance,
              builder: (context, child) {
                final unread =
                    !widget.isLinkedPartner ||
                        _hasPermission('Notifications and clinic updates')
                    ? NotificationService.instance.unreadCount
                    : 0;
                return IconButton(
                  tooltip: l10n.notifications,
                  onPressed:
                      widget.isLinkedPartner &&
                          !_hasPermission('Notifications and clinic updates')
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(
                              isLinkedPartner: widget.isLinkedPartner,
                              partnerPermissions: _effectivePartnerPermissions,
                            ),
                          ),
                        ),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.primaryText,
                        size: 23,
                      ),
                      if (unread > 0)
                        Positioned(
                          right: -7,
                          top: -7,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 17,
                              minHeight: 17,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.burgundy,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (widget.isLinkedPartner)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: AppColors.blushPink,
                child: Text(
                  _partnerAuthorizationLoading
                      ? 'Checking linked patient access...'
                      : _partnerLinkActive
                      ? "Viewing $_patientName's Linked Patient Profile"
                      : 'Patient link is no longer active. Shared information is unavailable.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(child: selectedContent),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _selectTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.white,
            selectedItemColor: AppColors.burgundy,
            unselectedItemColor: AppColors.secondaryText,
            selectedFontSize: 10,
            unselectedFontSize: 9,
            elevation: 0,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            selectedIconTheme: const IconThemeData(size: 23),
            unselectedIconTheme: const IconThemeData(size: 21),
            landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
            items: [
              BottomNavigationBarItem(
                icon: const _NavigationIcon(
                  icon: Icons.home_outlined,
                  selected: false,
                ),
                activeIcon: const _NavigationIcon(
                  icon: Icons.home_rounded,
                  selected: true,
                ),
                label: l10n.home,
              ),
              BottomNavigationBarItem(
                icon: const _NavigationIcon(
                  icon: Icons.favorite_outline,
                  selected: false,
                ),
                activeIcon: const _NavigationIcon(
                  icon: Icons.favorite_rounded,
                  selected: true,
                ),
                label: l10n.myJourney,
              ),
              BottomNavigationBarItem(
                icon: const _NavigationIcon(
                  icon: Icons.calendar_month_outlined,
                  selected: false,
                ),
                activeIcon: const _NavigationIcon(
                  icon: Icons.calendar_month_rounded,
                  selected: true,
                ),
                label: l10n.appointments,
              ),
              BottomNavigationBarItem(
                icon: const _NavigationIcon(
                  icon: Icons.folder_outlined,
                  selected: false,
                ),
                activeIcon: const _NavigationIcon(
                  icon: Icons.folder_rounded,
                  selected: true,
                ),
                label: l10n.healthRecords,
              ),
              BottomNavigationBarItem(
                icon: const _NavigationIcon(
                  icon: Icons.person_outline_rounded,
                  selected: false,
                ),
                activeIcon: const _NavigationIcon(
                  icon: Icons.person_rounded,
                  selected: true,
                ),
                label: l10n.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _treatmentName {
    switch (widget.patientState) {
      case DashboardPatientState.ivf:
        return 'IVF Cycle 1';
      case DashboardPatientState.icsi:
        return 'ICSI Treatment';
      case DashboardPatientState.iui:
        return 'IUI Treatment';
      case DashboardPatientState.fet:
        return 'Frozen Embryo Transfer (FET)';
      case DashboardPatientState.embryoTransfer:
        return 'Embryo Transfer';
      case DashboardPatientState.twoWeekWait:
        return 'Two-Week Wait';
      case DashboardPatientState.followUpCare:
      case DashboardPatientState.postProcedureRecovery:
        return 'Follow-up Care';
      case DashboardPatientState.newPatient:
        return 'Care pathway pending';
    }
  }
}

class _NavigationIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _NavigationIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: 42,
    height: 28,
    decoration: BoxDecoration(
      color: selected ? AppColors.blushPink : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
    ),
    alignment: Alignment.center,
    child: Icon(icon),
  );
}

class _PartnerAccountProfile extends StatelessWidget {
  final String name;
  final String mobile;
  final String linkId;
  final VoidCallback onLogout;

  const _PartnerAccountProfile({
    required this.name,
    required this.mobile,
    required this.linkId,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        color: AppColors.white,
        elevation: 0,
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.blushPink,
            child: Icon(Icons.person_outline, color: AppColors.burgundy),
          ),
          title: Text(name),
          subtitle: LocalizedText('Partner account · $mobile'),
        ),
      ),
      const SizedBox(height: 12),
      const LocalizedText(
        'This is your separate partner account. It does not own a patient medical record.',
        style: TextStyle(color: AppColors.secondaryText, height: 1.5),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LinkedMemberAccessScreen(mobileNumber: mobile),
          ),
        ),
        icon: const Icon(Icons.link_rounded),
        label: const LocalizedText('Link to Patient'),
      ),
      if (linkId.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LocalizedText(
            'To change shared access, ask the patient to update permissions or revoke the link.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const LocalizedText('Log out'),
        ),
      ),
    ],
  );
}
