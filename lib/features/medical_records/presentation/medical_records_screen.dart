import 'package:flutter/material.dart';

import '../../../core/formatters/currency_formatter.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../communication/presentation/communication_screen.dart';
import '../../medication/presentation/medication_screen.dart';

enum RecordCategory {
  patientDetails,
  medicalHistory,
  diagnosis,
  consultation,
  treatment,
  allergies,
  prescriptions,
  clinicalNotes,
  vitalSigns,
}

enum ReportCategory {
  bloodTest,
  hormoneTest,
  ultrasound,
  scan,
  fertilityInvestigation,
  otherLaboratory,
}

enum RecordSort { latest, oldest }

class MedicalRecord {
  final String title;
  final RecordCategory category;
  final String date;
  final String source;
  final String description;

  const MedicalRecord({
    required this.title,
    required this.category,
    required this.date,
    required this.source,
    required this.description,
  });
}

class PatientReport {
  final String name;
  final ReportCategory category;
  final String date;
  final String issuedBy;
  final String status;

  const PatientReport({
    required this.name,
    required this.category,
    required this.date,
    required this.issuedBy,
    required this.status,
  });
}

class DischargeSummary {
  final String admissionId;
  final String admissionDate;
  final String dischargeDate;
  final String doctor;
  final String department;
  final String status;

  const DischargeSummary({
    required this.admissionId,
    required this.admissionDate,
    required this.dischargeDate,
    required this.doctor,
    required this.department,
    required this.status,
  });
}

const _demoRecordDescription =
    'Demo preview only. Clinic records will appear here when securely published.';

const _demoRecords = <MedicalRecord>[
  MedicalRecord(
    title: 'Demo patient details',
    category: RecordCategory.patientDetails,
    date: 'Demo record',
    source: 'Patient profile',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo medical history',
    category: RecordCategory.medicalHistory,
    date: 'Demo record',
    source: 'Medical records',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo diagnosis record',
    category: RecordCategory.diagnosis,
    date: 'Demo record',
    source: 'Clinical department',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo doctor consultation',
    category: RecordCategory.consultation,
    date: 'Demo record',
    source: 'Consultation department',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo treatment history',
    category: RecordCategory.treatment,
    date: 'Demo record',
    source: 'Treatment department',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo allergies record',
    category: RecordCategory.allergies,
    date: 'Demo record',
    source: 'Patient profile',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo prescription',
    category: RecordCategory.prescriptions,
    date: 'Demo record',
    source: 'Pharmacy department',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo clinical note',
    category: RecordCategory.clinicalNotes,
    date: 'Demo record',
    source: 'Clinical department',
    description: _demoRecordDescription,
  ),
  MedicalRecord(
    title: 'Demo vital signs',
    category: RecordCategory.vitalSigns,
    date: 'Demo record',
    source: 'Nursing department',
    description: _demoRecordDescription,
  ),
];

const _demoReports = <PatientReport>[
  PatientReport(
    name: 'Demo blood test report',
    category: ReportCategory.bloodTest,
    date: 'Demo report',
    issuedBy: 'Laboratory',
    status: 'Demo preview',
  ),
  PatientReport(
    name: 'Demo hormone test report',
    category: ReportCategory.hormoneTest,
    date: 'Demo report',
    issuedBy: 'Laboratory',
    status: 'Demo preview',
  ),
  PatientReport(
    name: 'Demo ultrasound report',
    category: ReportCategory.ultrasound,
    date: 'Demo report',
    issuedBy: 'Imaging department',
    status: 'Demo preview',
  ),
  PatientReport(
    name: 'Demo scan report',
    category: ReportCategory.scan,
    date: 'Demo report',
    issuedBy: 'Imaging department',
    status: 'Demo preview',
  ),
  PatientReport(
    name: 'Demo fertility investigation',
    category: ReportCategory.fertilityInvestigation,
    date: 'Demo report',
    issuedBy: 'Fertility department',
    status: 'Demo preview',
  ),
  PatientReport(
    name: 'Demo laboratory report',
    category: ReportCategory.otherLaboratory,
    date: 'Demo report',
    issuedBy: 'Laboratory',
    status: 'Demo preview',
  ),
];

const _demoDischargeSummary = DischargeSummary(
  admissionId: 'Demo admission ID',
  admissionDate: 'Demo date',
  dischargeDate: 'Demo date',
  doctor: 'Demo treating doctor',
  department: 'Demo department',
  status: 'Demo preview',
);

