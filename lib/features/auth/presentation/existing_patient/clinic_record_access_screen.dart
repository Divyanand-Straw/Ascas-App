
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/step_progress_bar.dart';
import '../new_patient/profile_confirmation_screen.dart';

class ClinicRecordAccessScreen extends StatefulWidget {
  final String mobileNumber;

  const ClinicRecordAccessScreen({
    super.key,
    required this.mobileNumber,
  });

  @override
  State<ClinicRecordAccessScreen> createState() =>
      _ClinicRecordAccessScreenState();
}

class _ClinicRecordAccessScreenState
    extends State<ClinicRecordAccessScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _patientIdController =
      TextEditingController();
  late final TextEditingController _mobileController;
  final TextEditingController _dobController = TextEditingController();

  static const _mockPatientId = 'AS-20481';
  static const _mockDateOfBirth = '14/08/1992';

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController(text: widget.mobileNumber);
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1992, 8, 14),
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
      hintStyle: const TextStyle(
        color: AppColors.secondaryText,
        fontSize: 13,
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
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
        borderSide: const BorderSide(
          color: AppColors.burgundy,
          width: 1.4,
        ),
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
    bool enabled = true,
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
          enabled: enabled,
          onTap: onTap,
          validator: validator ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter $label.';
                }
                return null;
              },
          decoration: _inputDecoration(hint),
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _verifyClinicAccess() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final patientId = _patientIdController.text.trim().toUpperCase();
    final dateOfBirth = _dobController.text.trim();
    if (patientId != _mockPatientId || dateOfBirth != _mockDateOfBirth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'These details do not match our prototype clinic record. '
            'Use Patient ID AS-20481 and date of birth 14/08/1992.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileConfirmationScreen(
          fullName: 'Ananya Iyer',
          dateOfBirth: dateOfBirth,
          mobileNumber: _mobileController.text.trim(),
          preferredLanguage: 'English',
          isExistingPatient: true,
          patientId: patientId,
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
                            'Patient ID / MRN',
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
                      onPressed: () => Navigator.popUntil(
                        context,
                        (route) => route.isFirst,
                      ),
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

                const Divider(
                  color: AppColors.divider,
                  height: 1,
                ),

                const SizedBox(height: 16),

                const StepProgressBar(currentStep: 4),

                const SizedBox(height: 30),

                const Text(
                  'PATIENT ID / MRN',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Enter your Patient ID',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 25,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Enter the Patient ID or MRN from your existing hospital record.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                _buildTextField(
                  label: 'Patient ID / MRN',
                  hint: 'Enter your Patient ID / MRN',
                  controller: _patientIdController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9-]'),
                    ),
                  ],
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{2,}$')
                            .hasMatch(value.trim())) {
                      return 'Please enter your Patient ID / MRN.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Registered mobile number',
                  hint: 'Verified mobile number',
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  readOnly: true,
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
                      return 'Verified mobile number is unavailable.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Date of birth',
                  hint: 'DD/MM/YYYY',
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDate,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please select your date of birth.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _verifyClinicAccess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Continue',
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
}
