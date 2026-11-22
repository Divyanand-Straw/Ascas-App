import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import 'booking_confirmation_screen.dart';
import 'data/appointment_data.dart';
import 'models/appointment_models.dart';

class BookingReviewScreen extends StatefulWidget {
  final Doctor doctor;
  final DateTime date;
  final String time;
  final String patientName;
  final String appointmentType;
  final String consultationMode;
  final String reason;
  final String notes;

  const BookingReviewScreen({
    super.key,
    required this.doctor,
    required this.date,
    required this.time,
    required this.patientName,
    required this.appointmentType,
    required this.consultationMode,
    required this.reason,
    required this.notes,
  });

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  bool _isSubmitting = false;
  String? _submissionError;

  Future<void> _submitBooking() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final appointment = await addAppointment(
        doctor: widget.doctor,
        date: widget.date,
        time: widget.time,
        patientName: widget.patientName,
        appointmentType: widget.appointmentType,
        consultationMode: widget.consultationMode,
        reason: widget.reason,
        notes: widget.notes,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(
            doctor: widget.doctor,
            date: widget.date,
            time: widget.time,
            patientName: widget.patientName,
            reason: widget.reason,
            status: appointment.status,
            appointment: appointment,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _submissionError =
              error is DuplicateAppointmentException
              ? localizedText(
                  context,
                  'This appointment is already booked. Choose another time or review your appointments.',
                )
              : '${localizedText(context, 'Unable to save this demo booking. Please try again.')} $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const LocalizedText('Review booking'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _row('Doctor', widget.doctor.name),
          _row('Specialty', widget.doctor.specialty),
          _row('Clinic', 'Thaai Seyali Clinic'),
          _row('Date', _formatDate(context, widget.date)),
          _row('Time', widget.time),
          _row('Appointment type', widget.appointmentType),
          _row('Consultation mode', widget.consultationMode),
          _row('Patient', widget.patientName),
          _row('Consultation reason', widget.reason),
          if (widget.notes.trim().isNotEmpty)
            _row('Additional notes', widget.notes.trim()),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.blushPink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const LocalizedText(
              'Demo/local booking only. No live clinic slot is reserved.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          if (_submissionError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submissionError!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  child: const LocalizedText('Edit details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.divider,
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const LocalizedText('Confirm Booking'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: LocalizedText(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: LocalizedText(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
