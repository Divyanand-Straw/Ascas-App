import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../appointments/presentation/data/appointment_data.dart';
import '../../../appointments/presentation/appointment_detail_screen.dart';
import '../../../appointments/presentation/models/appointment_models.dart';
import '../../../medication/presentation/medication_screen.dart';
import 'dashboard_card.dart';

enum DashboardPatientState {
  newPatient,
  ivf,
  iui,
  embryoTransfer,
  twoWeekWait,
  postProcedureRecovery,
  followUpCare,
}

class DashboardHomeContent extends StatelessWidget {
  final String patientName;
  final DashboardPatientState patientState;
  final ValueChanged<int> onNavigate;

  const DashboardHomeContent({
    super.key,
    required this.patientName,
    required this.patientState,
    required this.onNavigate,
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
    DashboardPatientState.iui => 'IUI treatment',
    DashboardPatientState.embryoTransfer => 'Embryo transfer',
    DashboardPatientState.twoWeekWait => 'Post-transfer care',
    DashboardPatientState.postProcedureRecovery => 'Post-procedure care',
    DashboardPatientState.followUpCare => 'Follow-up care',
    DashboardPatientState.newPatient => 'Care pathway pending',
  };

  @override
  Widget build(BuildContext context) {
    final appointment = appointmentStore.nearestUpcoming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeSection(name: patientName, initials: _initials),
        if (patientState == DashboardPatientState.postProcedureRecovery) ...[
          const SizedBox(height: 20),
          const _AdmissionCard(),
        ],
        const SizedBox(height: 24),
        DashboardSectionHeader(
          title: 'Next Appointment',
          action: 'View all',
          onAction: () => onNavigate(2),
        ),
        const SizedBox(height: 12),
        _AppointmentCard(appointment: appointment, onNavigate: onNavigate),
        const SizedBox(height: 22),
        DashboardSectionHeader(
          title: 'Treatment Snapshot',
          action: 'View Journey',
          onAction: () => onNavigate(1),
        ),
        const SizedBox(height: 12),
        _TreatmentSnapshot(treatment: _treatment, onTap: () => onNavigate(1)),
        const SizedBox(height: 22),
        DashboardSectionHeader(
          title: 'Medication Reminders',
          action: 'View all',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MedicationScreen()),
          ),
        ),
        const SizedBox(height: 12),
        const _MedicationReminder(),
        const SizedBox(height: 22),
        DashboardSectionHeader(
          title: 'Your Doctors',
          action: 'View all',
          onAction: () => onNavigate(2),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 198,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sampleDoctors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _DoctorCard(doctor: sampleDoctors[index]),
          ),
        ),
        const SizedBox(height: 22),
        const DashboardSectionHeader(title: 'Quick Links'),
        const SizedBox(height: 12),
        _QuickLinks(onNavigate: onNavigate),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  final String name;
  final String initials;

  const _WelcomeSection({required this.name, required this.initials});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      color: AppColors.white,
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
              backgroundColor: AppColors.blushPink,
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
                const Text(
                  'Good Morning',
                  style: TextStyle(
                    color: AppColors.secondaryText,
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
                    color: AppColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Patient ID: TS-00124',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.blushPink,
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
          const Text(
            'ACTIVE ADMISSION',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Inpatient care',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          const _WhiteDetail(label: 'Admission ID', value: 'ADM-2026-001'),
          const _WhiteDetail(label: 'Admission date', value: '7 November 2026'),
          const _WhiteDetail(
            label: 'Ward / room',
            value: 'Women’s Care / Room 204',
          ),
          const _WhiteDetail(
            label: 'Treating doctor',
            value: 'Dr. Meera Sharma',
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.white,
              padding: EdgeInsets.zero,
            ),
            child: const Text('View Admission Details'),
          ),
        ],
      ),
    );
  }
}

class _WhiteDetail extends StatelessWidget {
  final String label;
  final String value;

  const _WhiteDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: .76),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  final Appointment? appointment;
  final ValueChanged<int> onNavigate;

  const _AppointmentCard({required this.appointment, required this.onNavigate});

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
                    color: AppColors.primaryText,
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
                  color: AppColors.primaryText,
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
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppointmentDetailsScreen(appointment: item),
                  ),
                ),
                child: const Text('View Details'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate(2),
                child: const Text('Request Appointment'),
              ),
            ],
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
        Text(
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
        const Text(
          'Current stage: Clinic-confirmed update pending',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 13),
        const LinearProgressIndicator(
          value: .45,
          minHeight: 7,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          backgroundColor: AppColors.blushPink,
          valueColor: AlwaysStoppedAnimation(AppColors.burgundy),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Text(
              'Progress placeholder',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
            ),
            TextButton(onPressed: onTap, child: const Text('View Journey')),
          ],
        ),
      ],
    ),
  );
}

class _MedicationReminder extends StatelessWidget {
  const _MedicationReminder();

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.blushPink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.medication_outlined,
            color: AppColors.burgundy,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medication placeholder',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Dosage placeholder  •  08:00 AM',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: _StatusBadge(label: 'Upcoming'),
        ),
      ],
    ),
  );
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;

  const _DoctorCard({required this.doctor});

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
              onPressed: () {},
              child: const Text('View Profile'),
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
      (Icons.route_outlined, 'My Journey', 1),
      (Icons.calendar_month_outlined, 'Appointments', 2),
      (Icons.folder_outlined, 'Medical Records', 3),
      (Icons.medication_outlined, 'Medication', 1),
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
            if (link.$2 == 'Medication') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicationScreen()),
              );
            } else {
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
                  child: Text(
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
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.burgundy,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
