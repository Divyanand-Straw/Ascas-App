import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../appointments/presentation/appointment_detail_screen.dart';
import '../../appointments/presentation/data/appointment_data.dart';
import '../../appointments/presentation/models/appointment_models.dart';
import '../../medication/presentation/medication_screen.dart';
import 'widgets/dashboard_card.dart';
import 'widgets/dashboard_home_content.dart';

class JourneyScreen extends StatelessWidget {
  final String treatmentName;

  const JourneyScreen({super.key, required this.treatmentName});

  @override
  Widget build(BuildContext context) {
    final appointment = appointmentStore.nearestUpcoming;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LocalizedText(
            'My Journey',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const LocalizedText(
            'A simple view of your clinic-managed care pathway.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _JourneyOverviewCard(treatmentName: treatmentName),
          const SizedBox(height: 16),
          const _JourneyStatusCard(),
          const SizedBox(height: 16),
          const _TreatmentTimelineCard(),
          if (appointment != null) ...[
            const SizedBox(height: 16),
            _JourneyAppointmentCard(appointment: appointment),
          ],
          const SizedBox(height: 16),
          const _MedicationCard(),
          const SizedBox(height: 22),
          const DashboardSectionHeader(title: 'Recent Clinic Updates'),
          const SizedBox(height: 12),
          const RecentClinicUpdates(limit: 3),
        ],
      ),
    );
  }
}

class _JourneyOverviewCard extends StatelessWidget {
  final String treatmentName;

  const _JourneyOverviewCard({required this.treatmentName});

  @override
  Widget build(BuildContext context) => DashboardCard(
    color: AppColors.blushPink,
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.favorite_outline_rounded,
            color: AppColors.burgundy,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LocalizedText(
                'CURRENT TREATMENT',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 4),
              LocalizedText(
                treatmentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _JourneyStatusCard extends StatelessWidget {
  const _JourneyStatusCard();

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardListItem(
          title: 'Current treatment stage',
          subtitle: 'Your care team has not published a stage update yet.',
          icon: Icons.timeline_rounded,
        ),
        const Divider(height: 16, color: AppColors.divider),
        const DashboardListItem(
          title: 'Treatment progress',
          subtitle: 'Confirmed milestones and progress will appear here when available.',
          icon: Icons.flag_outlined,
        ),
        const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.secondaryText,
              size: 16,
            ),
            SizedBox(width: 6),
            Expanded(
              child: LocalizedText(
                'Clinical stages are managed by your care team.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TreatmentTimelineCard extends StatelessWidget {
  const _TreatmentTimelineCard();

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(title: 'Treatment timeline'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.event_note_outlined,
                color: AppColors.burgundy,
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: LocalizedText(
                  'Your clinic-confirmed treatment milestones will appear here.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _JourneyAppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _JourneyAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(title: 'Next Appointment'),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.burgundy,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.doctorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${appointment.appointmentType} · ${appointment.date.day}/${appointment.date.month}/${appointment.date.year}, ${appointment.time}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AppointmentDetailsScreen(appointment: appointment),
              ),
            ),
            child: const LocalizedText('View appointment'),
          ),
        ),
      ],
    ),
  );
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard();

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.blushPink,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.medication_outlined,
            color: AppColors.burgundy,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: LocalizedText(
            'Prescription details will appear here when published by your clinic.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        IconButton(
          tooltip: localizedText(context, 'Medication Management'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MedicationScreen()),
          ),
          icon: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.burgundy,
            size: 17,
          ),
        ),
      ],
    ),
  );
}
