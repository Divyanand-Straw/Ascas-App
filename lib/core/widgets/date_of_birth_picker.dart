import 'package:flutter/material.dart';

import '../localization/localized_text.dart';
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
  DateTime? firstDate,
  DateTime? lastDate,
  Set<DateTime> disabledDates = const {},
  String? placeholder,
  String Function(DateTime)? dateFormat,
  VoidCallback? onCancel,
  ValueChanged<DateTime>? onConfirm,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final minimum = DateUtils.dateOnly(firstDate ?? DateTime(1900));
  final maximum = DateUtils.dateOnly(lastDate ?? today);
  final boundedMaximum = maximum.isAfter(today) ? today : maximum;
  final defaultInitial = DateTime(today.year - 30, today.month, today.day);
  final candidate = DateUtils.dateOnly(initialDate ?? defaultInitial);
  final selectedDate = _clampDate(
    candidate,
    minimum,
    boundedMaximum,
    disabledDates,
  );

  return showDialog<DateTime>(
    context: context,
    builder: (context) => ThaaiDatePickerDialog(
      initialDate: selectedDate,
      firstDate: minimum,
      lastDate: boundedMaximum,
      disabledDates: disabledDates,
      placeholder: placeholder,
      dateFormat: dateFormat,
      onCancel: onCancel,
      onConfirm: onConfirm,
    ),
  );
}

DateTime _clampDate(
  DateTime date,
  DateTime firstDate,
  DateTime lastDate,
  Set<DateTime> disabledDates,
) {
  var candidate = DateUtils.dateOnly(date);
  if (candidate.isBefore(firstDate)) candidate = firstDate;
  if (candidate.isAfter(lastDate)) candidate = lastDate;
  if (!_isDisabled(candidate, disabledDates)) return candidate;
  for (var offset = 1; offset <= 3660; offset++) {
    final before = candidate.subtract(Duration(days: offset));
    if (!before.isBefore(firstDate) && !_isDisabled(before, disabledDates)) {
      return before;
    }
    final after = candidate.add(Duration(days: offset));
    if (!after.isAfter(lastDate) && !_isDisabled(after, disabledDates)) {
      return after;
    }
  }
  return candidate;
}

bool _isDisabled(DateTime date, Set<DateTime> disabledDates) =>
    disabledDates.any((disabled) => DateUtils.isSameDay(disabled, date));

class ThaaiDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> disabledDates;
  final String? placeholder;
  final String Function(DateTime)? dateFormat;
  final VoidCallback? onCancel;
  final ValueChanged<DateTime>? onConfirm;

  const ThaaiDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.disabledDates = const {},
    this.placeholder,
    this.dateFormat,
    this.onCancel,
    this.onConfirm,
  });

  @override
  State<ThaaiDatePickerDialog> createState() => _ThaaiDatePickerDialogState();
}

enum _PickerPanel { none, month, year }

