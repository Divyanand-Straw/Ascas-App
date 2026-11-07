import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/locale_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import '../../../medication/presentation/medication_screen.dart';
import '../../../communication/presentation/communication_screen.dart';
import '../../../education/presentation/education_screen.dart';
import 'dashboard_home_content.dart';
import 'patient_profile_screen.dart';
import 'treatment_overview_screen.dart';

class PatientServicesScreen extends StatelessWidget {
  final String patientName;
  final String mobileNumber;
  final String dateOfBirth;
  final String preferredLanguage;
  final DashboardPatientState patientState;

  const PatientServicesScreen({
    super.key,
    required this.patientName,
    required this.mobileNumber,
    required this.dateOfBirth,
    required this.preferredLanguage,
    required this.patientState,
  });

  String get _initials {
    final parts = patientName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isEmpty ? '' : parts.first[0].toUpperCase();
  }

  String get _treatmentName {
    switch (patientState) {
      case DashboardPatientState.ivf:
        return 'IVF Cycle 1';
      case DashboardPatientState.iui:
        return 'IUI Treatment';
      case DashboardPatientState.embryoTransfer:
        return 'Embryo Transfer';
      case DashboardPatientState.twoWeekWait:
        return 'Two-Week Wait';
      case DashboardPatientState.followUpCare:
        return 'Follow-up Care';
      case DashboardPatientState.postProcedureRecovery:
        return 'Follow-up Care';
      case DashboardPatientState.newPatient:
        return 'Follow-up Care';
    }
  }

