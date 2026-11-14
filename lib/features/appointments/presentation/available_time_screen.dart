import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'booking_request_screen.dart';
import 'models/appointment_models.dart';

class AvailableTimeScreen extends StatefulWidget {
  final Doctor doctor;
  final DateTime selectedDate;
  final String patientName;
  final String mobileNumber;

  const AvailableTimeScreen({
    super.key,
    required this.doctor,
    required this.selectedDate,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  State<AvailableTimeScreen> createState() => _AvailableTimeScreenState();
}

class _AvailableTimeScreenState extends State<AvailableTimeScreen> {
  String? _selected;
  final _morningSlots = const [
    '09:00 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
  ];
  final _eveningSlots = const [
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Choose a time'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.doctor.name,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          LocalizedText(
            'Sample time slots only. Actual availability must be confirmed by Thaai Seyali.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _slotSection('MORNING SLOTS', _morningSlots),
          const SizedBox(height: 18),
          _slotSection('EVENING SLOTS', _eveningSlots),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingRequestScreen(
                        doctor: widget.doctor,
                        selectedDate: widget.selectedDate,
                        selectedTime: _selected!,
                        patientName: widget.patientName,
                        mobileNumber: widget.mobileNumber,
                      ),
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.divider,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: LocalizedText('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _slotSection(String title, List<String> slots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.dustyPink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final selected = slot == _selected;
            final unavailable = slot == '04:00 PM';
            return ChoiceChip(
              label: Text(slot),
              selected: selected,
              onSelected: unavailable
                  ? null
                  : (_) => setState(() => _selected = slot),
              selectedColor: AppColors.burgundy,
              disabledColor: AppColors.divider,
              labelStyle: TextStyle(
                color: unavailable
                    ? AppColors.secondaryText
                    : selected
                    ? AppColors.white
                    : AppColors.primaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        if (slots.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LocalizedText(
              'No sample slots are available.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
