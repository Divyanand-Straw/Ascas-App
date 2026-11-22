import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'booking_review_screen.dart';
import 'models/appointment_models.dart';

class BookingRequestScreen extends StatefulWidget {
  final Doctor doctor;
  final DateTime selectedDate;
  final String selectedTime;
  final String patientName;
  final String mobileNumber;

  const BookingRequestScreen({
    super.key,
    required this.doctor,
    required this.selectedDate,
    required this.selectedTime,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String _appointmentType = 'Monitoring consultation';
  String _mode = 'In clinic';
  String? _reason;

  List<String> get _consultationReasons {
    final specialty = widget.doctor.specialty.toLowerCase();
    if (specialty.contains('fertility') ||
        specialty.contains('reproductive') ||
        specialty.contains('ivf')) {
      return const [
        'General consultation',
        'Follow-up consultation',
        'Fertility consultation',
        'IVF consultation',
        'IUI consultation',
        'Treatment review',
        'Other',
      ];
    }
    return const [
      'General consultation',
      'Follow-up consultation',
      'Treatment review',
      'Other',
    ];
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Booking request'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _summary(),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _appointmentType,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Appointment type'),
              ),
              items: ['Monitoring consultation', 'Fertility consultation']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _appointmentType = value!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Consultation reason'),
              ),
              validator: (value) => value == null
                  ? localizedText(
                      context,
                      'Please select a consultation reason.',
                    )
                  : null,
              items: _consultationReasons
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(localizedText(context, item)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _reason = value),
            ),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Consultation mode'),
              ),
              items: ['In clinic', 'Video consultation']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _mode = value!),
            ),
            TextFormField(
              initialValue: widget.patientName,
              readOnly: true,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Patient name'),
              ),
              validator: _required,
            ),
            TextFormField(
              initialValue: widget.mobileNumber,
              readOnly: true,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Registered mobile number'),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Mobile number is required';
                }
                if (!RegExp(r'^[0-9+ ()-]{7,}$').hasMatch(value.trim())) {
                  return 'Enter a valid mobile number';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Additional notes'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingReviewScreen(
                        doctor: widget.doctor,
                        date: widget.selectedDate,
                        time: widget.selectedTime,
                        patientName: widget.patientName,
                        appointmentType: _appointmentType,
                        consultationMode: _mode,
                        reason: _reason!,
                        notes: _notesController.text,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: LocalizedText('Review booking'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.doctor.name,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.doctor.specialty,
            style: const TextStyle(color: AppColors.burgundy, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDate(context, widget.selectedDate)} · ${widget.selectedTime}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  static String _formatDate(BuildContext context, DateTime date) {
    final weekday = localizedText(
      context,
      const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][date.weekday - 1],
    );
    final month = localizedText(
      context,
      const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][date.month - 1],
    );
    return '$weekday, ${date.day} $month ${date.year}';
  }
}
