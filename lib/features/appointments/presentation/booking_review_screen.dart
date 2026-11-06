import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'data/appointment_data.dart';
import 'booking_confirmation_screen.dart';
import 'models/appointment_models.dart';

class BookingReviewScreen extends StatelessWidget {
  final Doctor doctor;
  final DateTime date;
  final String time;
  final String patientName;
  final String appointmentType;
  final String consultationMode;
  final String notes;

  const BookingReviewScreen({
    super.key,
    required this.doctor,
    required this.date,
    required this.time,
    required this.patientName,
    required this.appointmentType,
    required this.consultationMode,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Review booking'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _row('Doctor', doctor.name),
          _row('Specialty', doctor.specialty),
          _row('Date', '${date.day} ${_month(date.month)}'),
          _row('Time', time),
          _row('Appointment type', appointmentType),
          _row('Consultation mode', consultationMode),
          _row('Patient', patientName),
          _row('Additional notes', notes.isEmpty ? 'None' : notes),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Edit details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await addAppointment(
                      doctor: doctor,
                      date: date,
                      time: time,
                      patientName: patientName,
                      appointmentType: appointmentType,
                      consultationMode: consultationMode,
                      notes: notes,
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingConfirmationScreen(
                          doctor: doctor,
                          date: date,
                          time: time,
                          patientName: patientName,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                  ),
                  child: const Text('Submit request'),
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
            child: Text(label,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.primaryText, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static String _month(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}
