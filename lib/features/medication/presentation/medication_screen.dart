import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/dashboard_card.dart';
import '../../communication/presentation/communication_screen.dart';

enum DoseStatus { upcoming, due, taken, skipped, missed }

class MedicationDose {
  final String id;
  final String medicine;
  final String dosage;
  final String time;
  final String frequency;
  final String instructions;
  final String prescribedBy;
  final bool confirmationAllowed;
  DoseStatus status;
  DateTime? confirmedAt;

  MedicationDose({
    required this.id,
    required this.medicine,
    required this.dosage,
    required this.time,
    required this.frequency,
    required this.instructions,
    required this.prescribedBy,
    this.confirmationAllowed = true,
    this.status = DoseStatus.upcoming,
    this.confirmedAt,
  });
}

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final _doses = <MedicationDose>[
    MedicationDose(
      id: 'clinic-dose-1',
      medicine: 'Clinic prescription',
      dosage: 'Details awaiting clinic update',
      time: '—',
      frequency: 'Not available',
      instructions: 'No active clinic-authorized prescriptions are available.',
      prescribedBy: 'Thaai Seyazhi care team',
      confirmationAllowed: false,
    ),
  ];
  bool _remindersEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _remindersEnabled =
          preferences.getBool('medication_reminders_enabled') ?? false;
      _loading = false;
    });
  }

  Future<void> _setReminders(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('medication_reminders_enabled', enabled);
    if (mounted) setState(() => _remindersEnabled = enabled);
  }

  String _statusLabel(DoseStatus status) => switch (status) {
    DoseStatus.upcoming => 'Upcoming',
    DoseStatus.due => 'Due now',
    DoseStatus.taken => 'Taken',
    DoseStatus.skipped => 'Skipped',
    DoseStatus.missed => 'Missed',
  };

  Color _statusColor(DoseStatus status) => switch (status) {
    DoseStatus.taken => AppColors.success,
    DoseStatus.skipped || DoseStatus.missed => AppColors.error,
    DoseStatus.due => AppColors.warning,
    DoseStatus.upcoming => AppColors.secondaryText,
  };

  Future<void> _confirmDose(MedicationDose dose, DoseStatus status) async {
    final action = status == DoseStatus.taken ? 'taken' : 'skipped';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('Mark dose $action?'),
        content: LocalizedText(
          'This records the clinic-authorized dose as $action in your medication history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: LocalizedText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: LocalizedText('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      dose.status = status;
      dose.confirmedAt = DateTime.now();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: LocalizedText('Dose marked $action.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: LocalizedText('Medication Management'),
        actions: [
          IconButton(
            tooltip: localizedText(context, 'Support'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommunicationScreen()),
            ),
            icon: const Icon(Icons.support_agent_outlined),
          ),
          IconButton(
            tooltip: localizedText(context, 'Medication history'),
            onPressed: () => _showHistory(context),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                DashboardCard(
                  color: AppColors.burgundy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'TODAY\'S MEDICATION SCHEDULE',
                        style: TextStyle(
                          color: AppColors.dustyPink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LocalizedText(
                        '${_doses.where((dose) => dose.status == DoseStatus.taken).length} doses completed',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      LocalizedText(
                        'Only prescriptions published by your clinic appear here.',
                        style: TextStyle(color: AppColors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: LocalizedText(
                        'Reminder settings',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: _remindersEnabled,
                      onChanged: _setReminders,
                      activeThumbColor: AppColors.burgundy,
                    ),
                  ],
                ),
                Text(
                  _remindersEnabled
                      ? 'Dose reminders are enabled on this device.'
                      : 'Reminders are disabled.',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                LocalizedText(
                  'TODAY',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                ..._doses.map(_doseCard),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showReminderPreview(context),
                  icon: const Icon(Icons.notifications_none_rounded),
                  label: LocalizedText('Preview reminder notification'),
                ),
              ],
            ),
    );
  }

  Widget _doseCard(MedicationDose dose) {
    final unavailable = dose.dosage.startsWith('Details awaiting');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dose.medicine,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: LocalizedText(
                    localizedText(context, _statusLabel(dose.status)),
                    style: TextStyle(
                      color: _statusColor(dose.status),
                      fontSize: 10,
                    ),
                  ),
                  backgroundColor: _statusColor(dose.status)
                      .withValues(alpha: .12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LocalizedText(
              '${dose.dosage}  •  ${dose.time}  •  ${dose.frequency}',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dose.instructions,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            LocalizedText(
              'Prescribed by: ${dose.prescribedBy}',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
            if (!unavailable &&
                dose.status != DoseStatus.taken &&
                dose.status != DoseStatus.skipped)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: dose.confirmationAllowed
                        ? () => _confirmDose(dose, DoseStatus.skipped)
                        : null,
                    child: LocalizedText('Skip'),
                  ),
                  FilledButton(
                    onPressed: dose.confirmationAllowed
                        ? () => _confirmDose(dose, DoseStatus.taken)
                        : null,
                    child: LocalizedText('Mark taken'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicationHistoryScreen()),
    );
  }

  void _showReminderPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: LocalizedText('Reminder preview'),
        content: const ListTile(
          leading: Icon(
            Icons.notifications_active_outlined,
            color: AppColors.burgundy,
          ),
          title: LocalizedText('Medication reminder'),
          subtitle: LocalizedText('Your clinic-authorized dose is due now.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: LocalizedText('Close'),
          ),
        ],
      ),
    );
  }
}

class MedicationHistoryScreen extends StatelessWidget {
  const MedicationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: LocalizedText('Medication History')),
    backgroundColor: AppColors.background,
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: LocalizedText(
          'No medication confirmations recorded yet.\n\nHistory is saved when a permitted dose is marked taken or skipped.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText, height: 1.5),
        ),
      ),
    ),
  );
}
