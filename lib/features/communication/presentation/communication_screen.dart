import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/dashboard_card.dart';

class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  int _supportRequestCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _supportRequestCount = preferences.getInt('support_request_count') ?? 0;
      _loading = false;
    });
  }

  Future<void> _openRequestForm() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SupportRequestScreen()),
    );
    if (submitted == true) {
      await _loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: LocalizedText('Communication & Support')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                DashboardCard(
                  color: AppColors.burgundy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'PATIENT SUPPORT',
                        style: TextStyle(
                          color: AppColors.dustyPink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LocalizedText(
                        'Your care conversations',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LocalizedText(
                        'This is a local prototype. Messages are not sent to or received from the clinic.',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LocalizedText(
                  'EMERGENCY GUIDANCE',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                DashboardCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.emergency_outlined,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: LocalizedText(
                          'Do not use app messaging for urgent medical problems. Seek immediate medical attention or contact appropriate emergency services.',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LocalizedText(
                  'QUICK SUPPORT',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                _tile(
                  Icons.forum_outlined,
                  'Patient inbox',
                  'Conversations and pending responses',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConversationListScreen(),
                    ),
                  ),
                ),
                _tile(
                  Icons.add_comment_outlined,
                  'Submit a support request',
                  'Create a local request reference',
                  _openRequestForm,
                ),
                _tile(
                  Icons.help_outline_rounded,
                  'Frequently asked questions',
                  'Registration, appointments, medication and privacy',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FrequentlyAskedQuestionsScreen(),
                    ),
                  ),
                ),
                _tile(
                  Icons.local_hospital_outlined,
                  'Clinic contact',
                  'Only verified contact details are shown',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClinicContactScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DashboardCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions_outlined,
                        color: AppColors.burgundy,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedText(
                          '$_supportRequestCount pending local support request${_supportRequestCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _openRequestForm,
                        child: LocalizedText('Review'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DashboardCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: AppColors.burgundy),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class ConversationListScreen extends StatelessWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: LocalizedText('Patient Inbox')),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _PrototypeBanner(
            text: 'No clinic conversations are connected. This empty inbox does not indicate that a clinic has received a message.',
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.dustyPink,
                  size: 44,
                ),
                const SizedBox(height: 10),
                LocalizedText(
                  'Your inbox is empty',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                LocalizedText(
                  'Clinic responses will appear here only after a secure messaging service is connected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportRequestScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: LocalizedText('Create support request'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: LocalizedText('Open local prototype chat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _messages = <_PrototypeMessage>[];
  String? _attachment;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachment == null) return;
    setState(() {
      _messages.add(_PrototypeMessage(text: text, attachment: _attachment));
      _messageController.clear();
      _attachment = null;
    });
  }

  Future<void> _selectAttachment() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: LocalizedText('Image (prototype)'),
              onTap: () => Navigator.pop(context, 'prototype-image.jpg'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: LocalizedText('PDF (prototype)'),
              onTap: () => Navigator.pop(context, 'prototype-document.pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: LocalizedText('Unsupported file types are blocked'),
              enabled: false,
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _attachment = selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: LocalizedText('Patient Support Chat')),
    backgroundColor: AppColors.background,
    body: Column(
      children: [
        const _PrototypeBanner(
          text: 'Local prototype only. Messages remain on this device and show Pending; no clinic delivery or response is represented.',
        ),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: LocalizedText(
                    'No messages yet.\nStart a local prototype conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _showMessageDetails(message),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8, left: 40),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.blushPink,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.text.isNotEmpty) Text(message.text),
                              if (message.attachment != null)
                                LocalizedText(
                                  'Attachment: ${message.attachment}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.burgundy,
                                  ),
                                ),
                              const SizedBox(height: 5),
                              LocalizedText(
                                'Patient • Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_attachment != null)
          ListTile(
            dense: true,
            leading: const Icon(Icons.attach_file, color: AppColors.burgundy),
            title: Text(_attachment!),
            subtitle: LocalizedText('Ready to attach locally'),
            trailing: IconButton(
              onPressed: () => setState(() => _attachment = null),
              icon: const Icon(Icons.close),
            ),
          ),
        SafeArea(
          child: Row(
            children: [
              IconButton(
                onPressed: _selectAttachment,
                icon: const Icon(Icons.attach_file, color: AppColors.burgundy),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: localizedText(
                      context,
                      'Write a local prototype message',
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send_rounded, color: AppColors.burgundy),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showMessageDetails(_PrototypeMessage message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: LocalizedText('Message details'),
        content: LocalizedText(
          'Sender: Patient\nStatus: Pending (local only)\nTime: ${message.createdAt}\nAttachment: ${message.attachment ?? 'None'}',
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
}

class _PrototypeMessage {
  final String text;
  final String? attachment;
  final DateTime createdAt;

  _PrototypeMessage({required this.text, required this.attachment})
    : createdAt = DateTime.now();
}

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key});

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _category = 'General support';
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final preferences = await SharedPreferences.getInstance();
    final nextCount = (preferences.getInt('support_request_count') ?? 0) + 1;
    await preferences.setInt('support_request_count', nextCount);
    if (!mounted) return;
    await Navigator.pushReplacement<bool, bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SupportRequestConfirmationScreen(
          reference: 'LOCAL-${DateTime.now().millisecondsSinceEpoch}',
        ),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: LocalizedText('Support Request')),
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _PrototypeBanner(
              text: 'This request is saved on this device only. It is not submitted to the clinic.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Request category'),
              ),
              items:
                  [
                        'General support',
                        'Appointments',
                        'Medication',
                        'Treatment journey',
                        'Medical records',
                        'Account and privacy',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            TextFormField(
              controller: _subject,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Subject'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a subject'
                  : null,
            ),
            TextFormField(
              controller: _description,
              minLines: 5,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: localizedText(context, 'Description'),
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a description'
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.attach_file),
              label: LocalizedText('Add attachment (not enabled)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving…' : 'Save support request'),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportRequestConfirmationScreen extends StatelessWidget {
  final String reference;

  const SupportRequestConfirmationScreen({super.key, required this.reference});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: LocalizedText('Request Confirmation')),
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DashboardCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 54,
                ),
                const SizedBox(height: 12),
                LocalizedText(
                  'Support request saved',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                LocalizedText(
                  'Local reference: $reference',
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 8),
                LocalizedText(
                  'No clinic submission or response has occurred.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: LocalizedText('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClinicContactScreen extends StatelessWidget {
  const ClinicContactScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: LocalizedText('Clinic Contact')),
    backgroundColor: AppColors.background,
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: DashboardCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_hospital_outlined,
                color: AppColors.dustyPink,
                size: 48,
              ),
              SizedBox(height: 12),
              LocalizedText(
                'Clinic contact details unavailable',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              LocalizedText(
                'Verified phone numbers, email addresses and opening hours will appear here when provided by the clinic.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FrequentlyAskedQuestionsScreen extends StatelessWidget {
  const FrequentlyAskedQuestionsScreen({super.key});

  static const _questions = {
    'Registration': [
      'How do I access my account?',
      'Use the registration and verification flow provided by your clinic.',
    ],
    'Appointments': [
      'Can I change an appointment?',
      'Use the existing appointments feature to submit an eligible request.',
    ],
    'Medication': [
      'Who controls medication information?',
      'Only clinic-authorized prescription information should be used.',
    ],
    'Treatment journey': [
      'Can I change a milestone?',
      'No. Treatment pathways and milestones are clinic-controlled.',
    ],
    'Medical records': [
      'Are missing records available?',
      'No. Records appear only when securely published by the clinic.',
    ],
    'Account and privacy': [
      'Is messaging private?',
      'This prototype stores support requests locally; no clinic messaging backend is connected.',
    ],
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: LocalizedText('Frequently Asked Questions')),
    backgroundColor: AppColors.background,
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: _questions.entries
          .map(
            (entry) => Card(
              color: AppColors.white,
              child: ExpansionTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  ListTile(
                    title: Text(entry.value.first),
                    subtitle: Text(entry.value.last),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _PrototypeBanner extends StatelessWidget {
  final String text;

  const _PrototypeBanner({required this.text});

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.burgundy, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
