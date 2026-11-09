import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

DateTime? parseDateOfBirth(String value) {
  final normalized = value.trim();
  final isoParts = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$')
      .firstMatch(normalized);
  final dayFirstParts = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$')
      .firstMatch(normalized);

  if (isoParts == null && dayFirstParts == null) return null;
  final parts = isoParts ?? dayFirstParts!;
  final year = int.parse(parts.group(isoParts != null ? 1 : 3)!);
  final month = int.parse(parts.group(2)!);
  final day = int.parse(parts.group(isoParts != null ? 3 : 1)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String formatDateOfBirth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

Future<DateTime?> showDateOfBirthPicker(
  BuildContext context, {
  DateTime? initialDate,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final firstDate = DateTime(1900);
  final defaultInitialDate = DateTime(today.year - 30, today.month, today.day);
  final candidate = DateUtils.dateOnly(initialDate ?? defaultInitialDate);
  final selectedDate = candidate.isBefore(firstDate)
      ? firstDate
      : candidate.isAfter(today)
      ? today
      : candidate;

  return showDialog<DateTime>(
    context: context,
    builder: (context) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.burgundy,
          onPrimary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.primaryText,
        ),
      ),
      child: _DateOfBirthPickerDialog(
        initialDate: selectedDate,
        firstDate: firstDate,
        lastDate: today,
      ),
    ),
  );
}

enum _PickerStep { year, month, day }

class _DateOfBirthPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateOfBirthPickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DateOfBirthPickerDialog> createState() =>
      _DateOfBirthPickerDialogState();
}

class _DateOfBirthPickerDialogState extends State<_DateOfBirthPickerDialog> {
  static const _months = [
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
  ];

  late DateTime _selectedDate = widget.initialDate;
  late int _selectedYear = widget.initialDate.year;
  late int _selectedMonth = widget.initialDate.month;
  late final ScrollController _yearScrollController;
  _PickerStep _step = _PickerStep.year;

  @override
  void initState() {
    super.initState();
    final yearIndex = widget.lastDate.year - widget.initialDate.year;
    _yearScrollController = ScrollController(
      initialScrollOffset: (yearIndex ~/ 4) * 56,
    );
  }

  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  void _selectYear(int year) {
    setState(() {
      _selectedYear = year;
      _step = _PickerStep.month;
    });
  }

  void _selectMonth(int month) {
    final lastDayOfMonth = DateTime(_selectedYear, month + 1, 0).day;
    final day = _selectedDate.day.clamp(1, lastDayOfMonth);
    var date = DateTime(_selectedYear, month, day);
    if (date.isAfter(widget.lastDate)) date = widget.lastDate;

    setState(() {
      _selectedMonth = month;
      _selectedDate = date;
      _step = _PickerStep.day;
    });
  }

  String get _title => switch (_step) {
    _PickerStep.year => 'Select year',
    _PickerStep.month => 'Select month · $_selectedYear',
    _PickerStep.day => '${_months[_selectedMonth - 1]} $_selectedYear',
  };

  @override
  Widget build(BuildContext context) {
    final years = [
      for (
        var year = widget.lastDate.year;
        year >= widget.firstDate.year;
        year--
      )
        year,
    ];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: 360,
        height: 490,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  if (_step != _PickerStep.year)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => setState(
                        () => _step = _step == _PickerStep.day
                            ? _PickerStep.month
                            : _PickerStep.year,
                      ),
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.burgundy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildStep(years)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(List<int> years) => switch (_step) {
    _PickerStep.year => GridView.builder(
      key: const ValueKey('dob-year-grid'),
      controller: _yearScrollController,
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        return _PickerChoice(
          label: '$year',
          selected: year == _selectedYear,
          onTap: () => _selectYear(year),
        );
      },
    ),
    _PickerStep.month => GridView.builder(
      key: const ValueKey('dob-month-grid'),
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.55,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: _months.length,
      itemBuilder: (context, index) {
        final month = index + 1;
        final firstDay = DateTime(_selectedYear, month);
        final enabled =
            !firstDay.isAfter(widget.lastDate) &&
            !DateTime(_selectedYear, month + 1, 0).isBefore(widget.firstDate);
        return _PickerChoice(
          label: _months[index],
          selected: month == _selectedMonth,
          enabled: enabled,
          onTap: () => _selectMonth(month),
        );
      },
    ),
    _PickerStep.day => CalendarDatePicker(
      key: const ValueKey('dob-day-calendar'),
      initialDate: _selectedDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      currentDate: widget.lastDate,
      initialCalendarMode: DatePickerMode.day,
      onDateChanged: (date) => Navigator.pop(context, date),
    ),
  };
}

class _PickerChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PickerChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.burgundy : AppColors.background,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: !enabled
                  ? AppColors.secondaryText.withValues(alpha: .45)
                  : selected
                  ? AppColors.white
                  : AppColors.primaryText,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}
