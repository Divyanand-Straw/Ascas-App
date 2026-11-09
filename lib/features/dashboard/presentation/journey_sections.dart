import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/medication/presentation/demo_reminder_card.dart';
import '../data/treatment_journey_data.dart';
import 'widgets/dashboard_card.dart';

class OvulationTrackerScreen extends StatefulWidget {
  const OvulationTrackerScreen({super.key});

  @override
  State<OvulationTrackerScreen> createState() => _OvulationTrackerScreenState();
}

class _OvulationTrackerScreenState extends State<OvulationTrackerScreen> {
  DateTime? _lastPeriod;
  int _cycleLength = 28;
  bool _remindersEnabled = false;

  DateTime? get _currentCycleStart {
    final lastPeriod = _lastPeriod;
    if (lastPeriod == null) return null;
    final today = DateTime.now();
    var cycleStart = DateTime(
      lastPeriod.year,
      lastPeriod.month,
      lastPeriod.day,
    );
    while (!cycleStart.add(Duration(days: _cycleLength)).isAfter(today)) {
      cycleStart = cycleStart.add(Duration(days: _cycleLength));
    }
    return cycleStart;
  }

  DateTime? get _nextEstimatedOvulation {
    final cycleStart = _currentCycleStart;
    return cycleStart?.add(Duration(days: _cycleLength - 14));
  }

  DateTime? get _fertileStart =>
      _nextEstimatedOvulation?.subtract(const Duration(days: 5));

  DateTime? get _fertileEnd =>
      _nextEstimatedOvulation?.add(const Duration(days: 1));