class MedicalRecordsScreen extends StatelessWidget {
  final String patientName;
  final bool isLinkedPartner;
  final Map<String, bool> partnerPermissions;

  const MedicalRecordsScreen({
    super.key,
    this.patientName = '',
    this.isLinkedPartner = false,
    this.partnerPermissions = const {},
  });

  bool _can(String category) =>
      !isLinkedPartner || partnerPermissions[category] == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const LocalizedText('Patient Records'),
        titleSpacing: 20,
        actions: [
          IconButton(
            tooltip: localizedText(context, 'Support'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommunicationScreen()),
            ),
            icon: const Icon(Icons.support_agent_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          const LocalizedText(
            'Access your medical information and billing records.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_can('Patient profile information'))
            _PatientSummary(patientName: patientName),
          const SizedBox(height: 22),
          const _SectionLabel('RECORD CATEGORIES'),
          const SizedBox(height: 9),
          if (!isLinkedPartner)
            _CategoryCard(
              icon: Icons.folder_shared_outlined,
              title: 'EMR',
              description: 'View your electronic medical records.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmrScreen()),
              ),
            ),
          if (_can('Medical Reports'))
            _CategoryCard(
              icon: Icons.assessment_outlined,
              title: 'Reports',
              description: 'Review laboratory and imaging reports.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
          if (_can('Discharge Summary'))
            _CategoryCard(
              icon: Icons.description_outlined,
              title: 'Discharge Summary',
              description: 'Access your discharge documentation.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DischargeSummaryScreen(),
                ),
              ),
            ),
          if (isLinkedPartner &&
              (_can('Prescriptions') || _can('Medication schedules')))
            _CategoryCard(
              icon: Icons.medication_outlined,
              title: 'Medication schedules & prescriptions',
              description: 'View shared medication information.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicationScreen(
                    isLinkedPartner: isLinkedPartner,
                    canViewMedicationSchedule: _can('Medication schedules'),
                    canViewPrescriptions: _can('Prescriptions'),
                  ),
                ),
              ),
            ),
          if (_can('Bills and Payments'))
            _CategoryCard(
              icon: Icons.receipt_long_outlined,
              title: 'Bills & Payments',
              description: 'Review your billing history and payment status.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillsPaymentsScreen()),
              ),
            ),
          if (_can('IP Billing'))
            _CategoryCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'IP Billing',
              description: 'View inpatient admission billing details.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IpBillingScreen()),
              ),
            ),
        ],
      ),
    );
  }
}

class EmrScreen extends StatefulWidget {
  const EmrScreen({super.key});

  @override
  State<EmrScreen> createState() => _EmrScreenState();
}

class _EmrScreenState extends State<EmrScreen> {
  String _query = '';
  RecordCategory? _filter;
  RecordSort _sort = RecordSort.latest;

