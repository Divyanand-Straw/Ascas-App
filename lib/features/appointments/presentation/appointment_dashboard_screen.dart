import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import 'appointment_history_screen.dart';
import 'clinic_location_screen.dart';
import 'doctor_information_screen.dart';
import 'upcoming_appointments_screen.dart';

class AppointmentDashboardScreen extends StatelessWidget {
  final String patientName;
  final String mobileNumber;

  const AppointmentDashboardScreen({
    super.key,
    required this.patientName,
    required this.mobileNumber,
  });

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LocalizedText(
          'Appointments',
          style: TextStyle(
            color: _primaryText,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const LocalizedText(
          'Manage your clinic visits and appointments.',
          style: TextStyle(color: _secondaryText, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = constraints.maxWidth < 360 ? 10.0 : 14.0;
            return GridView.count(
              key: const ValueKey('appointment-action-grid'),
              crossAxisCount: 2,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: constraints.maxWidth < 360 ? 0.94 : 1.02,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _AppointmentActionCard(
                  key: const ValueKey('appointment-book-visit'),
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Book Visit',
                  description: 'Schedule a clinic appointment',
                  highlighted: true,
                  onTap: () => _open(
                    context,
                    DoctorInformationScreen(
                      patientName: patientName,
                      mobileNumber: mobileNumber,
                    ),
                  ),
                ),
                _AppointmentActionCard(
                  key: const ValueKey('appointment-upcoming'),
                  icon: Icons.event_available_rounded,
                  title: 'Upcoming',
                  description: 'View scheduled visits',
                  onTap: () => _open(
                    context,
                    UpcomingAppointmentsScreen(
                      patientName: patientName,
                      mobileNumber: mobileNumber,
                    ),
                  ),
                ),
                _AppointmentActionCard(
                  key: const ValueKey('appointment-history'),
                  icon: Icons.history_rounded,
                  title: 'History',
                  description: 'View previous appointments',
                  onTap: () => _open(context, const AppointmentHistoryScreen()),
                ),
                _AppointmentActionCard(
                  key: const ValueKey('appointment-clinic'),
                  icon: Icons.local_hospital_outlined,
                  title: 'Clinic',
                  description: 'Clinic information and facilities',
                  onTap: () => _open(context, const ClinicLocationScreen()),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _AppointmentActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool highlighted;
  final VoidCallback onTap;

  const _AppointmentActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted ? Colors.white : _burgundy;
    final secondary = highlighted ? _blush : _secondaryText;
    return Material(
      color: highlighted ? _burgundy : _blush,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primaryText.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 31),
              const Spacer(),
              LocalizedText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              LocalizedText(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: secondary, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _burgundy = Color(0xFF6B1837);
const _blush = Color(0xFFF8E9EE);
const _primaryText = Color(0xFF30232A);
const _secondaryText = Color(0xFF806D76);
