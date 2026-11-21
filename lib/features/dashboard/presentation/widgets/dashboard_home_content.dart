import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/copyable_patient_id.dart';
import '../../../appointments/presentation/data/appointment_data.dart';
import '../../../appointments/presentation/appointment_detail_screen.dart';
import '../../../appointments/presentation/doctor_information_screen.dart';
import '../../../appointments/presentation/models/appointment_models.dart';
import '../../../communication/presentation/communication_screen.dart';
import '../../../education/presentation/education_screen.dart';
import '../../../medical_records/presentation/medical_records_screen.dart';
import '../../../medication/presentation/demo_reminder_card.dart';
import '../../../medication/presentation/medication_screen.dart';
import '../../data/treatment_journey_data.dart';
import '../journey_sections.dart';
import 'dashboard_card.dart';

enum DashboardPatientState {
  newPatient,
  ivf,
  icsi,
  iui,
  fet,
  embryoTransfer,
  twoWeekWait,
  postProcedureRecovery,
  followUpCare,
}

const _fertilityJourneyBurgundy = Color(0xFF6B1837);
const _fertilityJourneyBlush = Color(0xFFF8E9EE);
const _fertilityJourneyDustyPink = Color(0xFFC9879D);

class DashboardHomeContent extends StatelessWidget {
  final String patientName;
  final String mobileNumber;
  final String dateOfBirth;
  final String patientId;
  final DashboardPatientState patientState;
  final ValueChanged<int> onNavigate;
  final bool isLinkedPartner;
  final Map<String, bool> partnerPermissions;

  const DashboardHomeContent({
    super.key,
    required this.patientName,
    this.mobileNumber = '',
    this.dateOfBirth = '',
    this.patientId = '',
    required this.patientState,
    required this.onNavigate,
    this.isLinkedPartner = false,
    this.partnerPermissions = const {},
  });

  String get _initials {
    final parts = patientName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isEmpty ? 'P' : parts.first[0].toUpperCase();
  }

  String get _treatment => switch (patientState) {
    DashboardPatientState.ivf => 'IVF Cycle 1',
    DashboardPatientState.icsi => 'ICSI Treatment',
    DashboardPatientState.iui => 'IUI Treatment',
    DashboardPatientState.fet => 'Frozen Embryo Transfer (FET)',
    DashboardPatientState.embryoTransfer => 'Embryo Transfer',
    DashboardPatientState.twoWeekWait => 'Two-Week Wait',
    DashboardPatientState.postProcedureRecovery => 'Follow-up Care',
    DashboardPatientState.followUpCare => 'Follow-up Care',
    DashboardPatientState.newPatient => 'Care pathway pending',
  };

  String get _currentStage => switch (patientState) {
    DashboardPatientState.ivf => 'Ovarian stimulation',
    DashboardPatientState.icsi => 'Ovarian stimulation',
    DashboardPatientState.iui => 'Follicular monitoring',
    DashboardPatientState.fet => 'Cycle preparation',
    DashboardPatientState.embryoTransfer => 'Embryo transfer',
    DashboardPatientState.twoWeekWait => 'Two-week wait',
    DashboardPatientState.postProcedureRecovery => 'Post-procedure recovery',
    DashboardPatientState.followUpCare => 'Clinic follow-up',
    DashboardPatientState.newPatient => 'Clinic update pending',
  };

  bool _can(String category) =>
      !isLinkedPartner || partnerPermissions[category] == true;

  @override
  Widget build(BuildContext context) {
    final hasSharedCategory =
        !isLinkedPartner ||
        partnerPermissions.values.any((permission) => permission);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_can('Patient profile information'))
          _WelcomeSection(
            name: patientName,
            initials: _initials,
            patientId: patientId,
          ),
        if (!hasSharedCategory)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: LocalizedText(
              'The patient has not shared any information with this account yet.',
              style: TextStyle(color: AppColors.secondaryText, height: 1.5),
            ),
          ),
        if (_can('Patient profile information') &&
            patientState == DashboardPatientState.postProcedureRecovery) ...[
          const SizedBox(height: 20),
          const _AdmissionCard(),
        ],
        if (_can('Treatment Journey')) ...[
          const SizedBox(height: 22),
          _CurrentPathwayCard(
            treatment: _treatment,
            currentStage: _currentStage,
            onTap: () => onNavigate(1),
          ),
        ],
        if (_can('Appointments')) ...[
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: appointmentStore,
            builder: (context, _) => _UpcomingVisitCard(
              appointment: appointmentStore.nearestUpcoming,
              patientName: patientName,
              mobileNumber: mobileNumber,
            ),
          ),
        ],
        if (!isLinkedPartner) ...[
          const SizedBox(height: 22),
          _CareTeamSection(
            patientName: patientName,
            mobileNumber: mobileNumber,
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorInformationScreen(
                  patientName: patientName,
                  mobileNumber: mobileNumber,
                ),
              ),
            ),
          ),
        ],
        if (_can('Medication schedules')) ...[
          const SizedBox(height: 22),
          DashboardSectionHeader(
            title: 'Medication Reminders',
            action: 'View all',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MedicationScheduleScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _MedicationReminder(),
        ],
        if (_can('Prescriptions'))
          _SharedCategoryCard(
            title: 'Prescriptions',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MedicationScheduleScreen(),
              ),
            ),
          ),
        if (!isLinkedPartner) ...[
          const SizedBox(height: 22),
          const DashboardSectionHeader(title: 'Quick Links'),
          const SizedBox(height: 12),
          _QuickLinks(onNavigate: onNavigate),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SharedCategoryCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SharedCategoryCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: DashboardCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}

