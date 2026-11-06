import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../appointments/presentation/appointment_dashboard_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import 'widgets/dashboard_home_content.dart';
import 'widgets/patient_profile_screen.dart';
import 'widgets/patient_services_screen.dart';

export 'widgets/dashboard_home_content.dart' show DashboardPatientState;

class DashboardScreen extends StatefulWidget {
  final String patientName;
  final DashboardPatientState patientState;
  final String mobileNumber;
  final String dateOfBirth;
  final String preferredLanguage;

  const DashboardScreen({
    super.key,
    required this.patientName,
    this.patientState = DashboardPatientState.ivf,
    this.mobileNumber = '',
    this.dateOfBirth = '',
    this.preferredLanguage = '',
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

  @override
  Widget build(BuildContext context) {
    const navigationLabels = [
      'Home',
      'My Journey',
      'Appointments',
      'Health Records',
      'More',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientServicesScreen(
                    patientName: _patientName,
                    mobileNumber: _mobileNumber,
                    dateOfBirth: _dateOfBirth,
                    preferredLanguage: _preferredLanguage,
                    patientState: widget.patientState,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Thaai Seyazhi',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: NotificationService.instance,
              builder: (context, child) {
                final unread = NotificationService.instance.unreadCount;
                return IconButton(
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
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientProfileScreen(
                      patientName: _patientName,
                      patientInitials: _initials,
                      patientState: widget.patientState,
                      mobileNumber: _mobileNumber,
                      dateOfBirth: _dateOfBirth,
                      preferredLanguage: _preferredLanguage,
                      onProfileUpdated: (profile) {
                        if (!mounted) return;
                        setState(() {
                          _patientName = profile.name;
                          _mobileNumber = profile.mobile;
                          _dateOfBirth = profile.dateOfBirth;
                          _preferredLanguage = profile.language;
                        });
                      },
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.blushPink,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _selectedIndex == 0
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DashboardHomeContent(
                  patientName: _patientName,
                  patientState: widget.patientState,
                ),
              )
            : _selectedIndex == 2
                ? AppointmentDashboardScreen(
                    patientName: _patientName,
                    mobileNumber: _mobileNumber,
                  )
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
            selectedFontSize: 9,
            unselectedFontSize: 9,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_outline),
                label: 'My Journey',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                label: 'Appointments',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
                label: 'Health Records',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_rounded),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
