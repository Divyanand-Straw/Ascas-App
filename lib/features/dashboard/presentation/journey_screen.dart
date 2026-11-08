import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/dashboard_card.dart';
import 'widgets/dashboard_home_content.dart';

class JourneyScreen extends StatelessWidget {
  final String treatmentName;
  final DashboardPatientState patientState;

  const JourneyScreen({
    super.key,
    required this.treatmentName,
    required this.patientState,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Journey',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
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
          _OvulationCard(patientState: patientState),
          const SizedBox(height: 16),
          _TimelineCard(
            title: 'IUI Timeline',
            icon: Icons.route_outlined,
            milestones: const [
              _Milestone('Initial consultation', 'Date to be confirmed', true),
              _Milestone('Follicle monitoring', 'Date to be confirmed', false),
              _Milestone('IUI procedure', 'Date to be confirmed', false),
            ],
          ),
          const SizedBox(height: 16),
          _TimelineCard(
            title: 'IVF Timeline',
            icon: Icons.timeline_rounded,
            milestones: const [
              _Milestone('Care pathway setup', 'Completed', true),
              _Milestone(
                'Current treatment stage',
                'Clinic update pending',
                true,
              ),
              _Milestone('Next milestone', 'Upcoming', false),
            ],
          ),
          const SizedBox(height: 18),
          _MedicationScheduleCard(),
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
          child: Text(
            treatmentName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.burgundy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OvulationCard extends StatelessWidget {
  final DashboardPatientState patientState;

  const _OvulationCard({required this.patientState});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.calendar_month_outlined,
            title: 'Ovulation Tracker',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.blushPink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_note_outlined,
                  color: AppColors.burgundy,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Cycle information will appear after it is confirmed by your care team.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailLine(
            label: 'Current cycle',
            value: patientState == DashboardPatientState.newPatient
                ? 'Not assigned'
                : 'Placeholder cycle',
          ),
          const _DetailLine(label: 'Ovulation date', value: 'To be confirmed'),
          const SizedBox(height: 12),
          const _StatusPill(
            label: 'Tracking not started',
            color: AppColors.dustyPink,
          ),
          const SizedBox(height: 14),
          _SecondaryAction(label: 'View Details', onPressed: () {}),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Milestone> milestones;

  const _TimelineCard({
    required this.title,
    required this.icon,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    final completed = milestones.where((item) => item.active).length;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, title: title),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completed / milestones.length,
              minHeight: 6,
              backgroundColor: AppColors.blushPink,
              valueColor: const AlwaysStoppedAnimation(AppColors.burgundy),
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < milestones.length; index++)
            _TimelineMilestone(
              milestone: milestones[index],
              isLast: index == milestones.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineMilestone extends StatelessWidget {
  final _Milestone milestone;
  final bool isLast;

  const _TimelineMilestone({required this.milestone, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = milestone.active ? AppColors.burgundy : AppColors.dustyPink;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: milestone.active ? color : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 48, color: AppColors.divider),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  milestone.date,
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
        ),
      ],
    );
  }
}

class _MedicationScheduleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.medication_outlined,
            title: 'Medication Schedule',
          ),
          const SizedBox(height: 14),
          const _DetailLine(
            label: 'Medication',
            value: 'Medication placeholder',
          ),
          const _DetailLine(label: 'Dosage', value: 'As prescribed'),
          const _DetailLine(label: 'Scheduled time', value: 'To be confirmed'),
          const SizedBox(height: 8),
          const _StatusPill(
            label: 'Schedule not published',
            color: AppColors.dustyPink,
          ),
          const SizedBox(height: 14),
          _SecondaryAction(label: 'View Schedule', onPressed: () {}),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.blushPink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.burgundy, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
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
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.burgundy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryAction({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.burgundy,
          side: const BorderSide(color: AppColors.burgundy),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _Milestone {
  final String name;
  final String date;
  final bool active;

  const _Milestone(this.name, this.date, this.active);
}
