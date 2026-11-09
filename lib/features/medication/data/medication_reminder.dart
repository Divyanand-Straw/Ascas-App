enum MedicationReminderStatus { upcoming, due, completed, missed }

class MedicationReminder {
  final String id;
  final String name;
  final int hour;
  final int minute;
  final String dosage;
  final String instructions;
  final String frequency;
  final String? prescribingDoctor;
  final String? startDate;
  final String? endDate;

  const MedicationReminder({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.dosage,
    required this.instructions,
    required this.frequency,
    this.prescribingDoctor,
    this.startDate,
    this.endDate,
  });

  DateTime scheduledAtOn(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  DateTime nextScheduledAt(DateTime now) {
    final today = scheduledAtOn(now);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }
}

const sampleMedicationReminders = <MedicationReminder>[
  MedicationReminder(
    id: 'sample-morning',
    name: 'Folic acid · sample only',
    hour: 8,
    minute: 0,
    dosage: 'Not specified — sample only, not a prescribed dose.',
    instructions: 'No clinical instructions are provided in this demo.',
    frequency: 'Sample schedule · once daily',
    prescribingDoctor: 'Sample clinician · demo only',
  ),
  MedicationReminder(
    id: 'sample-afternoon',
    name: 'Vitamin D · sample only',
    hour: 13,
    minute: 0,
    dosage: 'Not specified — sample only, not a prescribed dose.',
    instructions: 'No clinical instructions are provided in this demo.',
    frequency: 'Sample schedule · once daily',
    prescribingDoctor: 'Sample clinician · demo only',
  ),
  MedicationReminder(
    id: 'sample-evening',
    name: 'Progesterone · sample only',
    hour: 20,
    minute: 0,
    dosage: 'Not specified — sample only, not a prescribed dose.',
    instructions: 'No clinical instructions are provided in this demo.',
    frequency: 'Sample schedule · once daily',
    prescribingDoctor: 'Sample clinician · demo only',
  ),
];

MedicationReminderStatus medicationReminderStatus({
  required MedicationReminder reminder,
  required DateTime now,
  DateTime? takenAt,
}) {
  if (takenAt != null &&
      takenAt.year == now.year &&
      takenAt.month == now.month &&
      takenAt.day == now.day) {
    return MedicationReminderStatus.completed;
  }

  final scheduledAt = reminder.scheduledAtOn(now);
  if (now.isBefore(scheduledAt)) return MedicationReminderStatus.upcoming;
  if (now.difference(scheduledAt) <= const Duration(hours: 1)) {
    return MedicationReminderStatus.due;
  }
  return MedicationReminderStatus.missed;
}

MedicationReminder nextMedicationReminder(DateTime now) {
  return sampleMedicationReminders.reduce(
    (nearest, reminder) =>
        reminder.nextScheduledAt(now).isBefore(nearest.nextScheduledAt(now))
        ? reminder
        : nearest,
  );
}