  @override
  Widget build(BuildContext context) {
    final records = _demoRecords.where((record) {
      final query = _query.trim().toLowerCase();
      return (query.isEmpty ||
              record.title.toLowerCase().contains(query) ||
              record.source.toLowerCase().contains(query)) &&
          (_filter == null || record.category == _filter);
    }).toList();
    final orderedRecords = _sort == RecordSort.latest
        ? records
        : records.reversed.toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const LocalizedText('EMR')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          const LocalizedText(
            'Electronic Medical Records',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 5),
          const LocalizedText(
            'Review records securely published by your clinic.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          _SearchField(
            hint: 'Search records',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          _FilterRow(
            filterLabel: 'Record category',
            filterValue: _filter == null
                ? 'All categories'
                : _recordCategoryLabel(_filter!),
            sortValue: _sort == RecordSort.latest
                ? 'Latest first'
                : 'Oldest first',
            onFilter: () => _showRecordFilters(context),
            onSort: () => setState(
              () => _sort = _sort == RecordSort.latest
                  ? RecordSort.oldest
                  : RecordSort.latest,
            ),
          ),
          const SizedBox(height: 20),
          if (records.isEmpty)
            const _EmptyState(
              title: 'No matching records',
              description: 'Try another search or category.',
            )
          else
            ...orderedRecords.map(
              (record) => _RecordCard(
                record: record,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordDetailScreen(record: record),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showRecordFilters(BuildContext context) async {
    final selected = await showModalBottomSheet<RecordCategory?>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (context) => _ChoiceSheet<RecordCategory?>(
        title: 'Filter records',
        selected: _filter,
        values: [null, ...RecordCategory.values],
        label: (value) =>
            value == null ? 'All categories' : _recordCategoryLabel(value),
      ),
    );
    if (mounted) setState(() => _filter = selected);
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _query = '';
  ReportCategory? _filter;
  RecordSort _sort = RecordSort.latest;

  @override
  Widget build(BuildContext context) {
    final reports = _demoReports.where((report) {
      final query = _query.trim().toLowerCase();
      return (query.isEmpty ||
              report.name.toLowerCase().contains(query) ||
              report.issuedBy.toLowerCase().contains(query)) &&
          (_filter == null || report.category == _filter);
    }).toList();
    final orderedReports = _sort == RecordSort.latest
        ? reports
        : reports.reversed.toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const LocalizedText('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          const LocalizedText(
            'Laboratory and imaging reports',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 5),
          const LocalizedText(
            'Reports are shown only when published by your clinic.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          _SearchField(
            hint: 'Search reports',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          _FilterRow(
            filterLabel: 'Report category',
            filterValue: _filter == null
                ? 'All categories'
                : _reportCategoryLabel(_filter!),
            sortValue: _sort == RecordSort.latest
                ? 'Latest first'
                : 'Oldest first',
            onFilter: () => _showReportFilters(context),
            onSort: () => setState(
              () => _sort = _sort == RecordSort.latest
                  ? RecordSort.oldest
                  : RecordSort.latest,
            ),
          ),
          const SizedBox(height: 20),
          if (reports.isEmpty)
            const _EmptyState(
              title: 'No matching reports',
              description: 'Try another search or category.',
            )
          else
            ...orderedReports.map(
              (report) => _ReportCard(
                report: report,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportDetailScreen(report: report),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showReportFilters(BuildContext context) async {
    final selected = await showModalBottomSheet<ReportCategory?>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (context) => _ChoiceSheet<ReportCategory?>(
        title: 'Filter reports',
        selected: _filter,
        values: [null, ...ReportCategory.values],
        label: (value) =>
            value == null ? 'All categories' : _reportCategoryLabel(value),
      ),
    );
    if (mounted) setState(() => _filter = selected);
  }
}

class DischargeSummaryScreen extends StatelessWidget {
  const DischargeSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const LocalizedText('Discharge Summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          const LocalizedText(
            'Your discharge documentation',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 5),
          const LocalizedText(
            'Summaries appear here when securely published by your clinic.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 18),
          _DischargeCard(
            summary: _demoDischargeSummary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DischargeSummaryDetailScreen(
                  summary: _demoDischargeSummary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecordDetailScreen extends StatelessWidget {
  final MedicalRecord record;

  const RecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) => _DocumentScaffold(
    title: record.title,
    children: [
      _DetailHeader(
        icon: _recordIcon(record.category),
        title: record.title,
        subtitle: _recordCategoryLabel(record.category),
      ),
      _DetailSection(
        title: 'Record information',
        rows: {
          'Category': _recordCategoryLabel(record.category),
          'Date': record.date,
          'Doctor / department': record.source,
        },
      ),
      _DetailSection(
        title: 'Description',
        rows: {'Record status': record.description},
      ),
    ],
  );
}

class ReportDetailScreen extends StatelessWidget {
  final PatientReport report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) => _DocumentScaffold(
    title: report.name,
    children: [
      _DetailHeader(
        icon: _reportIcon(report.category),
        title: report.name,
        subtitle: _reportCategoryLabel(report.category),
      ),
      _DetailSection(
        title: 'Report information',
        rows: {
          'Category': _reportCategoryLabel(report.category),
          'Report date': report.date,
          'Issued by': report.issuedBy,
          'Status': report.status,
        },
      ),
      const _NoticeBox(
        text: 'This is a clearly labelled demo preview. No medical result is shown because no clinic report file is available.',
      ),
    ],
  );
}

class DischargeSummaryDetailScreen extends StatelessWidget {
  final DischargeSummary summary;

  const DischargeSummaryDetailScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) => _DocumentScaffold(
    title: 'Discharge Summary',
    children: [
      const _NoticeBox(
        text: 'Demo preview only. Clinic-issued discharge details will appear here when available.',
      ),
      _DetailSection(
        title: 'Patient information',
        rows: {
          'Patient record': 'Authenticated patient',
          'Admission ID': summary.admissionId,
        },
      ),
      _DetailSection(
        title: 'Admission details',
        rows: {
          'Admission date': summary.admissionDate,
          'Discharge date': summary.dischargeDate,
          'Department': summary.department,
          'Status': summary.status,
        },
      ),
      _DetailSection(
        title: 'Diagnosis',
        rows: {'Details': 'Not available in demo preview.'},
      ),
      _DetailSection(
        title: 'Treatment summary',
        rows: {'Details': 'Not available in demo preview.'},
      ),
      _DetailSection(
        title: 'Procedures performed',
        rows: {'Details': 'Not available in demo preview.'},
      ),
      _DetailSection(
        title: 'Discharge instructions',
        rows: {'Details': 'Not available in demo preview.'},
      ),
      _DetailSection(
        title: 'Follow-up details',
        rows: {'Details': 'Not available in demo preview.'},
      ),
      _DetailSection(
        title: 'Doctor information',
        rows: {'Treating doctor': summary.doctor},
      ),
    ],
  );
}

class _PatientSummary extends StatelessWidget {
  final String patientName;

  const _PatientSummary({required this.patientName});

  @override
  Widget build(BuildContext context) {
    final name = patientName.isEmpty ? 'Authenticated patient' : patientName;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.blushPink,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.white,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.burgundy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalizedText(
                  'Patient information',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: AppTextStyles.headingSmall),
                const SizedBox(height: 2),
                const LocalizedText(
                  'Your private records space',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 1,
    shadowColor: AppColors.primaryText.withValues(alpha: 0.06),
    color: AppColors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.divider),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.blushPink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.burgundy),
      ),
      title: LocalizedText(
        title,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: LocalizedText(description, style: AppTextStyles.bodySmall),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.secondaryText,
      ),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  final MedicalRecord record;
  final VoidCallback onTap;

  const _RecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBox(icon: _recordIcon(record.category)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    record.title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    '${_recordCategoryLabel(record.category)} · ${record.date}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LocalizedText(record.description, style: AppTextStyles.bodySmall),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onTap,
            child: const LocalizedText('View details'),
          ),
        ),
      ],
    ),
  );
}

class _ReportCard extends StatelessWidget {
  final PatientReport report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBox(icon: _reportIcon(report.category)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    report.name,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    '${_reportCategoryLabel(report.category)} · ${report.date}\n${report.issuedBy} · ${report.status}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onTap,
            child: const LocalizedText('View report'),
          ),
        ),
      ],
    ),
  );
}

