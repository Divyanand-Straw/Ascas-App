import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/formatters/currency_formatter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../appointments/presentation/appointment_detail_screen.dart';
import '../../../appointments/presentation/data/appointment_data.dart';
import '../../../appointments/presentation/doctor_information_screen.dart';
import '../../../appointments/presentation/models/appointment_models.dart';
import 'dashboard_card.dart';
import 'dashboard_detail_screen.dart';
import 'treatment_overview_screen.dart';

enum DashboardPatientState {
  newPatient,
  ivf,
  iui,
  embryoTransfer,
  twoWeekWait,
  postProcedureRecovery,
  followUpCare,
}

class DashboardHomeContent extends StatefulWidget {
  final String patientName;
  final DashboardPatientState patientState;

  const DashboardHomeContent({
    super.key,
    required this.patientName,
    required this.patientState,
  });

  @override
  State<DashboardHomeContent> createState() => _DashboardHomeContentState();
}

class _DashboardHomeContentState extends State<DashboardHomeContent> {
  final Set<int> _completedActions = {0};
  final Set<int> _completedTasks = {};
  final int _completedDoses = 2;
  Timer? _countdownTimer;
  Duration _triggerRemaining = const Duration(hours: 6, minutes: 24);

  @override
  void initState() {
    super.initState();
    appointmentStore.addListener(_onAppointmentsChanged);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _triggerRemaining <= Duration.zero) return;
      setState(() {
        _triggerRemaining -= const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    appointmentStore.removeListener(_onAppointmentsChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onAppointmentsChanged() {
    if (mounted) setState(() {});
  }

  String get _stage {
    switch (widget.patientState) {
      case DashboardPatientState.newPatient:
        return 'Getting started';
      case DashboardPatientState.ivf:
        return 'IVF Â· Ovarian stimulation';
      case DashboardPatientState.iui:
        return 'IUI preparation';
      case DashboardPatientState.embryoTransfer:
        return 'Embryo transfer';
      case DashboardPatientState.twoWeekWait:
        return 'Two-week wait';
      case DashboardPatientState.postProcedureRecovery:
        return 'Post-procedure recovery';
      case DashboardPatientState.followUpCare:
        return 'Follow-up care';
    }
  }

  String get _treatmentName {
    switch (widget.patientState) {
      case DashboardPatientState.newPatient:
        return 'Not assigned yet';
      case DashboardPatientState.ivf:
        return 'IVF Treatment';
      case DashboardPatientState.iui:
        return 'IUI Treatment';
      case DashboardPatientState.embryoTransfer:
        return 'Embryo Transfer';
      case DashboardPatientState.twoWeekWait:
        return 'Post-transfer Care';
      case DashboardPatientState.postProcedureRecovery:
        return 'Post-procedure Care';
      case DashboardPatientState.followUpCare:
        return 'Follow-up Care';
    }
  }

  bool get _hasTriggerReminder =>
      widget.patientState == DashboardPatientState.ivf;

  bool get _hasMedicationSchedule =>
      widget.patientState == DashboardPatientState.ivf ||
      widget.patientState == DashboardPatientState.iui ||
      widget.patientState == DashboardPatientState.postProcedureRecovery;

  void _openDetail({
    required String title,
    required String eyebrow,
    required String description,
    List<DashboardDetailRow> rows = const [],
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardDetailScreen(
          title: title,
          eyebrow: eyebrow,
          description: description,
          rows: rows,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }

  void _showPrototypeMessage(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.burgundy,
                  side: const BorderSide(color: AppColors.burgundy),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: LocalizedText('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _journeyCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TreatmentOverviewScreen(
            treatmentName: _treatmentName == 'IVF Treatment'
                ? 'IVF Cycle 1'
                : _treatmentName,
            currentStage: _stage,
          ),
        ),
      ),
      child: DashboardCard(
        color: AppColors.burgundy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LocalizedText(
                    'MY FERTILITY JOURNEY',
                    style: TextStyle(
                      color: AppColors.dustyPink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.white,
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _stage,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.patientState == DashboardPatientState.newPatient
                  ? 'Your clinic-recorded journey will appear after your first visit.'
                  : 'Clinic-confirmed current stage',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.78),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: List.generate(
                5,
                (index) => Expanded(
                  child: Container(
                    height: 7,
                    margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: index < 3
                          ? AppColors.dustyPink
                          : AppColors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            const Row(
              children: [
                LocalizedText(
                  '3 confirmed',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                LocalizedText(
                  'View journey',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget treatmentOverviewCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TreatmentOverviewScreen(
              treatmentName: _treatmentName,
              currentStage: _stage,
            ),
          ),
        );
      },
      child: DashboardCard(
        color: AppColors.white,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.burgundy,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: LocalizedText(
                    'TREATMENT OVERVIEW',
                    style: TextStyle(
                      color: AppColors.dustyPink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.burgundy,
                  size: 15,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              _treatmentName,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.patientState == DashboardPatientState.newPatient
                  ? 'Your treatment information will appear after your clinic records your plan.'
                  : 'Current stage: $_stage',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.dustyPink, size: 15),
                SizedBox(width: 6),
                Expanded(
                  child: LocalizedText(
                    'View treatment details and progress',
                    style: TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineAction({
    required int index,
    required String date,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final completed = _completedActions.contains(index);
    return GestureDetector(
      onTap: () => _openDetail(
        title: title,
        eyebrow: date,
        description: subtitle,
        rows: [
          DashboardDetailRow(
            label: 'Status',
            value: completed
                ? 'Completed in this prototype'
                : 'Pending clinic task',
            icon: completed ? Icons.check_circle_outline : icon,
          ),
          const DashboardDetailRow(
            label: 'Clinic note',
            value: 'Follow only instructions recorded by your clinic.',
            icon: Icons.info_outline,
          ),
        ],
        actionLabel: completed ? 'Mark as pending' : 'Mark completed',
        onAction: () {
          Navigator.pop(context);
          setState(() {
            if (completed) {
              _completedActions.remove(index);
            } else {
              _completedActions.add(index);
            }
          });
        },
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: completed ? AppColors.success : AppColors.blushPink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed ? Icons.check : icon,
                  color: completed ? AppColors.white : AppColors.burgundy,
                  size: 17,
                ),
              ),
              if (index == 0)
                Container(width: 2, height: 45, color: AppColors.divider),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppColors.dustyPink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.secondaryText,
            size: 19,
          ),
        ],
      ),
    );
  }

  Widget _nextStepsCard() {
    return DashboardCard(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 4),
      child: Column(
        children: [
          _timelineAction(
            index: 0,
            date: 'NEXT',
            title: 'Take evening medication',
            subtitle: 'Clinic reminder Â· 8:00 PM',
            icon: Icons.medication_outlined,
          ),
          _timelineAction(
            index: 1,
            date: '12 MAY',
            title: 'Attend confirmed clinic appointment',
            subtitle: 'Thaai Seyazhi Â· 10:30 AM',
            icon: Icons.calendar_month_outlined,
          ),
        ],
      ),
    );
  }

  Widget _triggerCard() {
    if (!_hasTriggerReminder || _triggerRemaining <= Duration.zero) {
      return const SizedBox.shrink();
    }
    final hours = _triggerRemaining.inHours.toString().padLeft(2, '0');
    final minutes = (_triggerRemaining.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (_triggerRemaining.inSeconds % 60).toString().padLeft(
      2,
      '0',
    );
    return DashboardCard(
      color: AppColors.burgundy,
      child: InkWell(
        onTap: () => _openDetail(
          title: 'Trigger reminder',
          eyebrow: 'CLINIC-ENTERED REMINDER',
          description: 'Scheduled trigger reminder',
          rows: const [
            DashboardDetailRow(
              label: 'Scheduled',
              value: 'Today Â· 10:30 PM',
              icon: Icons.schedule_outlined,
            ),
            DashboardDetailRow(
              label: 'Instruction',
              value: 'Follow the instruction recorded by your clinic.',
              icon: Icons.medical_information_outlined,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(
              'CLINIC-ENTERED TRIGGER REMINDER',
              style: TextStyle(
                color: AppColors.dustyPink,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 9),
            LocalizedText(
              '$hours:$minutes:$seconds',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            LocalizedText(
              'Today Â· 10:30 PM Â· Reminder details',
              style: TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentCard() {
    final appointment = appointmentStore.nearestUpcoming;
    if (appointment == null) {
      return DashboardCard(
        padding: const EdgeInsets.fromLTRB(15, 17, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(
              'NEXT APPOINTMENT',
              style: TextStyle(
                color: AppColors.dustyPink,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 14),
            LocalizedText(
              'No upcoming appointments',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            LocalizedText(
              'Book a visit with your care team.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorInformationScreen(
                    patientName: widget.patientName,
                    mobileNumber: '',
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.burgundy,
              ),
              child: LocalizedText('Book an appointment'),
            ),
          ],
        ),
      );
    }

    final isFollowUp = appointment.appointmentType.toLowerCase().contains(
      'follow-up',
    );
    final foregroundColor = isFollowUp
        ? AppColors.white
        : AppColors.primaryText;
    final secondaryColor = isFollowUp
        ? AppColors.white
        : AppColors.secondaryText;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailsScreen(appointment: appointment),
        ),
      ),
      child: DashboardCard(
        color: isFollowUp ? AppColors.burgundy : AppColors.white,
        padding: const EdgeInsets.fromLTRB(15, 17, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: isFollowUp ? AppColors.white : AppColors.burgundy,
                  size: 18,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: LocalizedText(
                    'NEXT APPOINTMENT',
                    style: TextStyle(
                      color: AppColors.dustyPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              appointment.appointmentType,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              _appointmentDate(appointment),
              style: TextStyle(
                color: isFollowUp ? AppColors.white : AppColors.burgundy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              appointment.time,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appointment.doctorName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: secondaryColor, fontSize: 10),
            ),
            const SizedBox(height: 4),
            LocalizedText(
              'Status: ${_statusLabel(appointment.status)}',
              style: const TextStyle(color: AppColors.white, fontSize: 10),
            ),
            const SizedBox(height: 18),
            LocalizedText(
              'View appointment details',
              style: TextStyle(
                color: isFollowUp ? AppColors.white : AppColors.burgundy,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _appointmentDate(Appointment appointment) {
    final month = const [
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
    ][appointment.date.month - 1];
    return '${appointment.date.day} $month ${appointment.date.year}';
  }

  String _statusLabel(String status) {
    if (status == 'Requested') return 'Pending confirmation';
    return status;
  }

  Widget _medicationCard() {
    if (!_hasMedicationSchedule) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _openDetail(
        title: 'Medication schedule',
        eyebrow: 'PROTOTYPE SCHEDULE',
        description: 'Todayâ€™s clinic-entered medication schedule',
        rows: const [
          DashboardDetailRow(
            label: 'Next dose',
            value: '8:00 PM',
            icon: Icons.schedule_outlined,
          ),
          DashboardDetailRow(
            label: 'Safety',
            value: 'Medication details are shown only when supplied by the clinic.',
            icon: Icons.info_outline,
          ),
        ],
      ),
      child: DashboardCard(
        padding: const EdgeInsets.fromLTRB(15, 17, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.medication_outlined,
                  color: AppColors.burgundy,
                  size: 18,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: LocalizedText(
                    'TODAYâ€™S MEDICATION',
                    style: TextStyle(
                      color: AppColors.dustyPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            LocalizedText(
              '$_completedDoses of 3 completed',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _completedDoses / 3,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.burgundy,
                ),
              ),
            ),
            const SizedBox(height: 13),
            LocalizedText(
              'Next dose Â· 8:00 PM',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
            ),
            const SizedBox(height: 18),
            LocalizedText(
              'View schedule',
              style: TextStyle(
                color: AppColors.burgundy,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentAndMedication() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth >= 340;
        if (compact) {
          return SizedBox(
            height: 248,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _appointmentCard()),
                const SizedBox(width: 10),
                Expanded(child: _medicationCard()),
              ],
            ),
          );
        }
        return Column(
          children: [
            _appointmentCard(),
            const SizedBox(height: 16),
            _medicationCard(),
          ],
        );
      },
    );
  }

  Widget _pendingTasksCard() {
    const tasks = [
      (
        'Upload previous blood test',
        'Requested by your care coordinator',
        Icons.upload_file_outlined,
      ),
      (
        'Confirm monitoring appointment',
        'Response requested by Thaai Seyazhi',
        Icons.event_available_outlined,
      ),
      (
        'Review consent form',
        'Updated patient privacy consent',
        Icons.description_outlined,
      ),
    ];
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            '${tasks.length - _completedTasks.length} pending',
            style: const TextStyle(
              color: AppColors.dustyPink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          ...List.generate(tasks.length, (index) {
            final task = tasks[index];
            final completed = _completedTasks.contains(index);
            return Column(
              children: [
                InkWell(
                  onTap: () {
                    if (index == 0) {
                      _showPrototypeMessage(
                        'Upload previous blood test',
                        'Prototype file selection is ready. A file picker can be connected when the clinic upload service is available.',
                      );
                    } else if (index == 1) {
                      _openDetail(
                        title: 'Confirm appointment',
                        eyebrow: 'CLINIC REQUEST',
                        description: 'Confirm your monitoring appointment',
                        rows: const [
                          DashboardDetailRow(
                            label: 'Appointment',
                            value: 'Mon, 12 May Â· 10:30 AM Â· Thaai Seyazhi',
                            icon: Icons.calendar_month_outlined,
                          ),
                        ],
                        actionLabel: _completedTasks.contains(index)
                            ? 'Mark as pending'
                            : 'Confirm appointment',
                        onAction: () {
                          Navigator.pop(context);
                          setState(() {
                            if (_completedTasks.contains(index)) {
                              _completedTasks.remove(index);
                            } else {
                              _completedTasks.add(index);
                            }
                          });
                        },
                      );
                    } else {
                      _openDetail(
                        title: 'Consent form',
                        eyebrow: 'PATIENT PRIVACY',
                        description: 'Review your updated consent form',
                        rows: const [
                          DashboardDetailRow(
                            label: 'Status',
                            value: 'Review requested by your clinic',
                            icon: Icons.description_outlined,
                          ),
                        ],
                        actionLabel: _completedTasks.contains(index)
                            ? 'Mark as pending'
                            : 'Mark as reviewed',
                        onAction: () {
                          Navigator.pop(context);
                          setState(() {
                            if (_completedTasks.contains(index)) {
                              _completedTasks.remove(index);
                            } else {
                              _completedTasks.add(index);
                            }
                          });
                        },
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Icon(
                          completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: completed
                              ? AppColors.success
                              : AppColors.dustyPink,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.$1,
                                style: TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task.$2,
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.secondaryText,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < tasks.length - 1)
                  const Divider(color: AppColors.divider, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _reportCard() {
    return InkWell(
      onTap: () => _openDetail(
        title: 'Medical report',
        eyebrow: 'SAMPLE RECORD',
        description: 'Blood Test Report',
        rows: const [
          DashboardDetailRow(
            label: 'Added',
            value: '12 Apr 2025',
            icon: Icons.event_outlined,
          ),
          DashboardDetailRow(
            label: 'File',
            value: 'PDF Â· Sample record Â· Ready',
            icon: Icons.picture_as_pdf_outlined,
          ),
        ],
        actionLabel: 'Preview sample details',
        onAction: () => _showPrototypeMessage(
          'Sample report',
          'This prototype report is not a real medical document. A clinic-provided file preview will appear here when available.',
        ),
      ),
      child: DashboardCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.burgundy,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    'Blood Test Report',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  LocalizedText(
                    'Added 12 Apr 2025 Â· PDF',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            LocalizedText(
              'Ready',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget quickAccess() {
    const items = [
      (Icons.calendar_month_outlined, 'Book Appointment'),
      (Icons.favorite_outline, 'Journey'),
      (Icons.medication_outlined, 'Medicines'),
      (Icons.folder_outlined, 'Records'),
      (Icons.support_agent, 'Contact'),
    ];
    return DashboardCard(
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: InkWell(
              onTap: () {
                if (item.$2 == 'Journey') {
                  _openDetail(
                    title: 'My Journey',
                    eyebrow: 'CLINIC-CONFIRMED',
                    description: _stage,
                  );
                } else {
                  _showPrototypeMessage(
                    item.$2,
                    '${item.$2} is available as a prototype action. It will connect to your clinic service when configured.',
                  );
                }
              },
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blushPink,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(item.$1, color: AppColors.burgundy, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _billingCard() {
    return DashboardCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.blushPink,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.burgundy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'PENDING BALANCE · SAMPLE DATA',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  formatIndianRupees(24500),
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                LocalizedText(
                  'Next package payment due 20 May',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 82,
            child: TextButton(
              onPressed: () => _openDetail(
                title: 'Billing',
                eyebrow: 'PROTOTYPE SAMPLE DATA',
                description: 'Payment summary',
                rows: const [
                  DashboardDetailRow(
                    label: 'Status',
                    value: 'Pending payment',
                    icon: Icons.pending_actions_outlined,
                  ),
                  DashboardDetailRow(
                    label: 'Due date',
                    value: '20 May',
                    icon: Icons.event_outlined,
                  ),
                ],
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: LocalizedText(
                'View billing',
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clinicUpdate() {
    return InkWell(
      onTap: () => _openDetail(
        title: 'Clinic update',
        eyebrow: 'THAAI SEYAZHI Â· 2 HOURS AGO',
        description: 'Preparation guidance for your next visit',
        rows: const [
          DashboardDetailRow(
            label: 'Message',
            value: 'Review what to bring and how to prepare.',
            icon: Icons.notifications_active_outlined,
          ),
        ],
      ),
      child: DashboardCard(
        color: AppColors.blushPink,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: AppColors.burgundy,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    'Clinic update',
                    style: TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 6),
                  LocalizedText(
                    'Preparation guidance for your next visit.',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  LocalizedText(
                    'Thaai Seyazhi Â· 2 hours ago',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.burgundy),
          ],
        ),
      ),
    );
  }

  Widget _articleCard() {
    return InkWell(
      onTap: () => _openDetail(
        title: 'Staying calm before a monitoring visit',
        eyebrow: '5 MIN READ Â· CLINIC REVIEWED',
        description:
            'Small ways to feel prepared before you visit your care team.',
        rows: const [
          DashboardDetailRow(
            label: 'Article',
            value: 'A gentle guide to preparing questions and creating calm.',
            icon: Icons.menu_book_outlined,
          ),
        ],
        actionLabel: 'Read article',
      ),
      child: DashboardCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 112,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.burgundy, AppColors.dustyPink],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Center(
                child: Icon(
                  Icons.self_improvement_outlined,
                  color: AppColors.white,
                  size: 52,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    '5 MIN READ Â· CLINIC REVIEWED',
                    style: TextStyle(
                      color: AppColors.dustyPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  SizedBox(height: 7),
                  LocalizedText(
                    'Staying calm before a monitoring visit',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  LocalizedText(
                    'Read article',
                    style: TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportCard() {
    return DashboardCard(
      color: AppColors.burgundy,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showPrototypeMessage(
              'Message Thaai Seyazhi',
              'Clinic chat is a prototype interaction until the configured clinic messaging service is available.',
            ),
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Need help from Thaai Seyazhi?',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                LocalizedText(
                  'Message or call your clinic support team.',
                  style: TextStyle(color: AppColors.white, fontSize: 11),
                ),
                SizedBox(height: 8),
                LocalizedText(
                  'Contact details: configured clinic information',
                  style: TextStyle(color: AppColors.white, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showPrototypeMessage(
              'Call Thaai Seyazhi',
              'No phone number is configured in this prototype. Use the clinic contact information provided by your care team.',
            ),
            icon: const Icon(
              Icons.phone_outlined,
              color: AppColors.white,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        LocalizedText(
          'Good morning, ${widget.patientName}',
          style: const TextStyle(
            color: AppColors.burgundy,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        LocalizedText(
          'How are you feeling today?',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        _journeyCard(),
        const SizedBox(height: 20),
        const DashboardSectionHeader(title: 'Your Next Steps'),
        _nextStepsCard(),
        const SizedBox(height: 20),
        _triggerCard(),
        if (_hasTriggerReminder) const SizedBox(height: 20),
        const DashboardSectionHeader(title: 'Next appointment & medication'),
        _appointmentAndMedication(),
        const SizedBox(height: 20),
        const DashboardSectionHeader(title: 'Pending tasks'),
        _pendingTasksCard(),
        const SizedBox(height: 20),
        const DashboardSectionHeader(title: 'Recent medical report'),
        _reportCard(),
        const SizedBox(height: 20),
        const DashboardSectionHeader(title: 'Billing'),
        _billingCard(),
        const SizedBox(height: 20),
        const DashboardSectionHeader(title: 'From Thaai Seyazhi'),
        _clinicUpdate(),
        const SizedBox(height: 20),
        const DashboardSectionHeader(title: 'Recommended for you'),
        _articleCard(),
        const SizedBox(height: 20),
        _supportCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}
