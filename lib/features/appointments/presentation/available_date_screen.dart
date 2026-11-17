import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
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
    final hasSelection = doctor.name.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const LocalizedText('Doctor details and working hours'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _doctorCard(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _blush,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: _burgundy,
                      size: 25,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LocalizedText(
                            'Selected appointment date',
                            style: TextStyle(
                              color: _burgundy,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(context, selectedDate),
                            style: const TextStyle(
                              color: _primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const LocalizedText('Change date'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _workingHoursCard(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: hasSelection
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvailableTimeScreen(
                        doctor: doctor,
                        selectedDate: selectedDate,
                        patientName: patientName,
                        mobileNumber: mobileNumber,
                      ),
                    ),
                  )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _burgundy,
              foregroundColor: _white,
              disabledBackgroundColor: _divider,
              disabledForegroundColor: _secondaryText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const LocalizedText('Continue'),
          ),
        ),
      ),
    );
  }

  Widget _doctorCard() => _Card(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: _blush,
          foregroundImage: doctor.profileImageUrl == null
              ? null
              : NetworkImage(doctor.profileImageUrl!),
          child: doctor.profileImageUrl == null
              ? Text(
                  doctor.initials,
                  style: const TextStyle(
                    color: _burgundy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctor.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (doctor.qualifications?.isNotEmpty == true)
                Text(
                  doctor.qualifications!,
                  style: const TextStyle(color: _secondaryText, fontSize: 11),
                ),
              Text(
                doctor.specialty,
                style: const TextStyle(
                  color: _burgundy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (doctor.experience?.isNotEmpty == true)
                Text(
                  doctor.experience!,
                  style: const TextStyle(color: _secondaryText, fontSize: 11),
                ),
              if (doctor.description?.isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(
                  doctor.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 7),
                const LocalizedText(
                  'Doctor description has not been provided.',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _workingHoursCard() {
    final isDemo =
        doctor.workingDays == null ||
        doctor.morningHours == null ||
        doctor.eveningHours == null;
    return _Card(
      tint: _palePink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LocalizedText(
            "Doctor's Working Hours",
            style: TextStyle(
              color: _burgundy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (isDemo) ...[
            const SizedBox(height: 4),
            const LocalizedText(
              'Demo working hours',
              style: TextStyle(
                color: _secondaryText,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _hourRow(
            'Working days',
            doctor.workingDays ?? 'Demo: Monday to Friday',
          ),
          _hourRow(
            'Morning',
            doctor.morningHours ?? 'Demo: 09:00 AM - 01:00 PM',
          ),
          _hourRow(
            'Evening',
            doctor.eveningHours ?? 'Demo: 04:00 PM - 07:00 PM',
          ),
          const SizedBox(height: 4),
          const LocalizedText(
            'General working hours only; these are not confirmed appointment slots.',
            style: TextStyle(color: _secondaryText, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _hourRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = LocalizedText(
          label,
          style: const TextStyle(color: _secondaryText, fontSize: 11),
        );
        final valueWidget = LocalizedText(
          value,
          textAlign: constraints.maxWidth < 300
              ? TextAlign.start
              : TextAlign.end,
          style: const TextStyle(
            color: _primaryText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 3), valueWidget],
          );
        }
        return Row(
          children: [
            Expanded(child: labelWidget),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );

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

class _Card extends StatelessWidget {
  final Widget child;
  final Color tint;

  const _Card({required this.child, this.tint = _white});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: _divider),
      boxShadow: [
        BoxShadow(
          color: _primaryText.withValues(alpha: 0.045),
          blurRadius: 13,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

const _burgundy = Color(0xFF6B1837);
const _blush = Color(0xFFF8E9EE);
const _palePink = Color(0xFFFFF5F7);
const _white = Color(0xFFFFFFFF);
const _background = Color(0xFFFFFBFA);
const _primaryText = Color(0xFF30232A);
const _secondaryText = Color(0xFF806D76);
const _divider = Color(0xFFEADCE2);
