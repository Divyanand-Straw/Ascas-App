import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/dashboard_card.dart';
import '../../communication/presentation/communication_screen.dart';

enum RecordCategory {
  investigation,
  laboratory,
  scan,
  prescription,
  visit,
  treatment,
}

class MedicalRecord {
  final String title;
  final RecordCategory category;
  final String date;
  final String source;
  final bool available;

  const MedicalRecord({
    required this.title,
    required this.category,
    required this.date,
    required this.source,
    this.available = false,
  });
}

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final _records = const <MedicalRecord>[
    MedicalRecord(
      title: 'Clinic reports will appear here',
      category: RecordCategory.investigation,
      date: 'Awaiting clinic update',
      source: 'Thaai Seyazhi',
      available: false,
    ),
  ];
  String _query = '';
  RecordCategory? _filter;

  String _categoryLabel(RecordCategory category) => switch (category) {
    RecordCategory.investigation => 'Investigations',
    RecordCategory.laboratory => 'Laboratory',
    RecordCategory.scan => 'Scans',
    RecordCategory.prescription => 'Prescriptions',
    RecordCategory.visit => 'Visit summaries',
    RecordCategory.treatment => 'Treatment documents',
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _records.where((record) {
      final matchesText = record.title.toLowerCase().contains(
        _query.toLowerCase(),
      );
      return matchesText && (_filter == null || record.category == _filter);
    }).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: LocalizedText('Medical Records'),
        actions: [
          IconButton(
            tooltip: localizedText(context, 'Support'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommunicationScreen()),
            ),
            icon: const Icon(Icons.support_agent_outlined),
          ),
          IconButton(
            tooltip: localizedText(context, 'Upload document'),
            onPressed: () => _uploadUnavailable(context),
            icon: const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          DashboardCard(
            color: AppColors.burgundy,
            child: Row(
              children: [
                const Icon(
                  Icons.folder_copy_outlined,
                  color: AppColors.dustyPink,
                  size: 34,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'PRIVATE MEDICAL RECORDS',
                        style: TextStyle(
                          color: AppColors.dustyPink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      LocalizedText(
                        '0 available documents',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: localizedText(context, 'Search records'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<RecordCategory>(
            initialValue: _filter,
            decoration: InputDecoration(
              labelText: localizedText(context, 'Category'),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: [null, ...RecordCategory.values]
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(
                      category == null
                          ? 'All categories'
                          : _categoryLabel(category),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 18),
          LocalizedText(
            'RECENT RECORDS',
            style: TextStyle(
              color: AppColors.burgundy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty || !filtered.any((record) => record.available))
            DashboardCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AppColors.dustyPink,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  LocalizedText(
                    'No clinic records available',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  LocalizedText(
                    'Official reports and prescriptions will appear here when securely published by your clinic.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ...filtered.where((record) => record.available).map(_recordCard),
          const SizedBox(height: 18),
          LocalizedText(
            'CATEGORIES',
            style: TextStyle(
              color: AppColors.burgundy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RecordCategory.values
                .map(
                  (category) => ActionChip(
                    avatar: const Icon(Icons.folder_outlined, size: 16),
                    label: LocalizedText(_categoryLabel(category)),
                    onPressed: () => setState(() => _filter = category),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(MedicalRecord record) => DashboardCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.description_outlined,
        color: AppColors.burgundy,
      ),
      title: LocalizedText(record.title),
      subtitle: LocalizedText(
        '${_categoryLabel(record.category)} • ${record.date}\n${record.source}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showPreview(context, record),
    ),
  );

  void _showPreview(BuildContext context, MedicalRecord record) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: LocalizedText(record.title),
        content: LocalizedText(
          'This document is available from the clinic and can be previewed here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: LocalizedText('Close'),
          ),
        ],
      ),
    );
  }

  void _uploadUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LocalizedText(
          'Patient uploads are not enabled for this account.',
        ),
      ),
    );
  }
}
