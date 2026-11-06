import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'appointment_detail_screen.dart';
import 'data/appointment_data.dart';
import 'models/appointment_models.dart';
import 'widgets/appointment_widgets.dart';

class CancellationConfirmationScreen extends StatefulWidget {
  final Appointment appointment;

  const CancellationConfirmationScreen({
    super.key,
    required this.appointment,
  });

  @override
  State<CancellationConfirmationScreen> createState() =>
      _CancellationConfirmationScreenState();
}

class _CancellationConfirmationScreenState
    extends State<CancellationConfirmationScreen> {
  bool _cancelled = false;

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Cancel appointment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointment.title,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${appointment.date.day} ${_month(appointment.date.month)} · ${appointment.time}',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            if (_cancelled) ...[
              const AppointmentStatusBadge('Cancelled'),
              const SizedBox(height: 14),
              const Text(
                'Your appointment has been cancelled successfully.',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentDetailsScreen(
                        appointment: appointment,
                      ),
                    ),
                  ),
                  child: const Text('View appointment details'),
                ),
              ),
            ] else ...[
              const Text(
                'Are you sure you want to cancel this appointment?',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Keep appointment'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await cancelAppointment(appointment);
                    if (mounted) setState(() => _cancelled = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                  ),
                  child: const Text('Confirm cancellation'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _month(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}
