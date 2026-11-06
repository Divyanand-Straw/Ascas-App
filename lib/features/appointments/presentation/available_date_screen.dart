import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'available_time_screen.dart';
import 'models/appointment_models.dart';

class AvailableDateScreen extends StatelessWidget {
  final Doctor doctor;
  final DateTime selectedDate;
  final String patientName;
  final String mobileNumber;

  const AvailableDateScreen({
    super.key,
    required this.doctor,
    required this.selectedDate,
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
        title: const Text('Available date'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doctor.name,
                style: const TextStyle(color: AppColors.primaryText, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${selectedDate.day} ${_month(selectedDate.month)} ${selectedDate.year}',
                style: const TextStyle(color: AppColors.burgundy, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Selected sample date. Actual availability must be confirmed by Thaai Seyazhi.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 11, height: 1.4)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AvailableTimeScreen(
                      doctor: doctor,
                      selectedDate: selectedDate,
                      patientName: patientName,
                      mobileNumber: mobileNumber,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: const Text('Choose a time'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _month(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}
