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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: AppColors.primaryText.withValues(alpha: 0.06),
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentDetailsScreen(
              appointment: appointment,
              patientName: patientName,
              mobileNumber: mobileNumber,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.blushPink,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.burgundy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      appointment.doctorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppointmentStatusBadge(appointment.status),
                ],
              ),
              const SizedBox(height: 12),
              LocalizedText(
                '${_date(appointment.date)} · ${appointment.time}',
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              LocalizedText(
                '${appointment.appointmentType} · ${appointment.consultationMode}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                appointment.clinic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
}