class _DischargeCard extends StatelessWidget {
  final DischargeSummary summary;
  final VoidCallback onTap;

  const _DischargeCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _IconBox(icon: Icons.description_outlined),
            const SizedBox(
              width: 180,
              child: LocalizedText(
                'Demo discharge summary',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusBadge(summary.status),
          ],
        ),
        const SizedBox(height: 14),
        LocalizedText(
          'Admission: ${summary.admissionId}',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 4),
        LocalizedText(
          'Admission ${summary.admissionDate} · Discharge ${summary.dischargeDate}',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onTap,
            child: const LocalizedText('View summary'),
          ),
        ),
      ],
    ),
  );
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const _SurfaceCard({
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Material(
      color: AppColors.white,
      elevation: 1,
      shadowColor: AppColors.primaryText.withValues(alpha: 0.07),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(15), child: child),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const _SearchField({
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: localizedText(context, hint),
      prefixIcon: const Icon(Icons.search_rounded),
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
    ),
  );
}

class _FilterRow extends StatelessWidget {
  final String filterLabel;
  final String filterValue;
  final String sortValue;
  final VoidCallback onFilter;
  final VoidCallback onSort;

  const _FilterRow({
    required this.filterLabel,
    required this.filterValue,
    required this.sortValue,
    required this.onFilter,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: onFilter,
        icon: const Icon(Icons.filter_list_rounded, size: 18),
        label: LocalizedText('$filterLabel: $filterValue'),
      ),
      OutlinedButton.icon(
        onPressed: onSort,
        icon: const Icon(Icons.swap_vert_rounded, size: 18),
        label: LocalizedText(sortValue),
      ),
    ],
  );
}

