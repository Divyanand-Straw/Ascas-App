import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/treatment_journey_data.dart';
import '../../../appointments/presentation/appointment_detail_screen.dart';
import '../../../appointments/presentation/data/appointment_data.dart';
import '../../../appointments/presentation/models/appointment_models.dart';
import 'dashboard_card.dart';

class TreatmentOverviewScreen extends StatefulWidget {
  final String treatmentName;
  final String currentStage;

  const TreatmentOverviewScreen({
    super.key,
    required this.treatmentName,
    required this.currentStage,
  });

  @override
  State<TreatmentOverviewScreen> createState() =>
      _TreatmentOverviewScreenState();
}

class _TreatmentOverviewScreenState extends State<TreatmentOverviewScreen> {
  late TreatmentPathway _pathway;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _pathway = pathwayFor(widget.treatmentName, widget.currentStage);
  }

  @override
  Widget build(BuildContext context) {
    final current = _pathway.milestones.firstWhere(
      (milestone) => milestone.status == TreatmentMilestoneStatus.current,
      orElse: () => _pathway.milestones.first,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.burgundy,
        title: const Text(
          'My Fertility Journey',
          style: TextStyle(
            color: AppColors.burgundy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryCard(),
              const SizedBox(height: 22),
              _sectionTitle('CURRENT STAGE'),
              const SizedBox(height: 10),
              _currentStageCard(current),
              const SizedBox(height: 22),
              _clinicUpdatesCard(),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(child: _SectionHeading(title: 'Your journey timeline')),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_expanded.length == _pathway.milestones.length) {
                        _expanded.clear();
                      } else {
                        _expanded
                          ..clear()
                          ..addAll(_pathway.milestones.map((item) => item.id));
                      }
                    }),
                    child: Text(
                      _expanded.length == _pathway.milestones.length
                          ? 'Collapse'
                          : 'View timeline',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _timeline(),
              const SizedBox(height: 18),
              const Text(
                'Prototype pathway for demonstration only. Your clinic controls the confirmed journey and medical information.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final total = _pathway.milestones.length;
    final completed = _pathway.completedCount;
    return DashboardCard(
      color: AppColors.burgundy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLINIC-MANAGED CARE JOURNEY',
            style: TextStyle(
              color: AppColors.dustyPink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _pathway.name,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _changePathway,
                tooltip: 'Change prototype pathway',
                icon: const Icon(Icons.swap_horiz, color: AppColors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$completed Completed · ${_pathway.currentCount} Current · ${_pathway.upcomingCount} Upcoming',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completed / total,
              minHeight: 7,
              backgroundColor: AppColors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(AppColors.dustyPink),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Last updated by Thaai Seyazhi care team on 12 Apr 2025.',
            style: TextStyle(color: AppColors.white, fontSize: 10),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _changePathway,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Change prototype pathway'),
          ),
        ],
      ),
    );
  }

  Widget _currentStageCard(TreatmentMilestone milestone) {
    final isPlaceholder =
        milestone.status == TreatmentMilestoneStatus.awaitingUpdate;
    return DashboardCard(
      color: AppColors.blushPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPlaceholder ? _pathway.currentStage : milestone.name,
            style: const TextStyle(
              color: AppColors.burgundy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isPlaceholder
                ? 'Clinic-published stage pending'
                : '${_pathway.completedCount + _pathway.currentCount} of ${_pathway.milestones.length} clinic-confirmed milestones',
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: milestone.number / _pathway.milestones.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppColors.white,
            valueColor: const AlwaysStoppedAnimation(AppColors.burgundy),
          ),
          const SizedBox(height: 12),
          Text(
            milestone.startDate == null
                ? 'Stage start date: Not confirmed'
                : 'Stage start date: ${milestone.startDate}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Follow only the instructions published by your Thaai Seyazhi care team.',
            style: TextStyle(
              color: AppColors.burgundy,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline() {
    return Column(
      children: _pathway.milestones
          .map((milestone) => _timelineItem(milestone))
          .toList(),
    );
  }

  Widget _timelineItem(TreatmentMilestone milestone) {
    final expanded = _expanded.contains(milestone.id);
    final color = _statusColor(milestone.status);
    return InkWell(
      onTap: () => setState(() {
        if (expanded) {
          _expanded.remove(milestone.id);
        } else {
          _expanded.add(milestone.id);
        }
      }),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Icon(_statusIcon(milestone.status), color: color, size: 16),
                  ),
                  if (milestone.number < _pathway.milestones.length)
                    Container(
                      width: 2,
                      height: expanded ? 104 : 62,
                      color: AppColors.divider,
                    ),
                ],
              ),
            ),
            Expanded(
              child: DashboardCard(
                color: milestone.status == TreatmentMilestoneStatus.current
                    ? AppColors.blushPink
                    : AppColors.white,
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Milestone ${milestone.number} · ${milestone.name}',
                            style: TextStyle(
                              color: milestone.status ==
                                      TreatmentMilestoneStatus.current
                                  ? AppColors.burgundy
                                  : AppColors.primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.secondaryText,
                          size: 19,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusLabel(milestone.status),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 9),
                      Text(
                        _dateLine(milestone),
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        milestone.description,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                      if (milestone.instructions != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          milestone.instructions!,
                          style: const TextStyle(
                            color: AppColors.burgundy,
                            fontSize: 10,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      _relatedAppointmentSection(milestone),
                      _relatedRecordsSection(milestone),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relatedAppointmentSection(TreatmentMilestone milestone) {
    if (milestone.relatedAppointmentId == null) {
      return _emptyDetail('No appointment linked to this stage yet.');
    }
    final appointment = findAppointmentById(milestone.relatedAppointmentId!);
    if (appointment == null) {
      return _emptyDetail('No appointment linked to this stage yet.');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.blushPink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RELATED APPOINTMENT',
              style: TextStyle(
                color: AppColors.burgundy,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${appointment.appointmentType}\n${_appointmentDate(appointment)} · ${appointment.time}',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${appointment.doctorName} · ${appointment.status}',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailsScreen(
                    appointment: appointment,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.burgundy,
              ),
              child: const Text('View appointment details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relatedRecordsSection(TreatmentMilestone milestone) {
    if (milestone.relatedHealthRecords.isEmpty) {
      return _emptyDetail('No health record linked to this stage yet.');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RELATED HEALTH RECORDS',
            style: TextStyle(
              color: AppColors.burgundy,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          ...milestone.relatedHealthRecords.map(
            (record) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.description_outlined,
                color: AppColors.burgundy,
              ),
              title: Text(
                record.documentName,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${record.documentType} · ${record.uploadDate}',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                ),
              ),
              trailing: TextButton(
                onPressed: () => _showUnavailableRecordMessage(),
                child: const Text('View'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDetail(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _clinicUpdatesCard() {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLINIC UPDATES',
            style: TextStyle(
              color: AppColors.dustyPink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Last updated by Thaai Seyazhi care team',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '12 April 2025 · 10:30 AM',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
          ),
          const SizedBox(height: 9),
          const Text(
            'Recently published milestones and instructions appear here when supplied by the clinic.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
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

  void _showUnavailableRecordMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Health record viewing is not available yet.'),
      ),
    );
  }

  void _changePathway() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            const Text(
              'Change prototype pathway',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This demonstration choice does not modify clinic records.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
            ),
            const SizedBox(height: 12),
            ...[
              'IVF Cycle 1',
              'IUI Treatment',
              'Embryo Transfer',
              'Two-Week Wait',
              'Follow-up Care',
            ].map(
              (pathway) => ListTile(
                title: Text(pathway),
                trailing: pathway == _pathway.name
                    ? const Icon(Icons.check, color: AppColors.burgundy)
                    : null,
                onTap: () {
                  setState(() {
                    _pathway = pathwayFor(pathway, '');
                    _expanded.clear();
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: AppColors.dustyPink,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      );

  Color _statusColor(TreatmentMilestoneStatus status) {
    switch (status) {
      case TreatmentMilestoneStatus.completed:
        return AppColors.success;
      case TreatmentMilestoneStatus.current:
        return AppColors.burgundy;
      case TreatmentMilestoneStatus.upcoming:
        return AppColors.dustyPink;
      case TreatmentMilestoneStatus.awaitingUpdate:
        return AppColors.secondaryText;
    }
  }

  IconData _statusIcon(TreatmentMilestoneStatus status) {
    switch (status) {
      case TreatmentMilestoneStatus.completed:
        return Icons.check;
      case TreatmentMilestoneStatus.current:
        return Icons.radio_button_checked;
      case TreatmentMilestoneStatus.upcoming:
        return Icons.calendar_month_outlined;
      case TreatmentMilestoneStatus.awaitingUpdate:
        return Icons.more_horiz;
    }
  }

  String _statusLabel(TreatmentMilestoneStatus status) {
    switch (status) {
      case TreatmentMilestoneStatus.completed:
        return 'Completed';
      case TreatmentMilestoneStatus.current:
        return 'Current';
      case TreatmentMilestoneStatus.upcoming:
        return 'Upcoming';
      case TreatmentMilestoneStatus.awaitingUpdate:
        return 'Awaiting Clinic Update';
    }
  }

  String _dateLine(TreatmentMilestone milestone) {
    if (milestone.completionDate != null) {
      return 'Completed: ${milestone.completionDate}';
    }
    if (milestone.startDate != null) {
      return 'Started: ${milestone.startDate}';
    }
    if (milestone.scheduledDate != null) {
      return 'Date: ${milestone.scheduledDate}'
          '${milestone.scheduledTime == null ? '' : ' · ${milestone.scheduledTime}'}';
    }
    return 'Date: Not confirmed';
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
