import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'models/appointment_models.dart';
import 'appointment_calendar_screen.dart';

class DoctorProfileScreen extends StatelessWidget {
  final Doctor doctor;
  final String patientName;
  final String mobileNumber;

  const DoctorProfileScreen({
    super.key,
    required this.doctor,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Doctor profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          CircleAvatar(
            radius: 39,
            backgroundColor: AppColors.blushPink,
            child: Text(
              doctor.initials,
              style: const TextStyle(
                color: AppColors.burgundy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              doctor.name,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              doctor.specialty,
              style: const TextStyle(
                color: AppColors.burgundy,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Center(
            child: Text(
              doctor.languages,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.divider),
            ),
            child: LocalizedText(
              'Consultation information is sample data for this prototype. Live availability will be supplied by Thaai Seyazhi.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentCalendarScreen(
                    doctor: doctor,
                    patientName: patientName,
                    mobileNumber: mobileNumber,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: LocalizedText('Request appointment'),
            ),
          ),
        ],
      ),
    );
  }
}
