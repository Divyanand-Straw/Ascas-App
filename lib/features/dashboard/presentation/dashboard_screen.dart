import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../appointments/presentation/appointment_dashboard_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../medical_records/presentation/medical_records_screen.dart';
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

  const DashboardScreen({
    super.key,
    required this.patientName,
    this.patientId = '',
    this.patientState = DashboardPatientState.ivf,
    this.mobileNumber = '',
    this.dateOfBirth = '',
    this.preferredLanguage = '',
    this.accountId = '',
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

  @override
  void initState() {
    super.initState();
    _patientName = widget.patientName;
    _mobileNumber = widget.mobileNumber;
    _dateOfBirth = widget.dateOfBirth;
    _preferredLanguage = widget.preferredLanguage;
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
  }

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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientServicesScreen(
                      patientName: _patientName,
                      patientId: widget.patientId,
                      mobileNumber: _mobileNumber,
                      dateOfBirth: _dateOfBirth,
                      preferredLanguage: _currentLanguage,
                      patientState: widget.patientState,
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
                'Thaai Seyazhi',
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
                final unread = NotificationService.instance.unreadCount;
                return IconButton(
                  tooltip: l10n.notifications,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
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
        child: _selectedIndex == 0
            ? SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: DashboardHomeContent(
                  patientName: _patientName,
                  patientId: widget.patientId,
                  patientState: widget.patientState,
                  onNavigate: (index) => setState(() => _selectedIndex = index),
                ),
              )
            : _selectedIndex == 2
            ? AppointmentDashboardScreen(
                patientName: _patientName,
                mobileNumber: _mobileNumber,
              )
            : _selectedIndex == 1
            ? JourneyScreen(treatmentName: _treatmentName)
            : _selectedIndex == 3
            ? MedicalRecordsScreen(patientName: _patientName)
            : _selectedIndex == 4
            ? _profilePage()
            : _placeholderPage(navigationLabels[_selectedIndex]),
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
            onTap: (index) => setState(() => _selectedIndex = index),
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
