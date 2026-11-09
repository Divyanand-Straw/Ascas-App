import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/medication_reminder.dart';
import '../../dashboard/presentation/widgets/dashboard_card.dart';

class DemoReminderCard extends StatefulWidget {
  final bool compact;
  final bool showAll;

  const DemoReminderCard({
    super.key,
    this.compact = false,
    this.showAll = false,
  });

  @override
  State<DemoReminderCard> createState() => _DemoReminderCardState();
}

class _DemoReminderCardState extends State<DemoReminderCard> {
  String? _notificationIssue;

  @override
  void initState() {
    super.initState();
    _scheduleNotifications();
  }

  Future<void> _scheduleNotifications() async {
    try {
      final scheduled = await NotificationService.instance
          .scheduleMedicationReminders(sampleMedicationReminders);
      if (!mounted || scheduled) return;
      setState(() {
        _notificationIssue =
            'Notifications are unavailable or permission is disabled.';
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _notificationIssue = 'Notifications could not be scheduled. Check notification permissions in device settings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final reminders = widget.showAll
        ? sampleMedicationReminders
        : [nextMedicationReminder(now)];
    final accountId = NotificationService.instance.activeAccountId;
    return Column(
      children: [
        if (_notificationIssue != null) ...[
          DashboardCard(
            child: LocalizedText(
              _notificationIssue!,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (var index = 0; index < reminders.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          MedicationReminderCard(
            key: ValueKey('medication-reminder-${reminders[index].id}'),
            reminder: reminders[index],
            accountId: accountId,
            compact: widget.compact,
          ),
        ],
      ],
    );
  }
}

class MedicationReminderCard extends StatefulWidget {
  final MedicationReminder reminder;
  final String accountId;
  final bool compact;

  const MedicationReminderCard({
    super.key,
    required this.reminder,
    required this.accountId,
    this.compact = false,
  });

  @override
  State<MedicationReminderCard> createState() => _MedicationReminderCardState();
}

class _MedicationReminderCardState extends State<MedicationReminderCard>
    with WidgetsBindingObserver {
  late DateTime _now;
  late Timer _timer;
  DateTime? _takenAt;

  String get _takenPreferenceKey =>
      'sample_medication_taken_${widget.accountId}_${widget.reminder.id}';

  MedicationReminderStatus get _status => medicationReminderStatus(
    reminder: widget.reminder,
    now: _now,
    takenAt: _takenAt,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = DateTime.now();
    _loadTakenAt();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = _now.add(const Duration(seconds: 1)));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void didUpdateWidget(covariant MedicationReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.reminder.id != widget.reminder.id) {
      _takenAt = null;
      _loadTakenAt();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadTakenAt() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_takenPreferenceKey);
    if (!mounted || saved == null) return;
    setState(() => _takenAt = DateTime.tryParse(saved));
  }

  Future<void> _markTaken() async {
    final takenAt = DateTime.now();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _takenPreferenceKey,
      DateTime(takenAt.year, takenAt.month, takenAt.day).toIso8601String(),
    );
    if (!mounted) return;
    setState(() {
      _takenAt = takenAt;
      _now = takenAt;
    });
  }

  void _viewPrescription() {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => PrescriptionDetailsScreen(reminder: widget.reminder),
      ),
    );
  }

  String get _statusLabel => switch (_status) {
    MedicationReminderStatus.upcoming => 'Upcoming',
    MedicationReminderStatus.due => 'Due',
    MedicationReminderStatus.completed => 'Completed',
    MedicationReminderStatus.missed => 'Missed',
  };

  Color get _statusColor => switch (_status) {
    MedicationReminderStatus.upcoming => AppColors.dustyPink,
    MedicationReminderStatus.due => AppColors.warning,
    MedicationReminderStatus.completed => AppColors.success,
    MedicationReminderStatus.missed => AppColors.error,
  };

  String get _countdown {
    final difference = widget.reminder.nextScheduledAt(_now).difference(_now);
    final seconds = difference.inSeconds < 0 ? 0 : difference.inSeconds;
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$remainder';
  }

  @override
  Widget build(BuildContext context) {
    final scheduledTime = TimeOfDay(
      hour: widget.reminder.hour,
      minute: widget.reminder.minute,
    ).format(context);
    return DashboardCard(
      color: AppColors.burgundy,
      padding: EdgeInsets.all(widget.compact ? 15 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.dustyPink,
                size: 19,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: LocalizedText(
                  'SAMPLE DATA · NOT A PRESCRIPTION',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .35,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: LocalizedText(
                  _statusLabel,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            widget.reminder.name,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.dustyPink.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.dustyPink.withValues(alpha: .45),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.dustyPink,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: const LocalizedText(
                    'Scheduled time',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  scheduledTime,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          _ReminderInfoRow(
            label: 'Next reminder',
            value: _countdown,
            emphasized: true,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              TextButton(
                onPressed: _viewPrescription,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const LocalizedText('View Prescription'),
              ),
              if (_status != MedicationReminderStatus.completed)
                TextButton(
                  onPressed: _markTaken,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.white,
                    backgroundColor: AppColors.dustyPink.withValues(alpha: .24),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const LocalizedText('Mark as Taken'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _ReminderInfoRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: LocalizedText(
          label,
          style: const TextStyle(color: AppColors.dustyPink, fontSize: 11),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: AppColors.white,
          fontSize: emphasized ? 13 : 11,
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          fontFeatures: emphasized
              ? const [FontFeature.tabularFigures()]
              : null,
        ),
      ),
    ],
  );
}

class PrescriptionDetailsScreen extends StatelessWidget {
  final MedicationReminder reminder;

  const PrescriptionDetailsScreen({super.key, required this.reminder});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const LocalizedText('Prescription Details'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        DashboardCard(
          color: AppColors.burgundy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LocalizedText(
                'SAMPLE DATA · NOT A PRESCRIPTION',
                style: TextStyle(
                  color: AppColors.dustyPink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                reminder.name,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DashboardCard(
          child: Column(
            children: [
              _PrescriptionDetailRow(
                label: 'Medication name',
                value: reminder.name,
              ),
              _PrescriptionDetailRow(
                label: 'Prescribed dosage',
                value: reminder.dosage,
              ),
              _PrescriptionDetailRow(
                label: 'Instructions',
                value: reminder.instructions,
              ),
              _PrescriptionDetailRow(
                label: 'Frequency',
                value: reminder.frequency,
              ),
              _PrescriptionDetailRow(
                label: 'Prescribing doctor',
                value: reminder.prescribingDoctor ?? 'Not supplied',
              ),
              _PrescriptionDetailRow(
                label: 'Start date',
                value: reminder.startDate ?? 'Not supplied',
              ),
              _PrescriptionDetailRow(
                label: 'End date',
                value: reminder.endDate ?? 'Not supplied',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const LocalizedText(
          'This reminder opens only its associated sample details. No clinic prescription is available in this demo.',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _PrescriptionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _PrescriptionDetailRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          label,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        LocalizedText(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!last) const Divider(height: 15, color: AppColors.divider),
      ],
    ),
  );
}
