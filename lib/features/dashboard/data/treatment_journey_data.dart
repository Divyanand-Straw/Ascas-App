enum TreatmentMilestoneStatus {
  completed,
  current,
  upcoming,
  awaitingUpdate,
}

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
      .where((milestone) => milestone.status == TreatmentMilestoneStatus.completed)
      .length;

  int get currentCount => milestones
      .where((milestone) => milestone.status == TreatmentMilestoneStatus.current)
      .length;

  int get upcomingCount => milestones
      .where((milestone) => milestone.status == TreatmentMilestoneStatus.upcoming)
      .length;
}

TreatmentPathway pathwayFor(String name, String fallbackStage) {
  if (name == 'IVF Cycle 1' || fallbackStage.contains('Ovarian stimulation')) {
    return ivfCycleOne;
  }
  if (name == 'IUI Treatment') {
    return _placeholderPathway('IUI Treatment', 'Clinic-published stage pending');
  }
  if (name == 'Embryo Transfer') {
    return _placeholderPathway('Embryo Transfer', 'Clinic-published stage pending');
  }
  if (name == 'Two-Week Wait') {
    return _placeholderPathway('Two-Week Wait', 'Clinic-published stage pending');
  }
  if (name == 'Follow-up Care') {
    return _placeholderPathway('Follow-up Care', 'Clinic-published stage pending');
  }
  return _placeholderPathway(name, fallbackStage);
}

final ivfCycleOne = TreatmentPathway(
  name: 'IVF Cycle 1',
  currentStage: 'Ovarian stimulation',
  milestones: [
    const TreatmentMilestone(
      id: 'ivf-1',
      number: 1,
      name: 'Clinic pathway setup',
      status: TreatmentMilestoneStatus.awaitingUpdate,
      description: 'Details will be published by the clinic.',
    ),
    const TreatmentMilestone(
      id: 'ivf-2',
      number: 2,
      name: 'Clinic-confirmed milestone',
      status: TreatmentMilestoneStatus.completed,
      description: 'Clinic-confirmed milestone completed. Date not provided.',
    ),
    const TreatmentMilestone(
      id: 'ivf-3',
      number: 3,
      name: 'Investigations',
      status: TreatmentMilestoneStatus.completed,
      completionDate: '8 April 2025',
      description: 'Clinic-confirmed milestone completed.',
    ),
    const TreatmentMilestone(
      id: 'ivf-4',
      number: 4,
      name: 'Ovarian stimulation',
      status: TreatmentMilestoneStatus.current,
      startDate: '12 April 2025',
      description: 'Current clinic-confirmed milestone.',
      instructions:
          'Follow only the instructions published by your Thaai Seyazhi care team.',
    ),
    const TreatmentMilestone(
      id: 'ivf-5',
      number: 5,
      name: 'Monitoring scans and blood tests',
      status: TreatmentMilestoneStatus.upcoming,
      scheduledDate: '12 May 2025',
      scheduledTime: '10:30 AM',
      description: 'Clinic-confirmed milestone scheduled for a future date.',
      relatedAppointmentId: 'PROTOTYPE-001',
    ),
    const TreatmentMilestone(
      id: 'ivf-6',
      number: 6,
      name: 'Trigger injection',
      status: TreatmentMilestoneStatus.awaitingUpdate,
      description: 'Date not confirmed. Details will be published by the clinic.',
    ),
    const TreatmentMilestone(
      id: 'ivf-7',
      number: 7,
      name: 'Clinic milestone',
      status: TreatmentMilestoneStatus.awaitingUpdate,
      description: 'Details will be published by the clinic.',
    ),
    const TreatmentMilestone(
      id: 'ivf-8',
      number: 8,
      name: 'Clinic milestone',
      status: TreatmentMilestoneStatus.awaitingUpdate,
      description: 'Details will be published by the clinic.',
    ),
    const TreatmentMilestone(
      id: 'ivf-9',
      number: 9,
      name: 'Clinic milestone',
      status: TreatmentMilestoneStatus.awaitingUpdate,
      description: 'Details will be published by the clinic.',
    ),
    const TreatmentMilestone(
      id: 'ivf-10',
      number: 10,
      name: 'Clinic milestone',
      status: TreatmentMilestoneStatus.awaitingUpdate,
      description: 'Details will be published by the clinic.',
    ),
    const TreatmentMilestone(
      id: 'ivf-11',
      number: 11,
      name: 'Clinic milestone',
      status: TreatmentMilestoneStatus.awaitingUpdate,
      description: 'Details will be published by the clinic.',
    ),
  ],
);

TreatmentPathway _placeholderPathway(String name, String currentStage) {
  return TreatmentPathway(
    name: name,
    currentStage: currentStage,
    milestones: List.generate(
      11,
      (index) => TreatmentMilestone(
        id: '${name.toLowerCase().replaceAll(' ', '-')}-${index + 1}',
        number: index + 1,
        name: 'Clinic milestone ${index + 1}',
        status: TreatmentMilestoneStatus.awaitingUpdate,
        description: 'Details will be published by the clinic.',
      ),
    ),
  );
}