  Future<void> _selectLastPeriod() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _lastPeriod ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (selected != null && mounted) setState(() => _lastPeriod = selected);
  }

  String _date(DateTime? date) {
    if (date == null) return 'Not entered';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cycleStart = _currentCycleStart;
    final cycleDay = cycleStart == null
        ? null
        : DateTime.now().difference(cycleStart).inDays + 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const LocalizedText('Ovulation Tracker'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          DashboardCard(
            color: AppColors.burgundy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalizedText(
                  'Estimates only · Not a medical result or pregnancy prediction',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _estimateRow('Cycle length', '$_cycleLength days'),
                _estimateRow(
                  'Cycle day',
                  cycleDay == null ? 'Not available' : '$cycleDay',
                ),
                _estimateRow('Last menstrual period', _date(_lastPeriod)),
                _estimateRow(
                  'Estimated ovulation',
                  _date(_nextEstimatedOvulation),
                ),
                _estimateRow(
                  'Estimated fertile window',
                  _fertileStart == null
                      ? 'Not available'
                      : '${_date(_fertileStart)} – ${_date(_fertileEnd)}',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.dustyPink),
                  ),
                  onPressed: _selectLastPeriod,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const LocalizedText('Enter last menstrual period'),
                ),
                const SizedBox(height: 12),
                const LocalizedText('Cycle length'),
                Slider(
                  value: _cycleLength.toDouble(),
                  min: 21,
                  max: 35,
                  divisions: 14,
                  activeColor: AppColors.dustyPink,
                  onChanged: (value) =>
                      setState(() => _cycleLength = value.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DashboardSectionHeader(title: 'Cycle calendar'),
                const SizedBox(height: 8),
                _CycleCalendar(
                  lastPeriod: _lastPeriod,
                  fertileStart: _fertileStart,
                  fertileEnd: _fertileEnd,
                  ovulation: _nextEstimatedOvulation,
                ),
                const SizedBox(height: 8),
                const LocalizedText(
                  'Estimated dates may vary. Contact your care team for clinical guidance.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const LocalizedText('Cycle reminders'),
                  subtitle: const LocalizedText(
                    'Local tracker reminder preference',
                  ),
                  value: _remindersEnabled,
                  activeThumbColor: AppColors.burgundy,
                  onChanged: (value) =>
                      setState(() => _remindersEnabled = value),
                ),
                if (_currentCycleStart == null)
                  const LocalizedText(
                    'Previous cycle information: Not available',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  )
                else
                  Row(
                    children: [
                      const Expanded(
                        child: LocalizedText(
                          'Previous cycle start estimate',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        _date(
                          _currentCycleStart!.subtract(
                            Duration(days: _cycleLength),
                          ),
                        ),
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CycleDetailsScreen(
                          lastPeriod: _lastPeriod,
                          cycleLength: _cycleLength,
                          remindersEnabled: _remindersEnabled,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const LocalizedText('View Detailed Cycle'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateRow(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LocalizedText(
            title,
            style: const TextStyle(color: AppColors.dustyPink, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: value == 'Not entered' || value == 'Not available'
              ? LocalizedText(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    ),
  );
}

class CycleDetailsScreen extends StatefulWidget {
  final DateTime? lastPeriod;
  final int cycleLength;
  final bool remindersEnabled;

  const CycleDetailsScreen({
    super.key,
    required this.lastPeriod,
    required this.cycleLength,
    required this.remindersEnabled,
  });

  @override
  State<CycleDetailsScreen> createState() => _CycleDetailsScreenState();
}

class _CycleDetailsScreenState extends State<CycleDetailsScreen> {
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthNames = [
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

  late DateTime _visibleMonth = DateUtils.dateOnly(DateTime.now());
  late DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  DateTime? get _activeCycleStart {
    final lastPeriod = widget.lastPeriod;
    if (lastPeriod == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    final recordedStart = DateUtils.dateOnly(lastPeriod);
    if (recordedStart.isAfter(today)) return recordedStart;
    final elapsedDays = today.difference(recordedStart).inDays;
    final cyclesElapsed = elapsedDays ~/ widget.cycleLength;
    return recordedStart.add(
      Duration(days: cyclesElapsed * widget.cycleLength),
    );
  }

  DateTime? _cycleStartFor(DateTime date) {
    final activeStart = _activeCycleStart;
    if (activeStart == null) return null;
    final dayOffset = DateUtils.dateOnly(date).difference(activeStart).inDays;
    final cycleDayIndex =
        ((dayOffset % widget.cycleLength) + widget.cycleLength) %
        widget.cycleLength;
    return DateUtils.dateOnly(date).subtract(Duration(days: cycleDayIndex));
  }

  DateTime? _ovulationFor(DateTime date) {
    final cycleStart = _cycleStartFor(date);
    return cycleStart?.add(Duration(days: widget.cycleLength - 14));
  }

  DateTime? _fertileStartFor(DateTime date) =>
      _ovulationFor(date)?.subtract(const Duration(days: 5));

  DateTime? _fertileEndFor(DateTime date) =>
      _ovulationFor(date)?.add(const Duration(days: 1));

  int? _cycleDayFor(DateTime date) {
    final cycleStart = _cycleStartFor(date);
    if (cycleStart == null) return null;
    final dayOffset = DateUtils.dateOnly(date).difference(cycleStart).inDays;
    return dayOffset + 1;
  }

  String _phaseFor(DateTime date) {
    if (_activeCycleStart == null) {
      return 'Enter a period start to view estimates';
    }
    final cycleStart = _cycleStartFor(date)!;
    final cycleDay = _cycleDayFor(date)!;
    final ovulation = _ovulationFor(date)!;
    final fertileStart = _fertileStartFor(date)!;
    final fertileEnd = _fertileEndFor(date)!;
    if (cycleDay <= 5) return 'Period phase · estimated';
    if (_isSameCycleDate(date, ovulation)) return 'Estimated ovulation day';
    if (!date.isBefore(fertileStart) && !date.isAfter(fertileEnd)) {
      return 'Estimated fertile window';
    }
    if (date.isBefore(ovulation)) return 'Follicular phase · estimated';
    if (cycleStart.add(Duration(days: widget.cycleLength)).isAfter(date)) {
      return 'Luteal phase · estimated';
    }
    return 'Cycle day $cycleDay · estimated';
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      final daysInMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        0,
      ).day;
      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        _selectedDate.day.clamp(1, daysInMonth),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeStart = _activeCycleStart;
    final previousStart = activeStart?.subtract(
      Duration(days: widget.cycleLength),
    );
    final nextStart = activeStart?.add(Duration(days: widget.cycleLength));
    final cycleDay = _cycleDayFor(_selectedDate);
    final ovulation = _ovulationFor(_selectedDate);
    final fertileStart = _fertileStartFor(_selectedDate);
    final fertileEnd = _fertileEndFor(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const LocalizedText('Detailed Cycle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          DashboardCard(
            color: AppColors.burgundy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalizedText(
                  'Estimates only · Not a medical result or pregnancy prediction',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _cycleDetailRow('Cycle length', '${widget.cycleLength} days'),
                _cycleDetailRow(
                  'Selected cycle day',
                  cycleDay == null ? 'Not available' : '$cycleDay',
                ),
                _cycleDetailRow('Cycle phase', _phaseFor(_selectedDate)),
                _cycleDetailRow(
                  'Selected date',
                  _formatCycleDate(_selectedDate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LocalizedText(
                            _monthNames[_visibleMonth.month - 1],
                            style: const TextStyle(
                              color: AppColors.burgundy,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            ' ${_visibleMonth.year}',
                            style: const TextStyle(
                              color: AppColors.burgundy,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: _weekdayLabels
                      .map(
                        (label) => Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _DetailedCycleCalendar(
                  month: _visibleMonth,
                  selectedDate: _selectedDate,
                  lastPeriod: widget.lastPeriod,
                  activeCycleStart: activeStart,
                  cycleLength: widget.cycleLength,
                  onSelect: (date) => setState(() => _selectedDate = date),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _CycleLegend(
                      color: AppColors.burgundy,
                      label: 'Period estimate',
                    ),
                    _CycleLegend(
                      color: AppColors.blushPink,
                      label: 'Fertile window estimate',
                    ),
                    _CycleLegend(
                      color: AppColors.dustyPink,
                      label: 'Ovulation estimate',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardCard(
            color: AppColors.burgundy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalizedText(
                  'Selected day details',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _cycleDetailRow(
                  'Cycle phase',
                  _phaseFor(_selectedDate),
                  light: true,
                ),
                _cycleDetailRow(
                  'Cycle day',
                  cycleDay == null ? 'Not available' : '$cycleDay',
                  light: true,
                ),
                _cycleDetailRow(
                  'Estimated fertile window',
                  fertileStart == null
                      ? 'Not available'
                      : '${_formatCycleDate(fertileStart)} – '
                            '${_formatCycleDate(fertileEnd!)}',
                  light: true,
                ),
                _cycleDetailRow(
                  'Estimated ovulation',
                  ovulation == null
                      ? 'Not available'
                      : _formatCycleDate(ovulation),
                  light: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DashboardSectionHeader(title: 'Cycle progression'),
                const SizedBox(height: 14),
                _CycleProgression(
                  cycleDay: cycleDay,
                  cycleLength: widget.cycleLength,
                ),
                const SizedBox(height: 14),
                _cycleDetailRow(
                  'Period start',
                  activeStart == null
                      ? 'Not recorded'
                      : _formatCycleDate(activeStart),
                ),
                _cycleDetailRow(
                  'Estimated period end',
                  activeStart == null
                      ? 'Not available'
                      : _formatCycleDate(
                          activeStart.add(const Duration(days: 4)),
                        ),
                ),
                _cycleDetailRow('Period duration', '5 days · estimate only'),
                _cycleDetailRow(
                  'Previous cycle start',
                  previousStart == null
                      ? 'Not available'
                      : _formatCycleDate(previousStart),
                ),
                _cycleDetailRow(
                  'Upcoming cycle start',
                  nextStart == null
                      ? 'Not available'
                      : _formatCycleDate(nextStart),
                ),
                _cycleDetailRow(
                  'Recorded entries',
                  widget.lastPeriod == null
                      ? 'No period start recorded'
                      : 'Period start · ${_formatCycleDate(widget.lastPeriod!)}',
                ),
                _cycleDetailRow(
                  'Cycle reminders',
                  widget.remindersEnabled ? 'Enabled' : 'Off',
                ),
                const SizedBox(height: 8),
                const LocalizedText(
                  'Cycle phases, period duration, fertile days, and dates shown here are estimates. They are not confirmed medical results.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSameCycleDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

class _DetailedCycleCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final DateTime? lastPeriod;
  final DateTime? activeCycleStart;
  final int cycleLength;
  final ValueChanged<DateTime> onSelect;

  const _DetailedCycleCalendar({
    required this.month,
    required this.selectedDate,
    required this.lastPeriod,
    required this.activeCycleStart,
    required this.cycleLength,
    required this.onSelect,
  });

  DateTime? _cycleStartFor(DateTime date) {
    final start = activeCycleStart;
    if (start == null) return null;
    final offset = DateUtils.dateOnly(date).difference(start).inDays;
    final dayIndex = ((offset % cycleLength) + cycleLength) % cycleLength;
    return DateUtils.dateOnly(date).subtract(Duration(days: dayIndex));
  }

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    return GridView.builder(
      key: const ValueKey('detailed-cycle-calendar'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: offset + days,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, index - offset + 1);
        final cycleStart = _cycleStartFor(date);
        final cycleDay = cycleStart == null
            ? null
            : date.difference(cycleStart).inDays + 1;
        final ovulation = cycleStart?.add(Duration(days: cycleLength - 14));
        final fertileStart = ovulation?.subtract(const Duration(days: 5));
        final fertileEnd = ovulation?.add(const Duration(days: 1));
        final isPeriod = cycleDay != null && cycleDay <= 5;
        final isFertile =
            fertileStart != null &&
            fertileEnd != null &&
            !date.isBefore(fertileStart) &&
            !date.isAfter(fertileEnd);
        final isOvulation = ovulation != null && _isSameDay(date, ovulation);
        final isSelected = _isSameDay(date, selectedDate);
        final isRecordedPeriod =
            lastPeriod != null &&
            _isSameDay(date, DateUtils.dateOnly(lastPeriod!));
        final backgroundColor = isOvulation || isRecordedPeriod || isPeriod
            ? AppColors.burgundy
            : isFertile
            ? AppColors.blushPink
            : Colors.transparent;

        return Semantics(
          button: true,
          selected: isSelected,
          label: 'Cycle day ${date.day}',
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              key: ValueKey('cycle-day-${date.year}-${date.month}-${date.day}'),
              borderRadius: BorderRadius.circular(9),
              onTap: () => onSelect(date),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: isSelected || isOvulation
                      ? Border.all(
                          color: isOvulation
                              ? AppColors.dustyPink
                              : AppColors.burgundy,
                          width: 2,
                        )
                      : null,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isPeriod || isOvulation || isRecordedPeriod
                        ? AppColors.white
                        : AppColors.primaryText,
                    fontSize: 11,
                    fontWeight: isSelected || isFertile || isPeriod
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CycleLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CycleLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      LocalizedText(
        label,
        style: const TextStyle(color: AppColors.secondaryText, fontSize: 10),
      ),
    ],
  );
}

class _CycleProgression extends StatelessWidget {
  final int? cycleDay;
  final int cycleLength;

  const _CycleProgression({required this.cycleDay, required this.cycleLength});

  @override
  Widget build(BuildContext context) {
    final progress = cycleDay == null
        ? 0.0
        : (cycleDay! / cycleLength).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.blushPink,
            color: AppColors.burgundy,
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _DayLabel('Period'),
            _DayLabel('Fertile window'),
            _DayLabel('Luteal'),
          ],
        ),
      ],
    );
  }
}

Widget _cycleDetailRow(String label, String value, {bool light = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LocalizedText(
              label,
              style: TextStyle(
                color: light ? AppColors.dustyPink : AppColors.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LocalizedText(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: light ? AppColors.white : AppColors.primaryText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

String _formatCycleDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

class _CycleCalendar extends StatelessWidget {
  final DateTime? lastPeriod;
  final DateTime? fertileStart;
  final DateTime? fertileEnd;
  final DateTime? ovulation;

  const _CycleCalendar({
    required this.lastPeriod,
    required this.fertileStart,
    required this.fertileEnd,
    required this.ovulation,
  });

  @override
  Widget build(BuildContext context) {
    final month = ovulation ?? DateTime.now();
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DayLabel('M'),
            _DayLabel('T'),
            _DayLabel('W'),
            _DayLabel('T'),
            _DayLabel('F'),
            _DayLabel('S'),
            _DayLabel('S'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offset + days,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final day = index - offset + 1;
            final date = DateTime(month.year, month.month, day);
            final fertile =
                fertileStart != null &&
                fertileEnd != null &&
                !date.isBefore(fertileStart!) &&
                !date.isAfter(fertileEnd!);
            final isOvulation = ovulation != null && _sameDay(date, ovulation!);
            final isPeriod = lastPeriod != null && _sameDay(date, lastPeriod!);
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isOvulation || isPeriod
                    ? AppColors.burgundy
                    : fertile
                    ? AppColors.blushPink
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: isOvulation
                    ? Border.all(color: AppColors.dustyPink, width: 2)
                    : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  color: isOvulation || isPeriod
                      ? AppColors.white
                      : AppColors.primaryText,
                  fontSize: 11,
                  fontWeight: fertile || isOvulation || isPeriod
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _DayLabel extends StatelessWidget {
  final String label;

  const _DayLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.secondaryText,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
  );
}

class TreatmentTimelineScreen extends StatelessWidget {
  final String title;
  final List<String> stages;
  final TreatmentPathway pathway;

  const TreatmentTimelineScreen({
    super.key,
    required this.title,
    required this.stages,
    required this.pathway,
  });

  @override
  Widget build(BuildContext context) {
    final milestones = pathway.milestones;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: LocalizedText(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          DashboardCard(
            color: AppColors.burgundy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const LocalizedText(
                  'A general milestone guide. Your care team determines your applicable stages, dates and instructions.',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              children: [
                if (milestones.isNotEmpty)
                  ...milestones.map(
                    (milestone) => _MilestoneRow(
                      name: milestone.name,
                      status: switch (milestone.status) {
                        TreatmentMilestoneStatus.completed => 'Completed',
                        TreatmentMilestoneStatus.current => 'Current',
                        TreatmentMilestoneStatus.upcoming => 'Upcoming',
                        TreatmentMilestoneStatus.awaitingUpdate =>
                          'Awaiting clinic update',
                      },
                      date:
                          milestone.completionDate ??
                          milestone.scheduledDate ??
                          milestone.startDate,
                      details: [
                        milestone.description,
                        if (milestone.instructions?.isNotEmpty == true)
                          milestone.instructions!,
                      ].where((value) => value.isNotEmpty).join('\n'),
                    ),
                  )
                else
                  ...stages.map(
                    (stage) => _MilestoneRow(
                      name: stage,
                      status: 'Awaiting clinic update',
                      details: 'Guide only. This stage is not confirmed as part of your personal treatment plan.',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const LocalizedText(
            'No milestone is marked complete unless your clinic provides that status.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final String name;
  final String status;
  final String? date;
  final String details;

  const _MilestoneRow({
    required this.name,
    required this.status,
    this.date,
    required this.details,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: const Icon(
      Icons.radio_button_unchecked_rounded,
      color: AppColors.dustyPink,
    ),
    title: LocalizedText(
      name,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          status,
          style: const TextStyle(
            color: AppColors.burgundy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (date != null) Text(date!, style: const TextStyle(fontSize: 11)),
      ],
    ),
    trailing: const Icon(Icons.info_outline, color: AppColors.burgundy),
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText(name),
        content: LocalizedText(
          details.isEmpty
              ? 'Clinic instructions and updates will appear when provided.'
              : details,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LocalizedText('Close'),
          ),
        ],
      ),
    ),
  );
}

class MedicationScheduleScreen extends StatelessWidget {
  const MedicationScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const LocalizedText('Medication Schedule'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: const [
        DemoReminderCard(showAll: true),
        SizedBox(height: 14),
        DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardSectionHeader(title: 'Daily schedule'),
              SizedBox(height: 8),
              LocalizedText('No clinic-published medication schedule.'),
              SizedBox(height: 10),
              LocalizedText(
                'Prescribed dosage, clinical instructions and start/end dates will only appear when supplied by your care team. Sample reminders do not modify a prescription.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class JourneySectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const JourneySectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.white,
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.divider),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.burgundy),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    title,
                    style: const TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.burgundy),
          ],
        ),
      ),
    ),
  );
}