  void _open(BuildContext context, String title, String subtitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PatientServicePlaceholderScreen(title: title, subtitle: subtitle),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 23, bottom: 9),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.burgundy,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
        ),
      ),
    ),
  );

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.blushPink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.burgundy, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.secondaryText,
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(children: children),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = LocaleService.locale.value.languageCode;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primaryText,
        title: Text(
          l10n.patientServices,
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.blushPink,
              child: Text(
                _initials,
                style: const TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              patientName,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            LocalizedText(
              'Patient ID: AS-20481',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            _sectionTitle(l10n.appLanguage),
            _card([
              ListTile(
                title: Text(l10n.english),
                trailing: Icon(
                  language == 'en'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.burgundy,
                ),
                onTap: () => LocaleService.setLanguage('en'),
              ),
              ListTile(
                title: Text(l10n.tamil),
                trailing: Icon(
                  language == 'ta'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.burgundy,
                ),
                onTap: () => LocaleService.setLanguage('ta'),
              ),
            ]),
            _sectionTitle(l10n.treatmentCare),
            _card([
              _tile(
                context: context,
                icon: Icons.medication_outlined,
                title: l10n.medicationInjections,
                subtitle: 'Clinic prescription schedule.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicationScreen()),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.biotech_outlined,
                title: 'Embryology Updates',
                subtitle: 'Clinic-published embryo timeline.',
                onTap: () => _open(
                  context,
                  'Embryology Updates',
                  'No clinic-published embryology updates are available.',
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.healing_outlined,
                title: 'Procedure Preparation',
                subtitle: 'Instructions and recovery.',
                onTap: () => _open(
                  context,
                  'Procedure Preparation',
                  'Clinic instructions will appear here when published.',
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.timeline_rounded,
                title: 'Fertility History',
                subtitle: 'Previous cycles and records.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TreatmentOverviewScreen(
                      treatmentName: _treatmentName,
                      currentStage: 'Ovarian stimulation',
                    ),
                  ),
                ),
              ),
            ]),
            _sectionTitle(l10n.planningSupport),
            _card([
              _tile(
                context: context,
                icon: Icons.receipt_long_outlined,
                title: 'Billing & Packages',
                subtitle: '₹ estimates, payments and receipts.',
                onTap: () => _open(
                  context,
                  'Billing & Packages',
                  'Billing details are not connected in this prototype.',
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.ac_unit_rounded,
                title: 'Frozen Embryo Storage',
                subtitle: 'Storage status and renewal.',
                onTap: () => _open(
                  context,
                  'Frozen Embryo Storage',
                  'Storage information is not available in this prototype.',
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.people_outline_rounded,
                title: 'Partner Access',
                subtitle: 'Permission-based sharing.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PartnerPermissionsScreen(
                      permissions: {
                        'Appointments': false,
                        'Treatment overview': false,
                        'Health records': false,
                      },
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.question_answer_outlined,
                title: 'Question Notebook',
                subtitle: 'Prepare for consultations.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QuestionNotebookScreen(),
                  ),
                ),
              ),
            ]),
            _sectionTitle(l10n.learnSupported),
            _card([
              _tile(
                context: context,
                icon: Icons.menu_book_outlined,
                title: l10n.educationCentre,
                subtitle: 'Clinic-reviewed resources.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EducationScreen()),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.mood_outlined,
                title: 'Wellness Journal',
                subtitle: 'Private mood and reflection tools.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WellnessJournalScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.male_outlined,
                title: 'Male Fertility',
                subtitle: 'Inclusive education and records.',
                onTap: () => _open(
                  context,
                  'Male Fertility',
                  'No male fertility records or clinic resources are available.',
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.groups_outlined,
                title: 'ASCAS Circle',
                subtitle: 'General community support.',
                onTap: () => _open(
                  context,
                  'ASCAS Circle',
                  'Community services are coming soon and require secure moderation.',
                ),
              ),
            ]),
            _sectionTitle(l10n.accountClinic),
            _card([
              _tile(
                context: context,
                icon: Icons.chat_bubble_outline_rounded,
                title: l10n.clinicCommunication,
                subtitle: 'Inbox, chat and support.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CommunicationScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Reminders and clinic updates.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.lock_outline_rounded,
                title: 'Privacy & Consent',
                subtitle: 'Security and permissions.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConsentManagementScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _tile(
                context: context,
                icon: Icons.person_outline_rounded,
                title: 'Profile & Settings',
                subtitle: 'Personal details and preferences.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientProfileScreen(
                      patientName: patientName,
                      patientInitials: _initials,
                      patientState: patientState,
                      mobileNumber: mobileNumber,
                      dateOfBirth: dateOfBirth,
                      preferredLanguage: preferredLanguage,
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 22),
            LocalizedText(
              'Medical information and instructions are provided from authorized Thaai Seyazhi clinic records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientServicePlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const PatientServicePlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.burgundy,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class QuestionNotebookScreen extends StatefulWidget {
  const QuestionNotebookScreen({super.key});

  @override
  State<QuestionNotebookScreen> createState() => _QuestionNotebookScreenState();
}

class _QuestionNotebookScreenState extends State<QuestionNotebookScreen> {
  static const _storageKey = 'patient_question_notebook';
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || !mounted) return;
    setState(() {
      _questions = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
    });
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(_questions));
  }

  Future<void> _edit([int? index]) async {
    final controller = TextEditingController(
      text: index == null ? '' : _questions[index]['text'] as String,
    );
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'Add question' : 'Edit question'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: localizedText(context, 'Your question'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: LocalizedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: LocalizedText('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    setState(() {
      if (index == null) {
        _questions.add({'text': text, 'discussed': false});
      } else {
        _questions[index]['text'] = text;
      }
    });
    await _save();
  }

  Future<void> _delete(int index) async {
    setState(() => _questions.removeAt(index));
    await _save();
  }

  Future<void> _toggle(int index, bool value) async {
    setState(() => _questions[index]['discussed'] = value);
    await _save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: LocalizedText('Question Notebook'),
      actions: [IconButton(onPressed: _edit, icon: const Icon(Icons.add))],
    ),
    body: _questions.isEmpty
        ? const Center(
            child: LocalizedText(
              'No questions saved yet.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];
              return Card(
                color: AppColors.white,
                child: ListTile(
                  title: Text(question['text'] as String),
                  subtitle: Text(
                    question['discussed'] as bool
                        ? 'Marked as discussed'
                        : 'Not discussed',
                  ),
                  leading: Checkbox(
                    value: question['discussed'] as bool,
                    activeColor: AppColors.burgundy,
                    onChanged: (value) => _toggle(index, value ?? false),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _edit(index);
                      if (value == 'delete') _delete(index);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: LocalizedText('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: LocalizedText('Delete'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

class WellnessJournalScreen extends StatefulWidget {
  const WellnessJournalScreen({super.key});

  @override
  State<WellnessJournalScreen> createState() => _WellnessJournalScreenState();
}

class _WellnessJournalScreenState extends State<WellnessJournalScreen> {
  static const _storageKey = 'patient_wellness_journal';
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || !mounted) return;
    setState(() {
      _entries = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
    });
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(_entries));
  }

  Future<void> _edit([int? index]) async {
    final moodController = TextEditingController(
      text: index == null ? 'Calm' : _entries[index]['mood'] as String,
    );
    final noteController = TextEditingController(
      text: index == null ? '' : _entries[index]['note'] as String,
    );
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'New journal entry' : 'Edit journal entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: moodController,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Mood'),
              ),
            ),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Reflection'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: LocalizedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, [
              moodController.text.trim(),
              noteController.text.trim(),
            ]),
            child: LocalizedText('Save'),
          ),
        ],
      ),
    );
    moodController.dispose();
    noteController.dispose();
    if (result == null || result[1].isEmpty) return;
    setState(() {
      final entry = {
        'mood': result[0].isEmpty ? 'Unspecified' : result[0],
        'note': result[1],
        'date': DateTime.now().toIso8601String(),
      };
      if (index == null) {
        _entries.insert(0, entry);
      } else {
        _entries[index] = entry;
      }
    });
    await _save();
  }

  Future<void> _delete(int index) async {
    setState(() => _entries.removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: LocalizedText('Wellness Journal'),
      actions: [IconButton(onPressed: _edit, icon: const Icon(Icons.add))],
    ),
    body: _entries.isEmpty
        ? const Center(
            child: LocalizedText(
              'No private reflections saved yet.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return Card(
                color: AppColors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.favorite_outline,
                    color: AppColors.burgundy,
                  ),
                  title: Text(entry['mood'] as String),
                  subtitle: Text(entry['note'] as String),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _edit(index);
                      if (value == 'delete') _delete(index);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: LocalizedText('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: LocalizedText('Delete'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
