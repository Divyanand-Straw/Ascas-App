import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'appointment_detail_screen.dart';
import 'models/appointment_models.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Doctor doctor;
  final DateTime date;
  final String time;
  final String patientName;
  final String status;
  final String reason;
  final Appointment? appointment;

  const BookingConfirmationScreen({
    super.key,
    required this.doctor,
    required this.date,
    required this.time,
    required this.patientName,
    this.reason = '',
    this.status = 'Requested',
    this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Booking request'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.blushPink,
                child: Icon(
                  status.toLowerCase() == 'confirmed'
                      ? Icons.check_circle_outline
                      : Icons.task_alt,
                  color: AppColors.burgundy,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              LocalizedText(
                status.toLowerCase() == 'confirmed'
                    ? 'CONFIRMED'
                    : 'DEMO BOOKING SAVED',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              LocalizedText(
                status.toLowerCase() == 'confirmed'
                    ? 'Your appointment is confirmed.'
                    : 'Your demo booking was saved on this device. It has not been sent to or confirmed by the clinic.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _detail('Doctor', doctor.name),
                    _detail('Date', _formatDate(context, date)),
                    _detail('Time', time),
                    if (reason.isNotEmpty) _detail('Consultation reason', reason),
                    if (appointment?.reference.isNotEmpty == true)
                      _detail('Appointment ID', appointment!.reference),
                    _detail('Booking status', status),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _detail('Patient', patientName),
              const SizedBox(height: 26),
              if (appointment != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppointmentDetailsScreen(
                          appointment: appointment!,
                          patientName: patientName,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: AppColors.white,
                    ),
                    child: const LocalizedText('View Appointment'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  child: const LocalizedText('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LocalizedText(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LocalizedText(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  static String _formatDate(BuildContext context, DateTime date) {
    final weekday = localizedText(
      context,
      const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][date.weekday - 1],
    );
    final month = localizedText(
      context,
      const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][date.month - 1],
    );
    return '$weekday, ${date.day} $month ${date.year}';
  }
}
