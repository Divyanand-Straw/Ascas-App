import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/step_progress_bar.dart';
import 'new_patient/mobile_registration_screen.dart';

class PatientTypeScreen extends StatefulWidget {
  const PatientTypeScreen({super.key});

  @override
  State<PatientTypeScreen> createState() => _PatientTypeScreenState();
}

class _PatientTypeScreenState extends State<PatientTypeScreen> {
  int? _selectedOption;

  static const _options = [
    (
      title: 'New Patient',
      description: 'Create a new Thaai Seyazhi patient account.',
      icon: Icons.person_outline,
    ),
    (
      title: 'Existing Thaai Seyazhi Patient',
      description: 'Securely link an existing clinic record.',
      icon: Icons.verified_user_outlined,
    ),
    (
      title: 'Partner / Linked Member',
      description: 'Use a patient-authorized invitation.',
      icon: Icons.favorite_border,
    ),
  ];

  void _continue() {
  if (_selectedOption == null) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MobileRegistrationScreen(
        patientType: _options[_selectedOption!].title,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primaryText,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'STEP 1 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Patient type',
                          style: TextStyle(
                            color: AppColors.burgundy,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text(
                      'Exit',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 16),
              const StepProgressBar(currentStep: 1),
              const SizedBox(height: 28),
              const Text(
                'SECURE REGISTRATION',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'How are you joining\nThaai Seyazhi?',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the option that matches your relationship with the clinic.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                _options.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PatientTypeOption(
                    title: _options[index].title,
                    description: _options[index].description,
                    icon: _options[index].icon,
                    selected: _selectedOption == index,
                    onTap: () => setState(() => _selectedOption = index),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedOption == null ? null : _continue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientTypeOption extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PatientTypeOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.burgundy : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.burgundy, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: AppColors.burgundy,
              size: 23,
            ),
          ],
        ),
      ),
    );
  }
}
