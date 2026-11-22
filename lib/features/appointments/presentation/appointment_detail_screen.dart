import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import 'cancellation_confirmation_screen.dart';
import 'doctor_information_screen.dart';
import 'models/appointment_models.dart';
import 'reschedule_request_screen.dart';
import 'widgets/appointment_widgets.dart';
import 'data/appointment_data.dart';

class AppointmentDetailsScreen extends StatelessWidget {
  final Appointment appointment;
  final String patientName;
  final String mobileNumber;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
    this.patientName = '',
    this.mobileNumber = '',
  });

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = appointment.status.toLowerCase();
    final isCompleted = normalizedStatus == 'completed';
    final isCancelled = normalizedStatus == 'cancelled';
    final canChange = !isCompleted && !isCancelled;
    final doctor = _doctorFor(appointment.doctorName);
    final hasAddress = appointment.clinicAddress?.trim().isNotEmpty == true;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const LocalizedText('Appointment details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _HeaderCard(appointment: appointment),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.medical_services_outlined,
            title: 'Doctor information',
            child: Row(
              children: [
                _DoctorAvatar(doctor: doctor, appointment: appointment),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.doctorName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (doctor?.qualifications?.isNotEmpty == true)
                        Text(
                          doctor!.qualifications!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      if (appointment.specialty.isNotEmpty)
                        Text(
                          appointment.specialty,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      Text(
                        appointment.clinic,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.event_note_outlined,
            title: 'Appointment schedule',
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Date',
                  value: _date(context, appointment.date),
                ),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'Time',
                  value: appointment.time,
                ),
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Visit type',
                  value: appointment.appointmentType,
                ),
                _InfoRow(
                  icon: Icons.video_camera_front_outlined,
                  label: 'Consultation mode',
                  value: appointment.consultationMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.location_on_outlined,
            title: 'Clinic information',
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.local_hospital_outlined,
                  label: 'Clinic',
                  value: appointment.clinic,
                ),
                if (appointment.clinicAddress?.isNotEmpty == true)
                  _InfoRow(
                    icon: Icons.pin_drop_outlined,
                    label: 'Address',
                    value: appointment.clinicAddress!,
                  ),
                if (appointment.room?.isNotEmpty == true)
                  _InfoRow(
                    icon: Icons.meeting_room_outlined,
                    label: 'Room',
                    value: appointment.room!,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionButton(
                      icon: Icons.directions_outlined,
                      label: 'Get directions',
                      enabled: hasAddress,
                      onPressed: hasAddress
                          ? () => _showUnavailableMessage(
                              context,
                              'Map integration is not available yet.',
                            )
                          : null,
                    ),
                    _ActionButton(
                      icon: Icons.copy_outlined,
                      label: 'Copy address',
                      enabled: hasAddress,
                      onPressed: hasAddress
                          ? () => _copyAddress(
                              context,
                              appointment.clinicAddress!,
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.checklist_rounded,
            title: 'Preparation guidance',
            tint: _blush,
            child: appointment.preparationGuidance.isEmpty
                ? const LocalizedText(
                    'No preparation guidance has been provided for this visit.',
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: appointment.preparationGuidance
                        .map(
                          (instruction) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: _burgundy,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    instruction,
                                    style: const TextStyle(
                                      color: _primaryText,
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (appointment.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              icon: Icons.help_outline_rounded,
              title: 'Reason for visit',
              child: Text(
                appointment.reason,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (appointment.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              icon: Icons.notes_rounded,
              title: 'Patient notes',
              child: Text(
                appointment.notes,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (canChange) ...[
            _PrimaryAction(
              label: 'Reschedule appointment',
              icon: Icons.edit_calendar_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RescheduleRequestScreen(
                    appointment: appointment,
                    patientName: patientName,
                    mobileNumber: mobileNumber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.event_outlined,
                    label: 'Add to calendar',
                    onPressed: () => _showUnavailableMessage(
                      context,
                      'Calendar integration is not available yet.',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.directions_outlined,
                    label: 'Directions',
                    enabled: hasAddress,
                    onPressed: hasAddress
                        ? () => _showUnavailableMessage(
                            context,
                            'Map integration is not available yet.',
                          )
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CancellationConfirmationScreen(appointment: appointment),
                ),
              ),
              child: const LocalizedText('Cancel appointment'),
            ),
          ],
          if (isCompleted)
            _PrimaryAction(
              label: 'Book another visit',
              icon: Icons.add_circle_outline,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorInformationScreen(
                    patientName: patientName,
                    mobileNumber: mobileNumber,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LocalizedText('Back to appointments'),
          ),
        ],
      ),
    );
  }

  static Doctor? _doctorFor(String name) {
    for (final doctor in sampleDoctors) {
      if (doctor.name == name) return doctor;
    }
    return null;
  }

  static String _date(BuildContext context, DateTime date) {
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

  static void _copyAddress(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    _showUnavailableMessage(context, 'Address copied.');
  }

  static void _showUnavailableMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: LocalizedText(message)));
  }
}

class _HeaderCard extends StatelessWidget {
  final Appointment appointment;

  const _HeaderCard({required this.appointment});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _burgundy,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: _burgundy.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: LocalizedText(
                'Appointment details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            AppointmentStatusBadge(appointment.status),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          appointment.appointmentType,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (appointment.reference.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${localizedText(context, 'Appointment ID')}: ${appointment.reference}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _blush, fontSize: 11),
          ),
        ],
      ],
    ),
  );
}

class _DoctorAvatar extends StatelessWidget {
  final Doctor? doctor;
  final Appointment appointment;

  const _DoctorAvatar({required this.doctor, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final imageUrl = doctor?.profileImageUrl;
    return CircleAvatar(
      radius: 29,
      backgroundColor: _blush,
      foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
      child: imageUrl == null
          ? Text(
              doctor?.initials ?? _initials(appointment.doctorName),
              style: const TextStyle(
                color: _burgundy,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.first.isEmpty ? '?' : parts.first[0].toUpperCase();
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color tint;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.tint = AppColors.white,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _divider),
      boxShadow: [
        BoxShadow(
          color: _primaryText.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _burgundy, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: LocalizedText(
                title,
                style: const TextStyle(
                  color: _burgundy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _dustyPink, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                label,
                style: const TextStyle(color: _secondaryText, fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: enabled ? onPressed : null,
    icon: Icon(icon, size: 17),
    label: LocalizedText(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(
      foregroundColor: _burgundy,
      disabledForegroundColor: _secondaryText.withValues(alpha: 0.55),
      side: BorderSide(color: enabled ? _burgundy : _divider),
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: LocalizedText(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _burgundy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
  );
}

class AppointmentDetailScreen extends AppointmentDetailsScreen {
  const AppointmentDetailScreen({super.key, required super.appointment});
}

class AppointmentInfoScreen extends StatelessWidget {
  final String title;
  final String description;

  const AppointmentInfoScreen({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: Text(title),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    ),
  );
}

const _burgundy = Color(0xFF6B1837);
const _blush = Color(0xFFF8E9EE);
const _dustyPink = Color(0xFFC9879D);
const _background = Color(0xFFFFFBFA);
const _primaryText = Color(0xFF30232A);
const _secondaryText = Color(0xFF806D76);
const _divider = Color(0xFFEADCE2);
