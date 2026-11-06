import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'models/appointment_models.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Doctor doctor;
  final DateTime date;
  final String time;
  final String patientName;

  const BookingConfirmationScreen({
    super.key,
    required this.doctor,
    required this.date,
    required this.time,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Booking request'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.blushPink,
                child: Icon(Icons.pending_actions, color: AppColors.burgundy, size: 32),
              ),
              const SizedBox(height: 18),
              const Text(
                'REQUESTED',
                style: TextStyle(color: AppColors.burgundy, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your appointment request has been submitted. The clinic will confirm the appointment after checking availability.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.primaryText, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                '${doctor.name}\n${date.day} ${_month(date.month)} · $time\nFor $patientName',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 12),
              const Text(
                'This request is awaiting clinic confirmation. It is not a confirmed appointment yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 26),
              OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _month(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}
