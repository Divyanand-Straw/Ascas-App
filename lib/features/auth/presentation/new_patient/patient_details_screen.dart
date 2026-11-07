import 'package:flutter/material.dart';

import '../../../../core/services/locale_service.dart';

import 'package:flutter/services.dart';

import 'profile_confirmation_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/step_progress_bar.dart';

class PatientDetailsScreen extends StatefulWidget {
  final String mobileNumber;

  const PatientDetailsScreen({super.key, required this.mobileNumber});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emergencyController = TextEditingController();

  String _selectedLanguage = 'English';

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.burgundy,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _dobController.text =
            '${selectedDate.day.toString().padLeft(2, '0')}/'
            '${selectedDate.month.toString().padLeft(2, '0')}/'
            '${selectedDate.year}';
      });
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burgundy, width: 1.4),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.burgundy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          validator:
              validator ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter $label.';
                }
                return null;
              },
          decoration: _inputDecoration(hint),
          style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
        ),
      ],
    );
  }

  void _reviewProfile() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileConfirmationScreen(
          fullName: _nameController.text.trim(),
          dateOfBirth: _dobController.text.trim(),
          mobileNumber: widget.mobileNumber,
          preferredLanguage: _selectedLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
          child: Form(
            key: _formKey,
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
                            'STEP 4 OF 8',
                            style: TextStyle(
                              color: AppColors.dustyPink,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'New patient registration',
                            style: TextStyle(
                              color: AppColors.burgundy,
                              fontSize: 12,
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
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Divider(color: AppColors.divider, height: 1),

                const SizedBox(height: 16),
                const StepProgressBar(currentStep: 4),
                const SizedBox(height: 30),

                const Text(
                  'PATIENT DETAILS',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'New patient registration',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 25,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Complete the required identity and contact details.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                _buildTextField(
                  label: 'Full name',
                  hint: 'Enter your full name',
                  controller: _nameController,
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Date of birth',
                  hint: 'DD/MM/YYYY',
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDate,
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Email',
                  hint: 'Enter your email address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address.';
                    }

                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())) {
                      return 'Please enter a valid email address.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                _buildLabel('Mobile'),

                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: AppColors.blushPink.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '+91',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 24, color: AppColors.divider),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.mobileNumber,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.verified,
                        color: AppColors.success,
                        size: 19,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildLabel('Preferred language'),

                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _languageOption('English')),
                      Expanded(child: _languageOption('தமிழ்')),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Emergency contact',
                  hint: 'Enter emergency contact number',
                  controller: _emergencyController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an emergency contact number.';
                    }

                    final emergencyNumber = value.trim();
                    final mobileNumber = widget.mobileNumber.trim();

                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(emergencyNumber)) {
                      return 'Enter a valid 10-digit mobile number.';
                    }

                    if (emergencyNumber == mobileNumber) {
                      return 'Emergency contact must differ from your mobile number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _reviewProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Review profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageOption(String language) {
    final isSelected = _selectedLanguage == language;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLanguage = language;
        });
        LocaleService.rememberLanguage(language == 'தமிழ்' ? 'ta' : 'en');
      },
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.burgundy : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          language,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.secondaryText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
