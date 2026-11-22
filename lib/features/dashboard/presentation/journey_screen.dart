import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../data/treatment_journey_data.dart';
import 'journey_sections.dart';

class JourneyScreen extends StatelessWidget {
  final String treatmentName;
  final ValueChanged<int>? onNavigate;
  final bool showPageHeader;
  final bool isLinkedPartner;
  final Map<String, bool> partnerPermissions;

  const JourneyScreen({
    super.key,
    required this.treatmentName,
    this.onNavigate,
    this.showPageHeader = true,
    this.isLinkedPartner = false,
    this.partnerPermissions = const {},
  });

  bool _canView(String category) =>
      !isLinkedPartner || partnerPermissions[category] == true;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      if (showPageHeader) ...[
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
          'Your trackers and clinic-managed treatment information.',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
      ],
      if (!isLinkedPartner || _canView('Treatment Journey')) ...[
        JourneySectionCard(
          title: 'Ovulation Tracker',
          subtitle:
              'Cycle details and clearly labelled calendar estimates.',
          icon: Icons.calendar_month_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OvulationTrackerScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        JourneySectionCard(
          title: 'IUI Timeline',
          subtitle: 'Milestones and updates provided by your clinic.',
          icon: Icons.timeline_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TreatmentTimelineScreen(
                title: 'IUI Timeline',
                stages: const [
                  'Initial consultation',
                  'Baseline scan',
                  'Follicular monitoring',
                  'Trigger injection, if prescribed',
                  'IUI procedure',
                  'Post-procedure follow-up',
                  'Pregnancy test appointment',
                ],
                pathway: pathwayFor('IUI treatment'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        JourneySectionCard(
          title: 'IVF Timeline',
          subtitle: 'Applicable stages, dates and clinic updates.',
          icon: Icons.timeline_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TreatmentTimelineScreen(
                title: 'IVF Timeline',
                stages: const [
                  'Initial consultation',
                  'Baseline scan',
                  'Ovarian stimulation',
                  'Follicular monitoring',
                  'Trigger injection, if prescribed',
                  'Egg retrieval',
                  'Fertilization',
                  'Embryo development',
                  'Embryo transfer, if applicable',
                  'Pregnancy test',
                ],
                pathway: pathwayFor(treatmentName.toLowerCase().contains('ivf')
                    ? treatmentName
                    : 'IVF treatment'),
              ),
            ),
          ),
        ),
      ],
      if (!isLinkedPartner || _canView('Medication schedules')) ...[
        const SizedBox(height: 12),
        JourneySectionCard(
          title: 'Medication Schedule',
          subtitle: 'Reminder tracking; clinic prescriptions remain unchanged.',
          icon: Icons.medication_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MedicationScheduleScreen(),
            ),
          ),
        ),
      ],
        if (isLinkedPartner &&
            !_canView('Treatment Journey') &&
            !_canView('Medication schedules'))
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: LocalizedText(
              'The patient has not shared journey or medication information with this account.',
              style: TextStyle(color: AppColors.secondaryText, height: 1.5),
            ),
          ),
      ],
    ),
  );
}