class _ChoiceSheet<T> extends StatelessWidget {
  final String title;
  final T selected;
  final List<T> values;
  final String Function(T value) label;

  const _ChoiceSheet({
    required this.title,
    required this.selected,
    required this.values,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        LocalizedText(title, style: AppTextStyles.headingSmall),
        const SizedBox(height: 8),
        ...values.map(
          (value) => ListTile(
            title: LocalizedText(label(value)),
            trailing: value == selected
                ? const Icon(Icons.check_rounded, color: AppColors.burgundy)
                : null,
            onTap: () => Navigator.pop(context, value),
          ),
        ),
      ],
    ),
  );
}

class _DocumentScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DocumentScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: LocalizedText(title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: children,
    ),
  );
}

class _DetailHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DetailHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      children: [
        _IconBox(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(title, style: AppTextStyles.headingSmall),
              const SizedBox(height: 3),
              LocalizedText(subtitle, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _DetailSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(title, style: AppTextStyles.headingSmall),
        const SizedBox(height: 10),
        ...rows.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: LocalizedText(
                    entry.key,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: LocalizedText(
                    entry.value,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoticeBox extends StatelessWidget {
  final String text;

  const _NoticeBox({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.blushPink,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.burgundy),
        const SizedBox(width: 10),
        Expanded(child: LocalizedText(text, style: AppTextStyles.bodySmall)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyState({
    this.icon = Icons.folder_open_outlined,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      children: [
        Icon(icon, color: AppColors.dustyPink, size: 44),
        const SizedBox(height: 10),
        LocalizedText(title, style: AppTextStyles.headingSmall),
        const SizedBox(height: 5),
        LocalizedText(
          description,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => LocalizedText(
    text,
    style: const TextStyle(
      color: AppColors.burgundy,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: AppColors.blushPink,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: AppColors.burgundy),
  );
}

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: LocalizedText(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.warning,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

enum BillStatus { paid, partiallyPaid, pending }

enum BillCategory { consultation, laboratory, pharmacy, package, other }

class BillItem {
  final String description;
  final int quantity;
  final double unitPrice;

  const BillItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get amount => quantity * unitPrice;
}

class PatientBill {
  final String id;
  final String date;
  final String description;
  final BillCategory category;
  final List<BillItem> items;
  final double additionalCharges;
  final double discount;
  final double paidAmount;

  const PatientBill({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.items,
    required this.additionalCharges,
    required this.discount,
    required this.paidAmount,
  });

  double get subtotal => items.fold(0, (total, item) => total + item.amount);
  double get totalAmount => subtotal + additionalCharges - discount;
  double get outstandingAmount => totalAmount - paidAmount;
  BillStatus get status {
    if (paidAmount >= totalAmount) return BillStatus.paid;
    if (paidAmount > 0) return BillStatus.partiallyPaid;
    return BillStatus.pending;
  }
}

const _demoBills = <PatientBill>[
  PatientBill(
    id: 'DEMO-BILL-001',
    date: '2026-10-24',
    description: 'Demo consultation bill',
    category: BillCategory.consultation,
    items: [
      BillItem(
        description: 'Demo consultation charge',
        quantity: 1,
        unitPrice: 1500,
      ),
    ],
    additionalCharges: 0,
    discount: 0,
    paidAmount: 0,
  ),
  PatientBill(
    id: 'DEMO-BILL-002',
    date: '2026-09-12',
    description: 'Demo laboratory services bill',
    category: BillCategory.laboratory,
    items: [
      BillItem(
        description: 'Demo laboratory service',
        quantity: 1,
        unitPrice: 2200,
      ),
    ],
    additionalCharges: 0,
    discount: 0,
    paidAmount: 0,
  ),
];

class BillsPaymentsScreen extends StatefulWidget {
  const BillsPaymentsScreen({super.key});

  @override
  State<BillsPaymentsScreen> createState() => _BillsPaymentsScreenState();
}

class _BillsPaymentsScreenState extends State<BillsPaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  BillStatus? _status;
  BillCategory? _category;
  RecordSort _sort = RecordSort.latest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bills = _demoBills.where((bill) {
      final query = _query.trim().toLowerCase();
      return (query.isEmpty ||
              bill.id.toLowerCase().contains(query) ||
              bill.description.toLowerCase().contains(query)) &&
          (_status == null || bill.status == _status) &&
          (_category == null || bill.category == _category);
    }).toList();
    final orderedBills = [...bills]
      ..sort((first, second) {
        final firstDate = DateTime.tryParse(first.date);
        final secondDate = DateTime.tryParse(second.date);
        final comparison = firstDate != null && secondDate != null
            ? firstDate.compareTo(secondDate)
            : first.date.compareTo(second.date);
        return _sort == RecordSort.latest ? -comparison : comparison;
      });
    final total = _demoBills.fold(0.0, (sum, bill) => sum + bill.totalAmount);
    final paid = _demoBills.fold(0.0, (sum, bill) => sum + bill.paidAmount);
    final pending = total - paid;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const LocalizedText('Bills & Payments')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          const LocalizedText(
            'Billing overview',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 5),
          const LocalizedText(
            'Demo billing data is shown until clinic billing is connected.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth < 420 ? 0.85 : 1.65,
              children: [
                _BillingMetric(
                  icon: Icons.receipt_long_outlined,
                  label: 'Total bills',
                  value: _demoBills.length.toString(),
                ),
                _BillingMetric(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total amount',
                  value: formatIndianRupees(total),
                ),
                _BillingMetric(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Paid amount',
                  value: formatIndianRupees(paid),
                  color: AppColors.success,
                ),
                _BillingMetric(
                  icon: Icons.pending_outlined,
                  label: 'Pending amount',
                  value: formatIndianRupees(pending),
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SearchField(
            hint: 'Search bills',
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showBillFilters(context),
                icon: const Icon(Icons.filter_list_rounded, size: 18),
                label: LocalizedText(
                  _status == null && _category == null
                      ? 'Filter bills'
                      : 'Filters applied',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _sort = _sort == RecordSort.latest
                      ? RecordSort.oldest
                      : RecordSort.latest,
                ),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: LocalizedText(
                  _sort == RecordSort.latest ? 'Latest first' : 'Oldest first',
                ),
              ),
              if (_status != null || _category != null || _query.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _status = null;
                      _category = null;
                      _sort = RecordSort.latest;
                    });
                  },
                  child: const LocalizedText('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (orderedBills.isEmpty)
            const _EmptyState(
              title: 'No matching bills',
              description: 'Try another search or filter.',
            )
          else
            ...orderedBills.map(
              (bill) => _BillCard(
                bill: bill,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BillDetailsScreen(bill: bill),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showBillFilters(BuildContext context) async {
    final result = await showModalBottomSheet<_BillFilterSelection>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (_) => _BillFilterSheet(status: _status, category: _category),
    );
    if (!mounted || result == null) return;
    setState(() {
      _status = result.status;
      _category = result.category;
    });
  }
}

class _BillFilterSelection {
  final BillStatus? status;
  final BillCategory? category;

  const _BillFilterSelection({this.status, this.category});
}

class _BillFilterSheet extends StatefulWidget {
  final BillStatus? status;
  final BillCategory? category;

  const _BillFilterSheet({required this.status, required this.category});

  @override
  State<_BillFilterSheet> createState() => _BillFilterSheetState();
}

class _BillFilterSheetState extends State<_BillFilterSheet> {
  late BillStatus? _status = widget.status;
  late BillCategory? _category = widget.category;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        const LocalizedText('Filter bills', style: AppTextStyles.headingSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<BillStatus?>(
          initialValue: _status,
          decoration: InputDecoration(
            labelText: localizedText(context, 'Payment status'),
          ),
          items: [
            const DropdownMenuItem<BillStatus?>(
              value: null,
              child: LocalizedText('All statuses'),
            ),
            ...BillStatus.values.map(
              (status) => DropdownMenuItem(
                value: status,
                child: LocalizedText(_billStatusLabel(status)),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<BillCategory?>(
          initialValue: _category,
          decoration: InputDecoration(
            labelText: localizedText(context, 'Bill category'),
          ),
          items: [
            const DropdownMenuItem<BillCategory?>(
              value: null,
              child: LocalizedText('All categories'),
            ),
            ...BillCategory.values.map(
              (category) => DropdownMenuItem(
                value: category,
                child: LocalizedText(_billCategoryLabel(category)),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _BillFilterSelection(status: _status, category: _category),
          ),
          child: const LocalizedText('Apply filters'),
        ),
      ],
    ),
  );
}

class BillDetailsScreen extends StatelessWidget {
  final PatientBill bill;

  const BillDetailsScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context) => _DocumentScaffold(
    title: 'Bill Details',
    children: [
      _DetailHeader(
        icon: Icons.receipt_long_outlined,
        title: bill.id,
        subtitle: _billStatusLabel(bill.status),
      ),
      _DetailSection(
        title: 'Bill information',
        rows: {
          'Bill ID': bill.id,
          'Date': bill.date,
          'Category': _billCategoryLabel(bill.category),
          'Patient': 'Authenticated patient',
          'Payment status': _billStatusLabel(bill.status),
        },
      ),
      _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText(
              'Itemized charges',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: 10),
            ...bill.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            '${item.description} × ${item.quantity}',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const LocalizedText(
                                'Unit price',
                                style: AppTextStyles.bodySmall,
                              ),
                              const LocalizedText(': '),
                              Text(
                                formatIndianRupees(item.unitPrice),
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatIndianRupees(item.amount),
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      _DetailSection(
        title: 'Payment summary',
        rows: {
          'Subtotal': formatIndianRupees(bill.subtotal),
          'Additional charges': formatIndianRupees(bill.additionalCharges),
          'Discounts': formatIndianRupees(bill.discount),
          'Total amount': formatIndianRupees(bill.totalAmount),
          'Amount paid': formatIndianRupees(bill.paidAmount),
          'Outstanding balance': formatIndianRupees(bill.outstandingAmount),
        },
      ),
      const LocalizedText('Payment history', style: AppTextStyles.headingSmall),
      const SizedBox(height: 8),
      const _SurfaceCard(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.secondaryText),
            SizedBox(width: 10),
            Expanded(
              child: LocalizedText(
                'No payment transactions are available.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ),
      const _NoticeBox(
        text: 'Invoice download and sharing require file-service support.',
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoicePreviewScreen(bill: bill),
                ),
              ),
              icon: const Icon(Icons.preview_outlined),
              label: const LocalizedText('Invoice preview'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _unsupportedAction(context),
              icon: const Icon(Icons.download_outlined),
              label: const LocalizedText('Download invoice'),
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _unsupportedAction(context),
          icon: const Icon(Icons.share_outlined),
          label: const LocalizedText('Share invoice'),
        ),
      ),
    ],
  );

  void _unsupportedAction(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LocalizedText(
          'Invoice download and sharing require file-service support.',
        ),
      ),
    );
  }
}

class InvoicePreviewScreen extends StatelessWidget {
  final PatientBill bill;

  const InvoicePreviewScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context) => _DocumentScaffold(
    title: 'Invoice preview',
    children: [
      const _NoticeBox(
        text: 'Demo invoice preview. Not a clinic-issued invoice.',
      ),
      _DetailHeader(
        icon: Icons.receipt_long_outlined,
        title: bill.id,
        subtitle: bill.date,
      ),
      _DetailSection(
        title: 'Bill information',
        rows: {
          'Category': _billCategoryLabel(bill.category),
          'Patient': 'Authenticated patient',
          'Payment status': _billStatusLabel(bill.status),
        },
      ),
      _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText(
              'Itemized charges',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: 10),
            ...bill.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: LocalizedText(
                        '${item.description} × ${item.quantity}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    Text(
                      formatIndianRupees(item.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      _DetailSection(
        title: 'Payment summary',
        rows: {
          'Subtotal': formatIndianRupees(bill.subtotal),
          'Additional charges': formatIndianRupees(bill.additionalCharges),
          'Discounts': formatIndianRupees(bill.discount),
          'Total amount': formatIndianRupees(bill.totalAmount),
          'Amount paid': formatIndianRupees(bill.paidAmount),
          'Outstanding balance': formatIndianRupees(bill.outstandingAmount),
        },
      ),
      const _NoticeBox(
        text: 'Invoice download and sharing require file-service support.',
      ),
    ],
  );
}

class _BillingMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _BillingMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.burgundy,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryText.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 19),
        ),
        const Spacer(),
        LocalizedText(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BillCard extends StatelessWidget {
  final PatientBill bill;
  final VoidCallback onTap;

  const _BillCard({required this.bill, required this.onTap});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _IconBox(icon: Icons.receipt_long_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    bill.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  LocalizedText(
                    bill.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(bill.date, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            _PaymentStatusBadge(bill.status),
          ],
        ),
        const Divider(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const LocalizedText('Total', style: AppTextStyles.bodySmall),
            Text(
              formatIndianRupees(bill.totalAmount),
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const LocalizedText('Amount paid', style: AppTextStyles.bodySmall),
            Text(
              formatIndianRupees(bill.paidAmount),
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const LocalizedText('Category', style: AppTextStyles.bodySmall),
            LocalizedText(
              _billCategoryLabel(bill.category),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const LocalizedText('Outstanding', style: AppTextStyles.bodySmall),
            Text(
              formatIndianRupees(bill.outstandingAmount),
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onTap,
            child: const LocalizedText('View bill details'),
          ),
        ),
      ],
    ),
  );
}

class _PaymentStatusBadge extends StatelessWidget {
  final BillStatus status;

  const _PaymentStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BillStatus.paid => AppColors.success,
      BillStatus.partiallyPaid => AppColors.warning,
      BillStatus.pending => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LocalizedText(
        _billStatusLabel(status),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class IpBillingScreen extends StatelessWidget {
  const IpBillingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const LocalizedText('IP Billing')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 34, 18, 32),
      children: const [
        _EmptyState(
          icon: Icons.local_hospital_outlined,
          title: 'No Inpatient Billing Records',
          description: 'Your inpatient billing details will appear here when they are available.',
        ),
      ],
    ),
  );
}

String _billStatusLabel(BillStatus status) => switch (status) {
  BillStatus.paid => 'Paid',
  BillStatus.partiallyPaid => 'Partially Paid',
  BillStatus.pending => 'Pending',
};

String _billCategoryLabel(BillCategory category) => switch (category) {
  BillCategory.consultation => 'Consultation',
  BillCategory.laboratory => 'Laboratory',
  BillCategory.pharmacy => 'Pharmacy',
  BillCategory.package => 'Care package',
  BillCategory.other => 'Other',
};

IconData _recordIcon(RecordCategory category) => switch (category) {
  RecordCategory.patientDetails => Icons.person_outline_rounded,
  RecordCategory.medicalHistory => Icons.history_rounded,
  RecordCategory.diagnosis => Icons.health_and_safety_outlined,
  RecordCategory.consultation => Icons.medical_services_outlined,
  RecordCategory.treatment => Icons.vaccines_outlined,
  RecordCategory.allergies => Icons.warning_amber_outlined,
  RecordCategory.prescriptions => Icons.medication_outlined,
  RecordCategory.clinicalNotes => Icons.note_alt_outlined,
  RecordCategory.vitalSigns => Icons.monitor_heart_outlined,
};

String _recordCategoryLabel(RecordCategory category) => switch (category) {
  RecordCategory.patientDetails => 'Patient Details',
  RecordCategory.medicalHistory => 'Medical History',
  RecordCategory.diagnosis => 'Diagnosis',
  RecordCategory.consultation => 'Doctor Consultations',
  RecordCategory.treatment => 'Treatment History',
  RecordCategory.allergies => 'Allergies',
  RecordCategory.prescriptions => 'Prescriptions',
  RecordCategory.clinicalNotes => 'Clinical Notes',
  RecordCategory.vitalSigns => 'Vital Signs',
};

IconData _reportIcon(ReportCategory category) => switch (category) {
  ReportCategory.bloodTest => Icons.bloodtype_outlined,
  ReportCategory.hormoneTest => Icons.science_outlined,
  ReportCategory.ultrasound => Icons.monitor_heart_outlined,
  ReportCategory.scan => Icons.document_scanner_outlined,
  ReportCategory.fertilityInvestigation => Icons.biotech_outlined,
  ReportCategory.otherLaboratory => Icons.analytics_outlined,
};

String _reportCategoryLabel(ReportCategory category) => switch (category) {
  ReportCategory.bloodTest => 'Blood Test Reports',
  ReportCategory.hormoneTest => 'Hormone Test Reports',
  ReportCategory.ultrasound => 'Ultrasound Reports',
  ReportCategory.scan => 'Scan Reports',
  ReportCategory.fertilityInvestigation => 'Fertility Investigation Reports',
  ReportCategory.otherLaboratory => 'Other Laboratory Reports',
};
