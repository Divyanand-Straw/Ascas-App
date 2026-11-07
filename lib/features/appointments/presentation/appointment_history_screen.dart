import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'appointment_detail_screen.dart';
import 'data/appointment_data.dart';
import 'models/appointment_models.dart';
import 'widgets/appointment_widgets.dart';

class AppointmentHistoryScreen extends StatelessWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Appointment history'),
      ),
      body: sampleHistory.isEmpty
          ? const Center(
              child: LocalizedText(
                'No appointment history yet.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: sampleHistory
                  .map((appointment) => _card(context, appointment))
                  .toList(),
            ),
    );
  }

  Widget _card(BuildContext context, Appointment appointment) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailsScreen(appointment: appointment),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: AppColors.burgundy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.doctorName,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  LocalizedText(
                    '${_date(appointment.date)} · ${appointment.appointmentType}',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.consultationMode,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            AppointmentStatusBadge(appointment.status),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
}
