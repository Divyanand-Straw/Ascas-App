import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';

class ClinicLocationScreen extends StatelessWidget {
  const ClinicLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Clinic location'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: AppColors.burgundy,
                  size: 30,
                ),
                SizedBox(height: 13),
                LocalizedText(
                  'Thaai Seyazhi Clinic',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 9),
                LocalizedText(
                  'Clinic address will be supplied by the care team.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                LocalizedText(
                  'Directions placeholder',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                LocalizedText(
                  'No map integration or verified clinic address is configured in this prototype.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
