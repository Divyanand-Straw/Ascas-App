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
    final completed = sampleHistory
        .where((appointment) => appointment.status == 'Completed')
        .toList()
      ..sort((first, second) => second.date.compareTo(first.date));
    final cancelled = sampleHistory
        .where((appointment) => appointment.status == 'Cancelled')
        .toList()
      ..sort((first, second) => second.date.compareTo(first.date));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Appointment history'),
      ),
      body: completed.isEmpty && cancelled.isEmpty
          ? const Center(
              child: LocalizedText(
                'No appointment history yet.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (completed.isNotEmpty) ...[
                  const _HistorySectionHeading(title: 'Completed'),
                  ...completed.map((appointment) => _card(context, appointment)),
                ],
                if (cancelled.isNotEmpty) ...[
                  const _HistorySectionHeading(title: 'Cancelled'),
                  ...cancelled.map((appointment) => _card(context, appointment)),
                ],
              ],
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryText.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.burgundy,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.doctorName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  LocalizedText(
                    '${_date(appointment.date)} · ${appointment.time} · ${appointment.appointmentType}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.consultationMode,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _HistorySectionHeading extends StatelessWidget {
  final String title;

  const _HistorySectionHeading({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: LocalizedText(
      title,
      style: const TextStyle(
        color: AppColors.burgundy,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
