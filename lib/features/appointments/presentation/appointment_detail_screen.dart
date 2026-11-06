import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'cancellation_confirmation_screen.dart';
import 'models/appointment_models.dart';
import 'reschedule_request_screen.dart';
import 'widgets/appointment_widgets.dart';

class AppointmentDetailsScreen extends StatelessWidget {
  final Appointment appointment;
  final String patientName;
  final String mobileNumber;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
    this.patientName = '',
    this.mobileNumber = '',
  });

  @override
  Widget build(BuildContext context) {
    final canChange = appointment.status != 'Cancelled' &&
        appointment.status != 'Completed';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Appointment details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROTOTYPE REFERENCE',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appointment.reference,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  appointment.title,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                AppointmentStatusBadge(appointment.status),
                const SizedBox(height: 18),
                _detail('Doctor', appointment.doctorName),
                _detail('Specialty', appointment.specialty),
                _detail('Date', _date(appointment.date)),
                _detail('Time', appointment.time),
                _detail('Type', appointment.appointmentType),
                _detail('Location', appointment.clinic),
                _detail('Mode', appointment.consultationMode),
                _detail(
                  'Patient',
                  patientName.isEmpty ? appointment.patientName : patientName,
                ),
                _detail('Notes', appointment.notes),
              ],
            ),
          ),
          if (canChange) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RescheduleRequestScreen(
                    appointment: appointment,
                    patientName: patientName,
                    mobileNumber: mobileNumber,
                  ),
                ),
              ),
              child: const Text('Reschedule appointment'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CancellationConfirmationScreen(
                    appointment: appointment,
                  ),
                ),
              ),
              child: const Text('Cancel appointment'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to appointments'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Prototype sample data only. Status changes apply during this app session.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
}

class AppointmentDetailScreen extends AppointmentDetailsScreen {
  const AppointmentDetailScreen({
    super.key,
    required super.appointment,
  });
}

class AppointmentInfoScreen extends StatelessWidget {
  final String title;
  final String description;

  const AppointmentInfoScreen({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
