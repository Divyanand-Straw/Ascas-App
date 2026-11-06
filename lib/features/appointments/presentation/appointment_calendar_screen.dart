import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
      final past = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      final selected = _selectedDate?.year == date.year &&
          _selectedDate?.month == date.month &&
          _selectedDate?.day == date.day;
      cells.add(
        InkWell(
          onTap: past ? null : () => setState(() => _selectedDate = date),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.burgundy : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: past
                    ? AppColors.divider
                    : selected
                        ? AppColors.white
                        : AppColors.primaryText,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Choose a date'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.doctor.name,
              style: const TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          const Text('Sample dates for prototype demonstration.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${_monthName(_month.month)} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('M'), Text('T'), Text('W'), Text('T'), Text('F'), Text('S'), Text('S'),
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
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.divider,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  static String _monthName(int month) =>
      const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];
}
