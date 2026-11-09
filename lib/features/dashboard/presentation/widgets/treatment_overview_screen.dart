import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../communication/presentation/communication_screen.dart';
import '../../../education/presentation/education_screen.dart';
import '../journey_screen.dart';

class TreatmentOverviewScreen extends StatelessWidget {
  final String treatmentName;

  const TreatmentOverviewScreen({super.key, required this.treatmentName});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      foregroundColor: AppColors.burgundy,
      title: const LocalizedText(
        'My Fertility Journey',
        style: TextStyle(
          color: AppColors.burgundy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: localizedText(context, 'Education centre'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EducationScreen()),
          ),
          icon: const Icon(Icons.menu_book_outlined),
        ),
        IconButton(
          tooltip: localizedText(context, 'Support'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunicationScreen()),
          ),
          icon: const Icon(Icons.support_agent_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: JourneyScreen(treatmentName: treatmentName, showPageHeader: false),
    ),
  );
}
