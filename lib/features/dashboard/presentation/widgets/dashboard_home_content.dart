import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../appointments/presentation/data/appointment_data.dart';
import '../../../appointments/presentation/appointment_detail_screen.dart';
import '../../../appointments/presentation/doctor_information_screen.dart';
import '../../../appointments/presentation/doctor_profile_screen.dart';
import '../../../appointments/presentation/models/appointment_models.dart';
import '../../../communication/presentation/communication_screen.dart';
import '../../../education/presentation/education_screen.dart';
import '../../../medical_records/presentation/medical_records_screen.dart';
import '../../../medication/presentation/demo_reminder_card.dart';
import '../../../medication/presentation/medication_screen.dart';
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

class DashboardHomeContent extends StatelessWidget {
  final String patientName;
  final String mobileNumber;
  final String patientId;
  final DashboardPatientState patientState;
  final ValueChanged<int> onNavigate;
  final bool isLinkedPartner;
  final Map<String, bool> partnerPermissions;

  const DashboardHomeContent({
    super.key,
    required this.patientName,
    this.mobileNumber = '',
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
    DashboardPatientState.ivf => 'IVF treatment',
    DashboardPatientState.icsi => 'ICSI treatment',
    DashboardPatientState.iui => 'IUI treatment',
    DashboardPatientState.fet => 'Frozen Embryo Transfer (FET)',
    DashboardPatientState.embryoTransfer => 'Embryo transfer',
    DashboardPatientState.twoWeekWait => 'Post-transfer care',
    DashboardPatientState.postProcedureRecovery => 'Post-procedure care',
    DashboardPatientState.followUpCare => 'Follow-up care',
    DashboardPatientState.newPatient => 'Care pathway pending',
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
        if (_can('Appointments')) ...[
          const SizedBox(height: 24),
          DashboardSectionHeader(
            title: 'Next Appointment',
            action: 'View all',
            onAction: () => onNavigate(2),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: appointmentStore,
            builder: (context, _) =>
                _AppointmentCard(appointment: appointmentStore.nearestUpcoming),
          ),
        ],
        if (_can('Treatment Journey')) ...[
          const SizedBox(height: 22),
          DashboardSectionHeader(
            title: 'Fertility Journey',
            action: 'View Journey',
            onAction: () => onNavigate(1),
          ),
          const SizedBox(height: 12),
          _TreatmentSnapshot(treatment: _treatment, onTap: () => onNavigate(1)),
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
            onTap: () => onNavigate(3),
          ),
        if (!isLinkedPartner) ...[
          const SizedBox(height: 22),
          DashboardSectionHeader(
            title: 'Our Doctors',
            action: 'View all',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorInformationScreen(
                  patientName: patientName,
                  mobileNumber: mobileNumber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sampleDoctors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _DoctorCard(
                doctor: sampleDoctors[index],
                patientName: patientName,
                mobileNumber: mobileNumber,
              ),
            ),
          ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (patientId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${localizedText(context, 'Patient ID')}: $patientId',
                      style: const TextStyle(
                        color: AppColors.dustyPink,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _AppointmentCard extends StatelessWidget {
  final Appointment? appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final item = appointment;
    if (item == null) {
      return const DashboardCard(
        child: Text(
          'No upcoming appointments.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }
    return DashboardCard(
      color: AppColors.burgundy,
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.doctorName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(label: item.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              Text(
                '${item.date.day} ${_month(item.date.month)}  •  ${item.time}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.appointmentType}  •  ${item.consultationMode}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.dustyPink, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailsScreen(appointment: item),
                ),
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
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

class _TreatmentSnapshot extends StatelessWidget {
  final String treatment;
  final VoidCallback onTap;

  const _TreatmentSnapshot({required this.treatment, required this.onTap});

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          treatment,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.burgundy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        const SizedBox(height: 7),
        const LocalizedText(
          'Current stage',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Your treatment stage will appear when shared by your care team.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 12),
        const _StatusBadge(label: 'Awaiting clinic update'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: onTap,
              child: const LocalizedText('View Journey'),
            ),
          ],
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

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final String patientName;
  final String mobileNumber;

  const _DoctorCard({
    required this.doctor,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.blushPink,
                child: Text(
                  doctor.initials,
                  style: const TextStyle(
                    color: AppColors.burgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  doctor.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            doctor.specialty,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorProfileScreen(
                    doctor: doctor,
                    patientName: patientName,
                    mobileNumber: mobileNumber,
                  ),
                ),
              ),
              child: const LocalizedText('View Profile'),
            ),
          ),
        ],
      ),
    ),
  );
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
