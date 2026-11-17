enum TreatmentMilestoneStatus {
  completed,
  current,
  upcoming,
  rescheduled,
  cancelled,
  awaitingUpdate,
}

class TreatmentMilestone {
  final String id;
  final int number;
  final String name;
  final TreatmentMilestoneStatus status;
  final String? startDate;
  final String? endDate;
  final String? completionDate;
  final String? scheduledDate;
  final String? scheduledTime;
  final String description;
  final String? whatHappens;
  final String? treatmentInformation;
  final String? instructions;
  final String? lastUpdated;
  final bool optional;
  final bool applicable;
  final String? relatedAppointmentId;
  final List<HealthRecord> relatedHealthRecords;
  final ClinicalStageResults? clinicalResults;

  const TreatmentMilestone({
    required this.id,
    required this.number,
    required this.name,
    required this.status,
    this.startDate,
    this.endDate,
    this.completionDate,
    this.scheduledDate,
    this.scheduledTime,
    required this.description,
    this.whatHappens,
    this.treatmentInformation,
    this.instructions,
    this.lastUpdated,
    this.optional = false,
    this.applicable = true,
    this.relatedAppointmentId,
    this.relatedHealthRecords = const [],
    this.clinicalResults,
  });

  String? get displayDate {
    if (completionDate != null) return completionDate;
    final date = scheduledDate ?? startDate;
    if (date != null && endDate != null) return '$date – $endDate';
    return date;
  }
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

class ClinicalStageResults {
  final String? cycleDay;
  final String? scanDate;
  final String? rightOvary;
  final String? leftOvary;
  final String? follicleCount;
  final List<String> follicleMeasurements;
  final String? endometrialThickness;
  final String? endometrialPattern;
  final String? assessment;
  final String? nextAppointmentDate;
  final String? nextAppointmentTime;
  final String? eggsRetrieved;
  final String? eggsInseminated;
  final String? fertilisationResult;
  final String? embryoDevelopment;
  final String? embryoGrade;
  final String? embryosTransferred;
  final String? procedureDate;
  final String? spermPreparation;
  final String? testDate;
  final String? testResult;
  final String? doctorNote;
  final String? patientInstructions;

  const ClinicalStageResults({
    this.cycleDay,
    this.scanDate,
    this.rightOvary,
    this.leftOvary,
    this.follicleCount,
    this.follicleMeasurements = const [],
    this.endometrialThickness,
    this.endometrialPattern,
    this.assessment,
    this.nextAppointmentDate,
    this.nextAppointmentTime,
    this.eggsRetrieved,
    this.eggsInseminated,
    this.fertilisationResult,
    this.embryoDevelopment,
    this.embryoGrade,
    this.embryosTransferred,
    this.procedureDate,
    this.spermPreparation,
    this.testDate,
    this.testResult,
    this.doctorNote,
    this.patientInstructions,
  });
}

class TreatmentPathway {
  final String name;
  final String currentStage;
  final List<TreatmentMilestone> milestones;
  final bool isDevelopmentSample;

  const TreatmentPathway({
    required this.name,
    required this.currentStage,
    required this.milestones,
    this.isDevelopmentSample = false,
  });

  List<TreatmentMilestone> get applicableMilestones =>
      milestones.where((milestone) => milestone.applicable).toList();

  int get completedCount => applicableMilestones
      .where(
        (milestone) => milestone.status == TreatmentMilestoneStatus.completed,
      )
      .length;

  int get currentCount => applicableMilestones
      .where(
        (milestone) => milestone.status == TreatmentMilestoneStatus.current,
      )
      .length;

  TreatmentMilestone? get currentMilestone {
    for (final milestone in applicableMilestones) {
      if (milestone.status == TreatmentMilestoneStatus.current) {
        return milestone;
      }
    }
    return null;
  }

