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

List<String> workflowStagesFor(String treatmentName) {
  final treatment = treatmentName.toLowerCase();
  if (treatment.contains('icsi')) {
    return const [
      'Treatment planning',
      'Ovarian stimulation',
      'Clinic monitoring',
      'Egg retrieval',
      'ICSI fertilisation and embryo culture',
      'Embryo transfer or freezing',
      'Clinic-directed follow-up',
    ];
  }
  if (treatment.contains('iui')) {
    return const [
      'Treatment planning',
      'Cycle monitoring as directed by your clinic',
      'Insemination',
      'Clinic-directed follow-up',
    ];
  }
  if (treatment.contains('fet') || treatment.contains('frozen')) {
    return const [
      'Treatment planning',
      'Cycle preparation as directed by your clinic',
      'Clinic monitoring',
      'Frozen embryo transfer',
      'Clinic-directed follow-up',
    ];
  }
  if (treatment.contains('ivf')) {
    return const [
      'Treatment planning',
      'Ovarian stimulation',
      'Clinic monitoring',
      'Egg retrieval',
      'Fertilisation and embryo culture',
      'Embryo transfer or freezing',
      'Clinic-directed follow-up',
    ];
  }
  if (treatment.toLowerCase().contains('embryo transfer') ||
      treatment.contains('two-week')) {
    return const ['Embryo transfer', 'Post-transfer care and follow-up'];
  }
  if (treatment.contains('follow-up') || treatment.contains('recovery')) {
    return const ['Clinic-directed follow-up care'];
  }
  return const [];
}

TreatmentPathway pathwayFor(String name) => TreatmentPathway(
  name: name,
  currentStage: 'Clinic update pending',
  milestones: const [],
);
