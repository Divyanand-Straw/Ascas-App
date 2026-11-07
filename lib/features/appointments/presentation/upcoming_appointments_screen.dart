import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'appointment_detail_screen.dart';
import 'data/appointment_data.dart';
import 'models/appointment_models.dart';
import 'widgets/appointment_widgets.dart';

class UpcomingAppointmentsScreen extends StatelessWidget {
  final String patientName;
  final String mobileNumber;

  const UpcomingAppointmentsScreen({
    super.key,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  Widget build(BuildContext context) {
    final appointments = sampleAppointments
        .where((appointment) => appointment.status != 'Cancelled')
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Upcoming appointments'),
      ),
      body: appointments.isEmpty
          ? const Center(
              child: LocalizedText(
                'No upcoming appointments.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ...appointments.map(
                  (appointment) => _card(context, appointment),
                ),
                const SizedBox(height: 8),
                LocalizedText(
                  'Prototype sample appointments only. They are not real bookings.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card(BuildContext context, Appointment appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appointment.doctorName,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppointmentStatusBadge(appointment.status),
            ],
          ),
          const SizedBox(height: 9),
          LocalizedText(
            '${_date(appointment.date)} · ${appointment.time}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          LocalizedText(
            '${appointment.appointmentType} · ${appointment.consultationMode}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.clinic,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailsScreen(
                    appointment: appointment,
                    patientName: patientName,
                    mobileNumber: mobileNumber,
                  ),
                ),
              ),
              child: LocalizedText('View details'),
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
}
