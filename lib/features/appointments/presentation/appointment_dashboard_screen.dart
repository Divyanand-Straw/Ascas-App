import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'data/appointment_data.dart';
import 'widgets/appointment_widgets.dart';
import 'doctor_information_screen.dart';
import 'appointment_detail_screen.dart';
import 'appointment_history_screen.dart';
import 'clinic_location_screen.dart';
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
  Widget build(BuildContext context) {
    final appointment = appointmentStore.nearestUpcoming;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointments',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'YOUR NEXT VISIT',
            style: TextStyle(
              color: AppColors.dustyPink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          if (appointment != null)
            AppointmentCard(
              appointment: appointment,
              onTap: () => _open(
                context,
                AppointmentDetailsScreen(
                  appointment: appointment,
                  patientName: patientName,
                  mobileNumber: mobileNumber,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No upcoming appointments.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
          const SizedBox(height: 14),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 12.0;
              final width = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: AppointmentActionTile(
                      icon: Icons.add_circle_outline,
                      title: 'REQUEST',
                      subtitle: 'Choose a doctor and time',
                      onTap: () => _open(
                        context,
                        DoctorInformationScreen(
                          patientName: patientName,
                          mobileNumber: mobileNumber,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: AppointmentActionTile(
                      icon: Icons.event_available_outlined,
                      title: 'UPCOMING',
                      subtitle: 'View upcoming visits',
                      onTap: () => _open(
                        context,
                        UpcomingAppointmentsScreen(
                          patientName: patientName,
                          mobileNumber: mobileNumber,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: AppointmentActionTile(
                      icon: Icons.history_outlined,
                      title: 'HISTORY',
                      subtitle: 'Past consultations',
                      onTap: () => _open(
                        context,
                        const AppointmentHistoryScreen(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: AppointmentActionTile(
                      icon: Icons.location_on_outlined,
                      title: 'CLINIC',
                      subtitle: 'Directions and details',
                      onTap: () => _open(
                        context,
                        const ClinicLocationScreen(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'APPOINTMENT REQUESTS',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _open(
                  context,
                  const AppointmentInfoScreen(
                    title: 'Appointment requests',
                    description: 'Submitted appointment requests will appear here.',
                  ),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Row(
              children: [
                Icon(Icons.pending_actions_outlined,
                    color: AppColors.burgundy),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fertility consultation',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '14 May · 10:30 AM · Sample slot',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                AppointmentStatusBadge('Requested'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Prototype sample data only. Live doctor availability will be supplied by Thaai Seyazhi.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
