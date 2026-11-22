import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../appointments/presentation/appointment_detail_screen.dart';
import '../../appointments/presentation/data/appointment_data.dart';
import '../../communication/presentation/communication_screen.dart';
import '../../dashboard/presentation/widgets/treatment_overview_screen.dart';
import '../../medical_records/presentation/medical_records_screen.dart';
import '../../medication/presentation/medication_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isLinkedPartner;
  final Map<String, bool> partnerPermissions;

  const NotificationsScreen({
    super.key,
    this.isLinkedPartner = false,
    this.partnerPermissions = const {},
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService.instance;
  NotificationCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool _isAllowed(InAppNotification notification) {
    if (!widget.isLinkedPartner) return true;
    return switch (notification.category) {
      NotificationCategory.appointment ||
      NotificationCategory.appointmentConfirmation ||
      NotificationCategory.appointmentUpdated =>
        widget.partnerPermissions['Appointments'] == true,
      NotificationCategory.medication =>
        widget.partnerPermissions['Medication schedules'] == true ||
            widget.partnerPermissions['Prescriptions'] == true,
      NotificationCategory.journey =>
        widget.partnerPermissions['Treatment Journey'] == true,
      NotificationCategory.medicalRecord =>
        widget.partnerPermissions['Medical Reports'] == true ||
            widget.partnerPermissions['Discharge Summary'] == true ||
            widget.partnerPermissions['Prescriptions'] == true,
      NotificationCategory.payment =>
        widget.partnerPermissions['Bills and Payments'] == true ||
            widget.partnerPermissions['IP Billing'] == true,
      NotificationCategory.clinicMessage =>
        widget.partnerPermissions['Notifications and clinic updates'] == true,
      NotificationCategory.general => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _service.inbox.where(_isAllowed).toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    final visibleNotifications = _selectedCategory == null
        ? notifications
        : notifications
              .where((item) => item.category == _selectedCategory)
              .toList();
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.burgundy,
              AppColors.dustyPink,
              AppColors.blushPink,
            ],
            stops: [0, .35, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: notifications.isEmpty
                      ? _emptyState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
                          children: [
                            _actions(context, visibleNotifications),
                            const SizedBox(height: 8),
                            _categoryFilters(),
                            const SizedBox(height: 14),
                            if (visibleNotifications.isEmpty)
                              _filteredEmptyState()
                            else
                              ...visibleNotifications.map(_notificationCard),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            color: AppColors.white,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Notifications',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _date(),
                  style: const TextStyle(color: AppColors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _clock(),
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 30,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    List<InAppNotification> visibleNotifications,
  ) {
    final unreadCount = visibleNotifications
        .where((notification) => !notification.isRead)
        .length;
    return Row(
      children: [
        Expanded(
          child: LocalizedText(
            unreadCount == 0
                ? 'All notifications read'
                : '$unreadCount unread notifications',
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: widget.isLinkedPartner || unreadCount == 0
              ? null
              : _service.markAllRead,
          child: const LocalizedText('Mark all as read'),
        ),
        if (!widget.isLinkedPartner)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _confirmClear(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: LocalizedText('Clear notifications'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _categoryFilters() {
    const categories = [
      null,
      NotificationCategory.appointment,
      NotificationCategory.medication,
      NotificationCategory.journey,
      NotificationCategory.medicalRecord,
      NotificationCategory.payment,
      NotificationCategory.clinicMessage,
      NotificationCategory.general,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final selected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: LocalizedText(
                category == null ? 'All' : _categoryLabel(category),
              ),
              selected: selected,
              onSelected: (_) => setState(() => _selectedCategory = category),
              selectedColor: AppColors.burgundy,
              backgroundColor: AppColors.white,
              labelStyle: TextStyle(
                color: selected ? AppColors.white : AppColors.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              side: const BorderSide(color: AppColors.divider),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _categoryLabel(NotificationCategory category) => switch (category) {
    NotificationCategory.appointment ||
    NotificationCategory.appointmentConfirmation ||
    NotificationCategory.appointmentUpdated => 'Appointments',
    NotificationCategory.medication => 'Medications',
    NotificationCategory.journey => 'Treatment updates',
    NotificationCategory.medicalRecord => 'Reports & records',
    NotificationCategory.payment => 'Payments',
    NotificationCategory.clinicMessage => 'Clinic updates',
    NotificationCategory.general => 'General',
  };

  Widget _filteredEmptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    child: Column(
      children: [
        const Icon(
          Icons.filter_alt_off_outlined,
          color: AppColors.dustyPink,
          size: 46,
        ),
        const SizedBox(height: 12),
        const LocalizedText(
          'No notifications in this category.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _selectedCategory = null),
          child: const LocalizedText('Show all notifications'),
        ),
      ],
    ),
  );

  Widget _notificationCard(InAppNotification notification) {
    final category = notification.category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: notification.isRead
            ? AppColors.white
            : AppColors.blushPink.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openNotification(notification),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _categoryIcon(category),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              localizedText(context, _title(notification)),
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(context, notification.createdAt),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _localizedBody(context, notification),
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LocalizedText(
                            _categoryLabel(category),
                            style: const TextStyle(
                              color: AppColors.burgundy,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _dateTime(notification.createdAt),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 8, top: 5),
                    decoration: const BoxDecoration(
                      color: AppColors.burgundy,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryIcon(NotificationCategory category) {
    final icon = switch (category) {
      NotificationCategory.medication => Icons.medication_outlined,
      NotificationCategory.appointment ||
      NotificationCategory.appointmentConfirmation ||
      NotificationCategory.appointmentUpdated => Icons.calendar_month_outlined,
      NotificationCategory.clinicMessage => Icons.chat_bubble_outline_rounded,
      NotificationCategory.journey => Icons.timeline_rounded,
      NotificationCategory.medicalRecord => Icons.description_outlined,
      NotificationCategory.payment => Icons.receipt_long_outlined,
      NotificationCategory.general => Icons.notifications_none_rounded,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.blushPink,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.burgundy),
    );
  }

  Future<void> _openNotification(InAppNotification notification) async {
    if (!_isAllowed(notification)) return;
    if (!widget.isLinkedPartner) await _service.markRead(notification);
    if (!mounted) return;
    final appointment = findAppointmentById(notification.appointmentId);
    if (appointment != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailsScreen(appointment: appointment),
        ),
      );
      return;
    }
    final page = switch (notification.category) {
      NotificationCategory.medication => MedicationScreen(
        isLinkedPartner: widget.isLinkedPartner,
        canViewMedicationSchedule:
            !widget.isLinkedPartner ||
            widget.partnerPermissions['Medication schedules'] == true,
        canViewPrescriptions:
            !widget.isLinkedPartner ||
            widget.partnerPermissions['Prescriptions'] == true,
      ),
      NotificationCategory.clinicMessage => const CommunicationScreen(),
      NotificationCategory.journey => const TreatmentOverviewScreen(
        treatmentName: 'Treatment pathway',
      ),
      NotificationCategory.medicalRecord => MedicalRecordsScreen(
        isLinkedPartner: widget.isLinkedPartner,
        partnerPermissions: widget.partnerPermissions,
      ),
      NotificationCategory.payment =>
        widget.isLinkedPartner &&
                widget.partnerPermissions['Bills and Payments'] != true
            ? const IpBillingScreen()
            : const BillsPaymentsScreen(),
      _ => null,
    };
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalizedText('Clear notifications?'),
        content: const LocalizedText(
          'This removes notifications saved on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LocalizedText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LocalizedText('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.clearAll();
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.dustyPink,
            size: 60,
          ),
          const SizedBox(height: 14),
          const LocalizedText(
            'No notifications yet.',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  String _title(InAppNotification notification) {
    if (notification.title == 'Appointment Reminder') {
      return 'Upcoming Appointment';
    }
    return notification.title;
  }

  String _body(InAppNotification notification) => notification.body;

  String _localizedBody(BuildContext context, InAppNotification notification) {
    final title = _title(notification);
    if (title == 'Upcoming Appointment') {
      return localizedText(
        context,
        'You have an upcoming appointment. Please review the appointment details.',
      );
    }
    if (title == 'Appointment Request Submitted') {
      return localizedText(
        context,
        'Your appointment request was submitted and is awaiting clinic confirmation.',
      );
    }
    if (title == 'Appointment Cancelled') {
      return localizedText(
        context,
        'Your appointment has been cancelled successfully.',
      );
    }
    if (title == 'Rescheduling Request Submitted') {
      return localizedText(
        context,
        'Your rescheduling request is awaiting clinic confirmation.',
      );
    }
    return localizedText(context, _body(notification));
  }

  String _relativeTime(BuildContext context, DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    final tamil =
        AppLocalizations.of(context)?.localeName.startsWith('ta') ?? false;
    if (difference.inMinutes < 1) return tamil ? 'இப்போது' : 'Now';
    if (difference.inMinutes < 60) {
      return tamil
          ? '${difference.inMinutes} நிமிடங்களுக்கு முன்'
          : '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return tamil
          ? '${difference.inHours} மணி நேரத்திற்கு முன்'
          : '${difference.inHours} hour ago';
    }
    if (difference.inDays == 1) return tamil ? 'நேற்று' : 'Yesterday';
    return tamil
        ? '${difference.inDays} நாட்களுக்கு முன்'
        : '${difference.inDays} days ago';
  }

  String _date() {
    final now = DateTime.now();
    const months = [
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
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _clock() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '$hour:${now.minute.toString().padLeft(2, '0')}';
  }

  String _dateTime(DateTime value) =>
      '${value.day}/${value.month}/${value.year} · ${TimeOfDay.fromDateTime(value).format(context)}';
}
