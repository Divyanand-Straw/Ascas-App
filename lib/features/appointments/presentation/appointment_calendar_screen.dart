import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import 'available_date_screen.dart';
import 'models/appointment_models.dart';

class AppointmentCalendarScreen extends StatefulWidget {
  final Doctor doctor;
  final String patientName;
  final String mobileNumber;

  const AppointmentCalendarScreen({
    super.key,
    required this.doctor,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  State<AppointmentCalendarScreen> createState() =>
      _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState extends State<AppointmentCalendarScreen> {
  static const _deepBurgundy = Color(0xFF6B1837);
  static const _burgundyDark = Color(0xFF4D1029);
  static const _dustyPink = Color(0xFFC9879D);
  static const _blushPink = Color(0xFFF8E9EE);
  static const _palePink = Color(0xFFFFF5F7);
  static const _primaryText = Color(0xFF30232A);
  static const _secondaryText = Color(0xFF806D76);
  static const _mutedDate = Color(0xFFC5AAB5);
  static const _border = Color(0xFFEADCE2);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <Widget>[];
    for (var i = 0; i < firstDay.weekday - 1; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= days; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final past = date.isBefore(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final selected =
          _selectedDate?.year == date.year &&
          _selectedDate?.month == date.month &&
          _selectedDate?.day == date.day;
      final today =
          date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;
      cells.add(
        InkWell(
          onTap: past ? null : () => setState(() => _selectedDate = date),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _deepBurgundy : Colors.transparent,
              shape: BoxShape.circle,
              border: today && !selected
                  ? Border.all(color: _dustyPink, width: 1.5)
                  : null,
            ),
            child: LocalizedText(
              '$day',
              style: TextStyle(
                color: past
                    ? _mutedDate
                    : selected
                    ? Colors.white
                    : _primaryText,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _palePink,
      appBar: AppBar(
        backgroundColor: _deepBurgundy,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const LocalizedText(
          'Choose a date',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.doctor.name,
            style: const TextStyle(
              color: _primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          LocalizedText(
            'Sample dates for prototype demonstration.',
            style: TextStyle(color: _secondaryText, fontSize: 11),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _burgundyDark.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _deepBurgundy,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                        color: Colors.white,
                        tooltip: 'Previous month',
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: LocalizedText(
                          '${_monthName(_month.month)} ${_month.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                        color: Colors.white,
                        tooltip: 'Next month',
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    LocalizedText(
                      'M',
                      style: TextStyle(
                        color: _deepBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    LocalizedText(
                      'T',
                      style: TextStyle(
                        color: _deepBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    LocalizedText(
                      'W',
                      style: TextStyle(
                        color: _deepBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    LocalizedText(
                      'T',
                      style: TextStyle(
                        color: _deepBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    LocalizedText(
                      'F',
                      style: TextStyle(
                        color: _deepBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    LocalizedText(
                      'S',
                      style: TextStyle(
                        color: _deepBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    LocalizedText(
                      'S',
                      style: TextStyle(
                        color: _deepBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 4,
                  children: cells,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedDate == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvailableDateScreen(
                        doctor: widget.doctor,
                        selectedDate: _selectedDate!,
                        patientName: widget.patientName,
                        mobileNumber: widget.mobileNumber,
                      ),
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _deepBurgundy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _blushPink,
              disabledForegroundColor: _mutedDate,
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

  static String _monthName(int month) => const [
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
  ][month - 1];
}