class _ThaaiDatePickerDialogState extends State<ThaaiDatePickerDialog> {
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
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late DateTime _selectedDate = DateUtils.dateOnly(widget.initialDate);
  late DateTime _visibleMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );
  _PickerPanel _panel = _PickerPanel.none;
  bool _yearSelected = false;

  bool get _canGoPrevious => _visibleMonth.isAfter(
    DateTime(widget.firstDate.year, widget.firstDate.month),
  );

  bool get _canGoNext => _visibleMonth.isBefore(
    DateTime(widget.lastDate.year, widget.lastDate.month),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  const SizedBox(height: 15),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _calendar()),
                        if (_panel != _PickerPanel.none) ...[
                          const SizedBox(width: 12),
                          SizedBox(width: 154, child: _dropdownPanel()),
                        ],
                      ],
                    )
                  else ...[
                    _selectors(),
                    if (_panel != _PickerPanel.none) ...[
                      const SizedBox(height: 10),
                      _dropdownPanel(),
                    ],
                    const SizedBox(height: 12),
                    _calendar(includeSelectors: false),
                  ],
                  const SizedBox(height: 15),
                  _actions(),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _header() => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _fertilityJourneyBlush,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.cake_outlined,
          color: _fertilityJourneyBurgundy,
          size: 20,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText(
              'Select date of birth',
              style: TextStyle(
                color: _fertilityJourneyBurgundy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.dateFormat?.call(_selectedDate) ??
                  '${widget.placeholder == null ? '' : '${widget.placeholder} · '}${formatDateOfBirth(_selectedDate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _fertilityJourneySecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: localizedText(context, 'Close'),
        onPressed: _cancel,
        icon: const Icon(Icons.close_rounded),
        color: AppColors.secondaryText,
      ),
    ],
  );

  Widget _selectors() => Row(
    children: [
      Expanded(
        child: _selectorButton(
          _yearSelected
              ? 'Select month · ${_visibleMonth.year}'
              : _months[_visibleMonth.month - 1],
          _PickerPanel.month,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _selectorButton(
          _yearSelected ? '${_visibleMonth.year}' : 'Select year',
          _PickerPanel.year,
        ),
      ),
    ],
  );

  Widget _selectorButton(String label, _PickerPanel panel) => OutlinedButton(
    onPressed: () =>
        setState(() => _panel = _panel == panel ? _PickerPanel.none : panel),
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      foregroundColor: _fertilityJourneyBurgundy,
      backgroundColor: _fertilityJourneyPale,
      side: const BorderSide(color: _fertilityJourneyDivider),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      children: [
        Expanded(
          child: LocalizedText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      ],
    ),
  );

  Widget _dropdownPanel() => Container(
    constraints: const BoxConstraints(maxHeight: 250),
    decoration: BoxDecoration(
      color: _fertilityJourneyPale,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _fertilityJourneyDivider),
    ),
    child: _panel == _PickerPanel.month
        ? ListView.builder(
            shrinkWrap: true,
            itemCount: _months.length,
            itemBuilder: (context, index) {
              final month = index + 1;
              final enabled = _monthHasSelectableDate(month);
              return _dropdownItem(
                key: ValueKey('dob-month-option-$month'),
                label: _months[index],
                selected: month == _visibleMonth.month,
                enabled: enabled,
                onTap: () {
                  setState(() {
                    _visibleMonth = DateTime(_visibleMonth.year, month);
                    _panel = _PickerPanel.none;
                    _selectedDate = _safeDateForMonth(_visibleMonth);
                  });
                },
              );
            },
          )
        : ListView.builder(
            shrinkWrap: true,
            itemCount: widget.lastDate.year - widget.firstDate.year + 1,
            itemBuilder: (context, index) {
              final year = widget.lastDate.year - index;
              return _dropdownItem(
                key: ValueKey('dob-year-option-$year'),
                label: '$year',
                selected: year == _visibleMonth.year,
                onTap: () {
                  setState(() {
                    _visibleMonth = DateTime(year, _visibleMonth.month);
                    _panel = _PickerPanel.none;
                    _yearSelected = true;
                    _selectedDate = _safeDateForMonth(_visibleMonth);
                  });
                },
              );
            },
          ),
  );

  Widget _dropdownItem({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) => InkWell(
    key: key,
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: selected ? _fertilityJourneyBlush : Colors.transparent,
      child: LocalizedText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: enabled ? _fertilityJourneyPrimary : _fertilityJourneyMuted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    ),
  );

  Widget _calendar({bool includeSelectors = true}) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final leadingDays = firstOfMonth.weekday - DateTime.monday;
    final cells = 42;
    return Column(
      children: [
        if (includeSelectors) _selectors(),
        Row(
          children: [
            IconButton(
              onPressed: _canGoPrevious
                  ? () => setState(
                      () => _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month - 1,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: _fertilityJourneyBurgundy,
            ),
            Expanded(
              child: LocalizedText(
                '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _fertilityJourneyPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: _canGoNext
                  ? () => setState(
                      () => _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: _fertilityJourneyBurgundy,
            ),
          ],
        ),
        Row(
          children: _weekdays
              .map(
                (day) => Expanded(
                  child: LocalizedText(
                    day,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _fertilityJourneySecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const ValueKey('dob-day-calendar'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final dayOffset = index - leadingDays;
            final date = DateTime(
              _visibleMonth.year,
              _visibleMonth.month,
              dayOffset + 1,
            );
            final inMonth = date.month == _visibleMonth.month;
            final disabled =
                date.isBefore(widget.firstDate) ||
                date.isAfter(widget.lastDate) ||
                _isDisabled(date, widget.disabledDates);
            return _dayCell(date, inMonth && !disabled, inMonth);
          },
        ),
      ],
    );
  }

  Widget _dayCell(DateTime date, bool enabled, bool inMonth) {
    final selected = DateUtils.isSameDay(date, _selectedDate);
    final today = DateUtils.isSameDay(date, DateTime.now());
    return InkWell(
      onTap: enabled ? () => setState(() => _selectedDate = date) : null,
      borderRadius: BorderRadius.circular(30),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _fertilityJourneyBurgundy : Colors.transparent,
            shape: BoxShape.circle,
            border: today && !selected
                ? Border.all(color: _fertilityJourneyDustyPink, width: 2)
                : null,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: !inMonth || !enabled
                  ? _fertilityJourneyMuted
                  : selected
                  ? AppColors.white
                  : _fertilityJourneyPrimary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() => Row(
    children: [
      Expanded(
        child: TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(
            backgroundColor: _fertilityJourneyBlush,
            foregroundColor: _fertilityJourneyBurgundy,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const LocalizedText('Cancel'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton(
          onPressed: _isDisabled(_selectedDate, widget.disabledDates)
              ? null
              : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _fertilityJourneyBurgundy,
            foregroundColor: AppColors.white,
            minimumSize: const Size.fromHeight(44),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const LocalizedText('Set Date'),
        ),
      ),
    ],
  );

  bool _monthHasSelectableDate(int month) {
    final first = DateTime(_visibleMonth.year, month);
    final last = DateTime(_visibleMonth.year, month + 1, 0);
    return !last.isBefore(widget.firstDate) && !first.isAfter(widget.lastDate);
  }

  DateTime _safeDateForMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final candidate = DateTime(
      month.year,
      month.month,
      _selectedDate.day.clamp(1, lastDay),
    );
    return _clampDate(
      candidate,
      widget.firstDate,
      widget.lastDate,
      widget.disabledDates,
    );
  }

  void _cancel() {
    widget.onCancel?.call();
    Navigator.pop(context);
  }

  void _confirm() {
    final selected = DateUtils.dateOnly(_selectedDate);
    widget.onConfirm?.call(selected);
    Navigator.pop(context, selected);
  }
}

const _fertilityJourneyBurgundy = Color(0xFF6B1837);
const _fertilityJourneyDustyPink = Color(0xFFC9879D);
const _fertilityJourneyBlush = Color(0xFFF8E9EE);
const _fertilityJourneyPale = Color(0xFFFFF5F7);
const _fertilityJourneyPrimary = Color(0xFF30232A);
const _fertilityJourneySecondary = Color(0xFF806D76);
const _fertilityJourneyMuted = Color(0xFFC5AAB5);
const _fertilityJourneyDivider = Color(0xFFEADCE2);
