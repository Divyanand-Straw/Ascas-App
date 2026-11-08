enum TreatmentMilestoneStatus { completed, current, upcoming, awaitingUpdate }

class TreatmentMilestone {
  final String id;
  final int number;
  final String name;
  final TreatmentMilestoneStatus status;
  final String? startDate;
  final String? completionDate;
  final String? scheduledDate;
  final String? scheduledTime;
  final String description;
  final String? instructions;
  final String? relatedAppointmentId;
  final List<HealthRecord> relatedHealthRecords;

  const TreatmentMilestone({
    required this.id,
    required this.number,
    required this.name,
    required this.status,
    this.startDate,
    this.completionDate,
    this.scheduledDate,
    this.scheduledTime,
    required this.description,
    this.instructions,
    this.relatedAppointmentId,
    this.relatedHealthRecords = const [],
  });
}

class HealthRecord {
  final String documentName;
  final String documentType;
  final String uploadDate;
  final String relatedStage;

  const HealthRecord({
    required this.documentName,
    required this.documentType,
    required this.uploadDate,
    required this.relatedStage,
  });
}

class TreatmentPathway {
  final String name;
  final String currentStage;
  final List<TreatmentMilestone> milestones;

  const TreatmentPathway({
    required this.name,
    required this.currentStage,
    required this.milestones,
  });

  int get completedCount => milestones
      .where(
        (milestone) => milestone.status == TreatmentMilestoneStatus.completed,
      )
      .length;

  int get currentCount => milestones
      .where(
        (milestone) => milestone.status == TreatmentMilestoneStatus.current,
      )
      .length;

  int get upcomingCount => milestones
      .where(
        (milestone) => milestone.status == TreatmentMilestoneStatus.upcoming,
      )
      .length;
}

TreatmentPathway pathwayFor(String name) => TreatmentPathway(
  name: name,
  currentStage: 'Clinic update pending',
  milestones: const [],
);
