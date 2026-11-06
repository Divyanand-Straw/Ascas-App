import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import 'models/appointment_models.dart';

class RescheduleRequestScreen extends StatefulWidget {
  final Appointment appointment;
  final String patientName;
  final String mobileNumber;

  const RescheduleRequestScreen({
    super.key,
    required this.appointment,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  State<RescheduleRequestScreen> createState() =>
      _RescheduleRequestScreenState();
}

class _RescheduleRequestScreenState extends State<RescheduleRequestScreen> {
  DateTime? _date;
  String? _time;
  final _times = const ['09:00 AM', '10:30 AM', '02:00 PM'];

  @override
  Widget build(BuildContext context) {
    final nextDate = DateTime.now().add(const Duration(days: 14));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Reschedule request'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.appointment.title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Current: ${widget.appointment.date.day} ${_month(widget.appointment.date.month)} · ${widget.appointment.time}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose a new sample date',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                initialDate: nextDate,
              );
              if (selected != null) setState(() => _date = selected);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _date == null
                  ? 'Select date'
                  : '${_date!.day} ${_month(_date!.month)} ${_date!.year}',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose a new sample time',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _times
                .map(
                  (time) => ChoiceChip(
                    label: Text(time),
                    selected: _time == time,
                    onSelected: (_) => setState(() => _time = time),
                    selectedColor: AppColors.blushPink,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _date == null || _time == null
                ? null
                : () => _submit(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.divider,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Review rescheduling request'),
          ),
          const SizedBox(height: 12),
          const Text(
            'A rescheduling request remains pending until the clinic approves it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit rescheduling request?'),
        content: Text(
          'New sample slot: ${_date!.day} ${_month(_date!.month)} · $_time',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await NotificationService.instance
                  .showReschedulingRequest(widget.appointment);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Your rescheduling request has been submitted and is awaiting clinic confirmation.',
                  ),
                ),
              );
            },
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
  }

  static String _month(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}