  TreatmentMilestone? get nextMilestone {
    for (final milestone in applicableMilestones) {
      if (milestone.status == TreatmentMilestoneStatus.upcoming ||
          milestone.status == TreatmentMilestoneStatus.rescheduled) {
        return milestone;
      }
    }
    return null;
  }
}

const _ivfStageDefinitions = [
  (
    'initial-consultation',
    'Initial consultation & assessment',
    'Medical history, investigations, specialist assessment and treatment plan.',
    false,
  ),
  (
    'baseline-scan',
    'Baseline scan & blood tests',
    'Initial ultrasound and blood tests as requested by the clinic.',
    false,
  ),
  (
    'cycle-preparation',
    'Cycle preparation / suppression',
    'Medication, dates and clinic instructions for preparing the treatment cycle.',
    true,
  ),
  (
    'ovarian-stimulation',
    'Ovarian stimulation',
    'Treatment dates, prescribed medication, reminders and progress updates.',
    false,
  ),
  (
    'follicular-monitoring',
    'Follicular monitoring',
    'Scan dates, follicle updates, results and the next scan when provided.',
    false,
  ),
  (
    'trigger-injection',
    'Trigger injection, if prescribed',
    'Prescribed medication, scheduled date/time and clinic instructions.',
    true,
  ),
  (
    'egg-retrieval',
    'Egg retrieval',
    'Procedure date, status, eggs retrieved when reported, preparation and recovery.',
    false,
  ),
  (
    'sperm-collection',
    'Sperm collection & preparation',
    'Collection date, preparation status and laboratory updates.',
    false,
  ),
  (
    'fertilisation',
    'Fertilisation',
    'Eggs inseminated, fertilisation date and clinic-provided results.',
    false,
  ),
  (
    'embryo-development',
    'Embryo development',
    'Day 1, 2, 3, 5 or 6 updates, embryo information and reports.',
    false,
  ),
  (
    'embryo-assessment',
    'Embryo assessment & selection',
    'Assessment date, clinic-provided information and selection updates.',
    false,
  ),
  (
    'embryo-transfer',
    'Embryo transfer, if applicable',
    'Transfer date, status, procedure details and follow-up instructions.',
    true,
  ),
  (
    'luteal-support',
    'Luteal phase support, if prescribed',
    'Medication, schedule, dates and clinic instructions.',
    true,
  ),
  (
    'pregnancy-test',
    'Pregnancy test',
    'Scheduled beta-hCG test, laboratory report and result when available.',
    false,
  ),
  (
    'confirmation-scan',
    'Pregnancy confirmation scan, if positive',
    'Scan date, report and follow-up appointment when applicable.',
    true,
  ),
];

const _iuiStageDefinitions = [
  (
    'iui-initial-consultation',
    'Initial consultation',
    'A fertility specialist reviews medical history and investigations to assess whether IUI is suitable.',
    'The specialist reviews fertility history, relevant investigations and the proposed IUI treatment plan.',
    false,
  ),
  (
    'iui-fertility-tests',
    'Pre-treatment fertility tests',
    'Relevant investigations assess reproductive health, including tube assessment and sperm evaluation where required.',
    'Your clinic will record investigation names, dates, reports and assessment status when provided.',
    false,
  ),
  (
    'iui-cycle-day-one',
    'Menstrual cycle – Day 1',
    'The first day of menstruation is reported to the clinic so the IUI cycle can be scheduled.',
    'The clinic records the cycle start and confirms planned monitoring dates.',
    false,
  ),
  (
    'iui-ovulation-induction',
    'Ovulation induction, if required',
    'Some patients receive prescribed medication to support follicle development; others have a natural-cycle IUI.',
    'Only clinic-prescribed medication, schedule and monitoring updates will be shown here.',
    true,
  ),
  (
    'iui-follicular-monitoring',
    'Follicular monitoring',
    'Ultrasound scans and sometimes blood tests monitor follicle growth and ovulation timing.',
    'Scan dates, follicle updates, blood results and the next scan are recorded when shared by the clinic.',
    false,
  ),
  (
    'iui-ovulation-trigger',
    'Ovulation detection / trigger injection',
    'The clinic identifies ovulation timing through monitoring or prescribes a trigger injection when appropriate.',
    'A trigger is not mandatory for every patient. The clinic supplies any medication, date, time and instructions.',
    true,
  ),
  (
    'iui-sperm-collection',
    'Sperm collection & preparation',
    'A sample is collected and processed in the laboratory to prepare suitable motile sperm for insemination.',
    'Collection date, laboratory preparation status and shared sample information appear when available.',
    false,
  ),
  (
    'iui-insemination',
    'Insemination (IUI procedure)',
    'Prepared sperm is placed directly into the uterus through a thin catheter, timed around ovulation.',
    'The clinic records the procedure date, status, clinician, preparation and post-procedure instructions.',
    false,
  ),
  (
    'iui-luteal-support',
    'Luteal phase support, if prescribed',
    'The clinic may prescribe support medication following insemination.',
    'Only clinic-prescribed medication, times, dates, reminders and instructions will be shown.',
    true,
  ),
  (
    'iui-two-week-wait',
    'Two-week wait',
    'The waiting period continues until the clinic-scheduled pregnancy test.',
    'The waiting period, next appointment, clinic instructions, reminders and test date appear when provided.',
    false,
  ),
  (
    'iui-pregnancy-test',
    'Pregnancy test',
    'A clinic-scheduled urine or blood test checks whether pregnancy has occurred.',
    'The test date, type, laboratory report and result are shown only when supplied by the clinic.',
    false,
  ),
  (
    'iui-pregnancy-follow-up',
    'Pregnancy follow-up, if positive',
    'The clinic arranges follow-up assessment and ultrasound at the appropriate time when applicable.',
    'Follow-up dates, ultrasound appointments, reports and doctor updates appear when available.',
    true,
  ),
];

List<String> workflowStagesFor(String treatmentName) {
  final treatment = treatmentName.toLowerCase();
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
  if (treatment.contains('embryo transfer') || treatment.contains('two-week')) {
    return const ['Embryo transfer', 'Post-transfer care and follow-up'];
  }
  if (treatment.contains('follow-up') || treatment.contains('recovery')) {
    return const ['Clinic-directed follow-up care'];
  }
  return const [];
}

TreatmentPathway pathwayFor(
  String name, {
  Set<String> excludedOptionalStageIds = const {},
}) {
  final treatment = name.toLowerCase();
  if (treatment.contains('iui')) {
    return TreatmentPathway(
      name: name,
      currentStage: 'Clinic update pending',
      isDevelopmentSample: true,
      milestones: [
        for (var index = 0; index < _iuiStageDefinitions.length; index++)
          TreatmentMilestone(
            id: _iuiStageDefinitions[index].$1,
            number: index + 1,
            name: _iuiStageDefinitions[index].$2,
            optional: _iuiStageDefinitions[index].$5,
            applicable: !excludedOptionalStageIds.contains(
              _iuiStageDefinitions[index].$1,
            ),
            status: TreatmentMilestoneStatus.awaitingUpdate,
            description: _iuiStageDefinitions[index].$3,
            whatHappens: _iuiStageDefinitions[index].$4,
          ),
      ],
    );
  }
  if (!treatment.contains('ivf')) {
    return const TreatmentPathway(
      name: 'Treatment',
      currentStage: 'Clinic update pending',
      milestones: [],
    );
  }

  return TreatmentPathway(
    name: name,
    currentStage: 'Clinic update pending',
    isDevelopmentSample: true,
    milestones: [
      for (var index = 0; index < _ivfStageDefinitions.length; index++)
        TreatmentMilestone(
          id: _ivfStageDefinitions[index].$1,
          number: index + 1,
          name: _ivfStageDefinitions[index].$2,
          optional: _ivfStageDefinitions[index].$4,
          applicable: !excludedOptionalStageIds.contains(
            _ivfStageDefinitions[index].$1,
          ),
          status: TreatmentMilestoneStatus.awaitingUpdate,
          description: _ivfStageDefinitions[index].$3,
          whatHappens: 'Your clinic will provide the steps, dates and results for this stage.',
        ),
    ],
  );
}
