import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'appointment_detail_screen.dart';
import 'data/appointment_data.dart';
import 'models/appointment_models.dart';
import 'widgets/appointment_widgets.dart';

class AppointmentHistoryScreen extends StatefulWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  State<AppointmentHistoryScreen> createState() =>
      _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final completed =
        sampleHistory
            .where((appointment) => appointment.status == 'Completed')
            .toList()
          ..sort((first, second) => second.date.compareTo(first.date));
    final cancelled =
        sampleHistory
            .where((appointment) => appointment.status == 'Cancelled')
            .toList()
          ..sort((first, second) => second.date.compareTo(first.date));
    final visibleCompleted = _filter == 'Cancelled'
        ? <Appointment>[]
        : completed;
    final visibleCancelled = _filter == 'Completed'
        ? <Appointment>[]
        : cancelled;
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
                Wrap(
                  spacing: 8,
                  children: ['All', 'Completed', 'Cancelled'].map((filter) {
                    return ChoiceChip(
                      label: LocalizedText(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                      selectedColor: AppColors.blushPink,
                      labelStyle: const TextStyle(
                        color: AppColors.burgundy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                if (visibleCompleted.isNotEmpty) ...[
                  const _HistorySectionHeading(title: 'Completed'),
                  ...visibleCompleted.map(
                    (appointment) => _card(context, appointment),
                  ),
                ],
                if (visibleCancelled.isNotEmpty) ...[
                  const _HistorySectionHeading(title: 'Cancelled'),
                  ...visibleCancelled.map(
                    (appointment) => _card(context, appointment),
                  ),
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
                    '${_date(context, appointment.date)} · ${appointment.time}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    appointment.appointmentType,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
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

  static String _date(BuildContext context, DateTime date) {
    final month = localizedText(
      context,
      const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][date.month - 1],
    );
    return '${date.day} $month ${date.year}';
  }
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