class _WelcomeSection extends StatelessWidget {
  final String name;
  final String initials;
  final String patientId;

  const _WelcomeSection({
    required this.name,
    required this.initials,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    return DashboardCard(
      color: AppColors.burgundy,
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.dustyPink, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.dustyPink,
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.burgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  greeting,
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  softWrap: true,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (patientId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        color: AppColors.dustyPink,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: CopyablePatientId(
                          patientId: patientId,
                          labelStyle: const TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textStyle: const TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          showCopyIcon: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.dustyPink,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.favorite_outline_rounded,
              color: AppColors.burgundy,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdmissionCard extends StatelessWidget {
  const _AdmissionCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      color: AppColors.burgundy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LocalizedText(
            'ADMISSION INFORMATION',
            style: TextStyle(
              color: AppColors.dustyPink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          const LocalizedText(
            'Inpatient care',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const LocalizedText(
            'Admission details will appear here when confirmed by your care team.',
            style: TextStyle(color: AppColors.white, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CurrentPathwayCard extends StatelessWidget {
  final String treatment;
  final String currentStage;
  final VoidCallback onTap;

  const _CurrentPathwayCard({
    required this.treatment,
    required this.currentStage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pathway = pathwayFor(treatment);
    final milestones = pathway.applicableMilestones;
    final total = milestones.length;
    final progress = total == 0 ? 0.0 : pathway.completedCount / total;
    final nextMilestone = pathway.nextMilestone;
    final completedLabel = pathway.completedCount == 0
        ? 'No milestones completed'
        : '${pathway.completedCount} milestone${pathway.completedCount == 1 ? '' : 's'} completed';
    final upcomingLabel = nextMilestone == null
        ? 'Clinic update pending'
        : nextMilestone.name;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _fertilityJourneyBlush,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: _fertilityJourneyDustyPink,
                size: 17,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: LocalizedText(
                  'CURRENT PATHWAY',
                  style: TextStyle(
                    color: _fertilityJourneyBurgundy,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const LocalizedText(
                'Cycle day —',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          LocalizedText(
            treatment,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _fertilityJourneyBurgundy,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const LocalizedText(
            'Clinic-managed treatment pathway',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalizedText(
                      'Current stage',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    LocalizedText(
                      currentStage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _fertilityJourneyBurgundy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: _fertilityJourneyBurgundy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: _fertilityJourneyDustyPink.withValues(alpha: .3),
              valueColor: const AlwaysStoppedAnimation(
                _fertilityJourneyBurgundy,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LocalizedText(
                  completedLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LocalizedText(
                  upcomingLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .62),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: _fertilityJourneyDustyPink,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LocalizedText(
                        'Next milestone',
                        style: TextStyle(
                          color: _fertilityJourneyBurgundy,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      LocalizedText(
                        nextMilestone?.name ?? 'Not available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (nextMilestone != null)
                        LocalizedText(
                          nextMilestone.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: _fertilityJourneyBurgundy,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const LocalizedText('View Fertility Journey →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingVisitCard extends StatelessWidget {
  final Appointment? appointment;
  final String patientName;
  final String mobileNumber;

  const _UpcomingVisitCard({
    required this.appointment,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  Widget build(BuildContext context) {
    final item = appointment;
    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _fertilityJourneyBlush,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const LocalizedText(
          'No upcoming clinical visits.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }
    final doctor = sampleDoctors.cast<Doctor?>().firstWhere(
      (candidate) => candidate?.name == item.doctorName,
      orElse: () => null,
    );
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _fertilityJourneyBurgundy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: _fertilityJourneyDustyPink,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: const LocalizedText(
                  'UPCOMING CLINICAL VISIT',
                  style: TextStyle(
                    color: _fertilityJourneyDustyPink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _StatusBadge(label: item.status),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: _fertilityJourneyBlush,
                foregroundImage: doctor?.profileImageUrl == null
                    ? null
                    : NetworkImage(doctor!.profileImageUrl!),
                child: doctor?.profileImageUrl == null
                    ? Text(
                        doctor?.initials ?? _initials(item.doctorName),
                        style: const TextStyle(
                          color: _fertilityJourneyBurgundy,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.doctorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.specialty.isNotEmpty)
                      Text(
                        item.specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _fertilityJourneyDustyPink,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.date.day} ${_month(item.date.month)} ${item.date.year}  •  ${item.time}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.clinic}  •  ${item.consultationMode}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _fertilityJourneyDustyPink,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          LocalizedText(
            item.appointmentType,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.white, fontSize: 12),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: _fertilityJourneyBurgundy,
                elevation: 0,
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailsScreen(
                    appointment: item,
                    patientName: patientName,
                    mobileNumber: mobileNumber,
                  ),
                ),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const LocalizedText(
                'View Details',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: BorderSide(color: AppColors.white.withValues(alpha: .75)),
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: () => _showInstructions(context, item),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const LocalizedText(
                'Instructions',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInstructions(
    BuildContext context,
    Appointment appointment,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * .65,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: LocalizedText(
                      'Instructions',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const LocalizedText(
                'Preparation guidance',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: appointment.preparationGuidance.isEmpty
                    ? const SingleChildScrollView(
                        child: LocalizedText(
                          'No preparation guidance has been provided for this visit.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: appointment.preparationGuidance.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.burgundy,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appointment.preparationGuidance[index],
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return value.isEmpty ? '?' : value[0].toUpperCase();
  }

  String _month(int month) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month];
}

class _CareTeamSection extends StatelessWidget {
  final String patientName;
  final String mobileNumber;
  final VoidCallback onViewAll;

  const _CareTeamSection({
    required this.patientName,
    required this.mobileNumber,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Your Care Team',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                LocalizedText(
                  'The specialists supporting your care.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 102,
            child: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: _fertilityJourneyBurgundy,
                padding: EdgeInsets.zero,
              ),
              child: const LocalizedText(
                'View All Doctors',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      ...sampleDoctors.map(
        (doctor) => _CareTeamDoctorRow(
          doctor: doctor,
          patientName: patientName,
          mobileNumber: mobileNumber,
        ),
      ),
    ],
  );
}

class _CareTeamDoctorRow extends StatelessWidget {
  final Doctor doctor;
  final String patientName;
  final String mobileNumber;

  const _CareTeamDoctorRow({
    required this.doctor,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _fertilityJourneyBlush,
          foregroundImage: doctor.profileImageUrl == null
              ? null
              : NetworkImage(doctor.profileImageUrl!),
          child: doctor.profileImageUrl == null
              ? Text(
                  doctor.initials,
                  style: const TextStyle(
                    color: _fertilityJourneyBurgundy,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctor.name,
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
                doctor.qualifications?.isNotEmpty == true
                    ? '${doctor.specialty} · ${doctor.qualifications}'
                    : doctor.specialty,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: null,
          tooltip: 'Doctor messaging unavailable',
          style: IconButton.styleFrom(
            backgroundColor: _fertilityJourneyBlush,
            disabledForegroundColor: _fertilityJourneyDustyPink,
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        ),
      ],
    ),
  );
}

class _MedicationReminder extends StatelessWidget {
  const _MedicationReminder();

  @override
  Widget build(BuildContext context) => const DemoReminderCard(compact: true);
}

class _QuickLinks extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const _QuickLinks({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    const links = [
      (Icons.medication_outlined, 'Medications', -1),
      (Icons.assessment_outlined, 'Reports', -1),
      (Icons.receipt_long_outlined, 'Bills & Payments', -1),
      (Icons.support_agent_outlined, 'Doctor Communication', -1),
      (Icons.menu_book_outlined, 'Fertility Education', -1),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: links.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2,
      ),
      itemBuilder: (context, index) {
        final link = links[index];
        return InkWell(
          onTap: () {
            switch (link.$2) {
              case 'Medications':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicationScreen()),
                );
              case 'Reports':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              case 'Bills & Payments':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BillsPaymentsScreen(),
                  ),
                );
              case 'Doctor Communication':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CommunicationScreen(),
                  ),
                );
              case 'Fertility Education':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EducationScreen()),
                );
              default:
                onNavigate(link.$3);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: DashboardCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(link.$1, color: AppColors.burgundy, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LocalizedText(
                    link.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.blushPink,
      borderRadius: BorderRadius.circular(20),
    ),
    child: LocalizedText(
      label,
      style: const TextStyle(
        color: AppColors.burgundy,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
