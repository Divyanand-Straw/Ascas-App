import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/appointment_models.dart';
import '../data/appointment_data.dart';

class AppointmentStatusBadge extends StatelessWidget {
  final String label;

  const AppointmentStatusBadge(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final isConfirmed = normalized == 'confirmed' || normalized == 'completed';
    final isCancelled = normalized == 'cancelled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isConfirmed
            ? AppColors.success.withValues(alpha: 0.12)
            : isCancelled
            ? AppColors.error.withValues(alpha: 0.12)
            : AppColors.blushPink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LocalizedText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isConfirmed
              ? AppColors.success
              : isCancelled
              ? AppColors.error
              : AppColors.burgundy,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;
  final VoidCallback? onReschedule;
  final VoidCallback? onDirections;
  final VoidCallback? onCalendar;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.onReschedule,
    this.onDirections,
    this.onCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final doctor = _doctorFor(appointment.doctorName);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryText.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DoctorAvatar(appointment: appointment),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (appointment.specialty.isNotEmpty)
                      Text(
                        doctor?.qualifications?.isNotEmpty == true
                            ? '${doctor!.qualifications} · ${appointment.specialty}'
                            : appointment.specialty,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              AppointmentStatusBadge(_statusLabel(appointment.status)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            appointment.appointmentType,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.burgundy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _AppointmentInfoRow(
            icon: Icons.calendar_month_outlined,
            text:
                '${_weekday(appointment.date)}, ${appointment.date.day} ${_month(appointment.date)} · ${appointment.time}',
          ),
          _AppointmentInfoRow(
            icon: Icons.location_on_outlined,
            text: [
              appointment.clinic,
              if (appointment.room?.isNotEmpty == true) appointment.room!,
            ].join(' · '),
          ),
          if (appointment.clinicAddress?.isNotEmpty == true)
            _AppointmentInfoRow(
              icon: Icons.pin_drop_outlined,
              text: appointment.clinicAddress!,
            ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blushPink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalizedText(
                  'Preparation guidance',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                if (appointment.preparationGuidance.isEmpty)
                  const LocalizedText(
                    'No preparation guidance has been provided for this visit.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  )
                else
                  ...appointment.preparationGuidance.map(
                    (instruction) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: LocalizedText(
                        '• $instruction',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              foregroundColor: AppColors.burgundy,
              side: const BorderSide(color: AppColors.burgundy),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const LocalizedText('View Details'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CardAction(
                icon: Icons.event_outlined,
                label: 'Calendar',
                onPressed: onCalendar,
              ),
              _CardAction(
                icon: Icons.edit_calendar_outlined,
                label: 'Reschedule',
                onPressed: onReschedule,
              ),
              _CardAction(
                icon: Icons.directions_outlined,
                label: 'Directions',
                onPressed: onDirections,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status.toLowerCase()) {
    'requested' => 'Pending Confirmation',
    _ => status,
  };

  static Doctor? _doctorFor(String name) {
    for (final doctor in sampleDoctors) {
      if (doctor.name == name) return doctor;
    }
    return null;
  }

  static String _month(DateTime date) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][date.month - 1];

  static String _weekday(DateTime date) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
}

class _DoctorAvatar extends StatelessWidget {
  final Appointment appointment;

  const _DoctorAvatar({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final doctor = AppointmentCard._doctorFor(appointment.doctorName);
    final parts = appointment.doctorName.trim().split(RegExp(r'\s+'));
    final initials = parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (parts.firstOrNull?.isNotEmpty == true
              ? parts.first[0].toUpperCase()
              : '?');
    return CircleAvatar(
      radius: 25,
      backgroundColor: AppColors.blushPink,
      foregroundImage: doctor?.profileImageUrl == null
          ? null
          : NetworkImage(doctor!.profileImageUrl!),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.burgundy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AppointmentInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AppointmentInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.dustyPink, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: LocalizedText(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.burgundy,
      side: const BorderSide(color: AppColors.divider),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class AppointmentSectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AppointmentSectionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryText.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.burgundy, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AppointmentActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 126),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryText.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blushPink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.burgundy, size: 20),
            ),
            const SizedBox(height: 10),
            LocalizedText(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            LocalizedText(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
