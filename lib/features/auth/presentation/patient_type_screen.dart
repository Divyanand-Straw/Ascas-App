import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (
        title: l10n.newPatient,
        description: l10n.newPatientDescription,
        icon: Icons.person_outline,
      ),
      (
        title: l10n.existingPatient,
        description: l10n.existingPatientDescription,
        icon: Icons.verified_user_outlined,
      ),
      (
        title: l10n.linkedMember,
        description: l10n.linkedMemberDescription,
        icon: Icons.favorite_border,
      ),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
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
                  Expanded(
                    child: Column(
                      children: [
                        LocalizedText(
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
                          l10n.patientType,
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
                    child: Text(
                      l10n.exit,
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
              Text(
                l10n.secureRegistration,
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.howJoining,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.relationshipClinic,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(
                _options.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PatientTypeOption(
                    title: options[index].title,
                    description: options[index].description,
                    icon: options[index].icon,
                    selected: _selectedOption == index,
                    onTap: () => setState(() => _selectedOption = index),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedOption == null ? null : _continue,
                  child: Text(l10n.continueText),
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
        padding: const EdgeInsets.all(16),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.burgundy, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      height: 1.3,
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
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
