import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
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

  static const _demoSlots = [
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
    '05:30 PM',
    '06:00 PM',
    '06:30 PM',
  ];

  bool get _usingSampleAvailability =>
      widget.doctor.availableTimeSlots == null &&
      widget.doctor.unavailableTimeSlots == null;

  List<String> get _availableSlots =>
      _usingSampleAvailability
          ? _demoSlots
          : widget.doctor.availableTimeSlots ?? const [];

  List<String> get _unavailableSlots =>
      widget.doctor.unavailableTimeSlots ?? const [];

  List<String> get _allSlots => _usingSampleAvailability
      ? _demoSlots
      : {
          ..._availableSlots,
          ..._unavailableSlots,
        }.toList(growable: false);

  List<String> get _morningSlots => _allSlots
      .where((slot) => slot.toUpperCase().contains('AM') || slot.startsWith('12:'))
      .toList(growable: false);

  List<String> get _eveningSlots => _allSlots
      .where((slot) => !slot.toUpperCase().contains('AM') && !slot.startsWith('12:'))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      elevation: 0,
      title: const LocalizedText('Choose a time'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _doctorCard(),
        const SizedBox(height: 14),
        _dateCard(context),
        const SizedBox(height: 18),
        const LocalizedText(
          'Select Your Preferred Time',
          style: TextStyle(
            color: _burgundy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (_usingSampleAvailability) ...[
          const LocalizedText(
            'Demo time slots only; these are not live clinic availability.',
            style: TextStyle(color: _secondaryText, fontSize: 11),
          ),
          const SizedBox(height: 12),
        ],
        _slotSection('Morning', _morningSlots),
        const SizedBox(height: 14),
        _slotSection('Evening', _eveningSlots),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: _bottomAction(context),
    ),
  );

  Widget _doctorCard() {
    final imageUrl = widget.doctor.profileImageUrl;
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: _blush,
            foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
            child: imageUrl == null
                ? Text(
                    widget.doctor.initials,
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
                  widget.doctor.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.doctor.qualifications?.isNotEmpty == true)
                  Text(
                    widget.doctor.qualifications!,
                    style: const TextStyle(color: _secondaryText, fontSize: 11),
                  ),
                Text(
                  widget.doctor.specialty,
                  style: const TextStyle(
                    color: _burgundy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.doctor.experience?.isNotEmpty == true)
                  Text(
                    widget.doctor.experience!,
                    style: const TextStyle(color: _secondaryText, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateCard(BuildContext context) => Container(
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
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(context, widget.selectedDate),
                    style: const TextStyle(
                      color: _primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  LocalizedText(
                    _usingSampleAvailability
                        ? 'Demo time slots for this date'
                        : 'Availability recorded for this date',
                    style: const TextStyle(
                      color: _secondaryText,
                      fontSize: 10,
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
  );

  Widget _slotSection(String title, List<String> slots) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LocalizedText(
        title,
        style: const TextStyle(
          color: _burgundy,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      if (slots.isEmpty)
        const _UnavailableMessage(message: 'No time slots are available.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map(_slotButton).toList(),
        ),
    ],
  );

  Widget _slotButton(String slot) {
    final available = _availableSlots.contains(slot) &&
        !_unavailableSlots.contains(slot);
    final selected = _selected == slot;
    return OutlinedButton(
      onPressed: available ? () => setState(() => _selected = slot) : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? _burgundy : _white,
        foregroundColor: selected ? _white : _burgundy,
        disabledForegroundColor: _secondaryText.withValues(alpha: 0.55),
        side: BorderSide(color: available ? _burgundy : _divider),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(slot),
    );
  }

  Widget _bottomAction(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          const Expanded(
            child: LocalizedText(
              'Selected time',
              style: TextStyle(color: _secondaryText, fontSize: 11),
            ),
          ),
          Text(
            _selected ?? 'Not selected',
            style: const TextStyle(
              color: _primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
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
    ],
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

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _white,
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

class _UnavailableMessage extends StatelessWidget {
  final String message;

  const _UnavailableMessage({required this.message});

  @override
  Widget build(BuildContext context) => LocalizedText(
    message,
    style: const TextStyle(color: _secondaryText, fontSize: 11),
  );
}

const _burgundy = Color(0xFF6B1837);
const _blush = Color(0xFFF8E9EE);
const _white = Color(0xFFFFFFFF);
const _background = Color(0xFFFFFBFA);
const _primaryText = Color(0xFF30232A);
const _secondaryText = Color(0xFF806D76);
const _divider = Color(0xFFEADCE2);
