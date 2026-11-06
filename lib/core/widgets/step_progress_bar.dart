import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: currentStep / totalSteps,
        minHeight: 5,
        backgroundColor: AppColors.divider,
        valueColor: const AlwaysStoppedAnimation<Color>(
          AppColors.burgundy,
        ),
      ),
    );
  }
}