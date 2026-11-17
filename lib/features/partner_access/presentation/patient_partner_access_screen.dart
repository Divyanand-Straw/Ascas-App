import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/dashboard_home_content.dart';
import '../data/partner_link_service.dart';

class PatientPartnerAccessScreen extends StatefulWidget {
  final String patientUserId;
  final String patientId;
  final String patientName;
  final String patientMobile;
  final DashboardPatientState patientState;

  const PatientPartnerAccessScreen({
    super.key,
    required this.patientUserId,
    required this.patientId,
    required this.patientName,
    required this.patientMobile,
    required this.patientState,
  });

  @override
  State<PatientPartnerAccessScreen> createState() =>
      _PatientPartnerAccessScreenState();
}

class _PatientPartnerAccessScreenState
    extends State<PatientPartnerAccessScreen> {
  final _service = PartnerLinkService();
  List<PartnerRelationship> _relationships = [];
  PartnerRelationship? _invitation;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    PartnerLinkService.changes.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    PartnerLinkService.changes.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final relationships = await _service.forPatient(
      widget.patientUserId,
      legacyPatientId: widget.patientId,
    );
    if (!mounted) return;
    PartnerRelationship? invitation;
    for (final relationship in relationships) {
      if (relationship.status == PartnerLinkStatus.invitation) {
        invitation = relationship;
        break;
      }
    }
    setState(() {
      _relationships = relationships;
      _invitation = invitation;
      _loading = false;
    });
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LocalizedText(
          error.toString().replaceFirst('Bad state: ', ''),
        ),
      ),
    );
  }

  Future<void> _generateInvitation() async {
    setState(() => _working = true);
    try {
      await _service.generateInvitation(
        patientUserId: widget.patientUserId,
        patientId: widget.patientId,
        patientName: widget.patientName,
        patientMobile: widget.patientMobile,
        patientState: widget.patientState.name,
      );
      await _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reviewRequest(
    PartnerRelationship relationship, {
    required bool approve,
  }) async {
    try {
      if (approve) {
        await _service.approveRequest(relationship.linkId);
      } else {
        await _service.rejectRequest(relationship.linkId);
      }
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editPermissions(PartnerRelationship relationship) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerDetailsSharingScreen(
          patientName: widget.patientName,
          partnerName: relationship.partnerName,
          permissions: relationship.permissions,
          linkId: relationship.linkId,
          service: _service,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _revoke(PartnerRelationship relationship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalizedText('Revoke partner access?'),
        content: LocalizedText(
          '${relationship.partnerName} will immediately lose access to shared categories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LocalizedText('Keep access'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LocalizedText('Revoke access'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.revokeAccess(relationship.linkId);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: LocalizedText(
      title,
      style: const TextStyle(
        color: AppColors.burgundy,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _relationshipCard(PartnerRelationship relationship) {
    final isPending = relationship.status == PartnerLinkStatus.pending;
    final isActive = relationship.status == PartnerLinkStatus.active;
    final sharedCategories = relationship.permissions.entries
        .where((entry) => entry.value)
        .map((entry) => localizedText(context, entry.key))
        .toList()
        .ifEmpty('none');
    final statusLabel = switch (relationship.status) {
      PartnerLinkStatus.invitation => 'Pending',
      PartnerLinkStatus.pending => 'Pending approval',
      PartnerLinkStatus.rejected => 'Request rejected',
      PartnerLinkStatus.active => 'Connected',
      PartnerLinkStatus.revoked => 'Revoked',
      PartnerLinkStatus.expired => 'Invitation expired',
    };
    final card = Card(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.burgundy),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        relationship.partnerName.isEmpty
                            ? 'Partner'
                            : relationship.partnerName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      LocalizedText(
                        relationship.partnerMobile.isEmpty
                            ? localizedText(context, statusLabel)
                            : '${relationship.partnerMobile} · ${localizedText(context, statusLabel)}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              const LocalizedText(
                'Approve only if you recognize this partner and want to share access.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _reviewRequest(relationship, approve: false),
                      child: const LocalizedText('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _reviewRequest(relationship, approve: true),
                      child: const LocalizedText('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            if (isActive) ...[
              const SizedBox(height: 8),
              LocalizedText(
                'Sharing: $sharedCategories',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _editPermissions(relationship),
                    child: const LocalizedText('Manage permissions'),
                  ),
                  TextButton(
                    onPressed: () => _revoke(relationship),
                    child: const LocalizedText('Revoke access'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    return isActive
        ? InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ConnectedPartnerScreen(
                  patientName: widget.patientName,
                  relationship: relationship,
                  service: _service,
                ),
              ),
            ),
            child: card,
          )
        : card;
  }

  @override
  Widget build(BuildContext context) {
    final current = DateTime.now();
    final visible = _relationships
        .where(
          (relationship) => relationship.status != PartnerLinkStatus.invitation,
        )
        .toList();
    final active = visible.where(
      (relationship) => relationship.status == PartnerLinkStatus.active,
    );
    final hasActive = active.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const LocalizedText('Partner Access'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const LocalizedText(
                  'You control who can view your patient information. Partner accounts remain separate and do not receive a patient record.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    height: 1.45,
                  ),
                ),
                if (_invitation != null &&
                    current.isBefore(_invitation!.invitationExpiry)) ...[
                  _sectionTitle('Current invitation'),
                  Card(
                    color: AppColors.white,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LocalizedText(
                            'Share this one-time code with your partner.',
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            _invitation!.invitationCode,
                            style: const TextStyle(
                              color: AppColors.burgundy,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: _invitation!.invitationCode,
                                    ),
                                  );
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: LocalizedText(
                                        'Invitation code copied.',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: const LocalizedText('Copy'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => SharePlus.instance.share(
                                  ShareParams(
                                    text:
                                        'Use invitation code ${_invitation!.invitationCode} to connect with me in Thaai Seyali.',
                                  ),
                                ),
                                icon: const Icon(Icons.share_rounded),
                                label: const LocalizedText('Share'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LocalizedText(
                            'Expires ${_invitation!.invitationExpiry.toLocal()}',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                _sectionTitle('Link a partner'),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _working || hasActive
                        ? null
                        : _generateInvitation,
                    icon: const Icon(Icons.key_rounded),
                    label: LocalizedText(
                      hasActive
                          ? 'An active partner is already linked'
                          : 'Generate invitation',
                    ),
                  ),
                ),
                _sectionTitle('Linked partners'),
                if (visible.isEmpty)
                  const Card(
                    color: AppColors.white,
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: LocalizedText(
                        'No linking requests or active partners.',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                  ),
                ...visible.map(_relationshipCard),
                const SizedBox(height: 12),
                const LocalizedText(
                  'Prototype only: these records are stored on this device. Production access requires authenticated server-side authorization.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }
}

class ConnectedPartnerScreen extends StatelessWidget {
  final String patientName;
  final PartnerRelationship relationship;
  final PartnerLinkService service;

  const ConnectedPartnerScreen({
    super.key,
    required this.patientName,
    required this.relationship,
    required this.service,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const LocalizedText('Connected partner'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const LocalizedText(
          'Your partner is connected to your account.',
          style: TextStyle(color: AppColors.secondaryText, height: 1.4),
        ),
        const SizedBox(height: 18),
        Card(
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PartnerDetailsSharingScreen(
                  patientName: patientName,
                  partnerName: relationship.partnerName,
                  permissions: relationship.permissions,
                  linkId: relationship.linkId,
                  service: service,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.blushPink,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.burgundy,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relationship.partnerName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          relationship.partnerMobile,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const LocalizedText(
                          'Connected',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: LocalizedText(
            'Tap the profile card to manage sharing.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class PartnerDetailsSharingScreen extends StatefulWidget {
  final String patientName;
  final String partnerName;
  final Map<String, bool> permissions;
  final String? linkId;
  final PartnerLinkService? service;

  const PartnerDetailsSharingScreen({
    super.key,
    this.patientName = 'Patient',
    this.partnerName = 'Partner',
    required this.permissions,
    this.linkId,
    this.service,
  });

  @override
  State<PartnerDetailsSharingScreen> createState() =>
      _PartnerDetailsSharingScreenState();
}

class _PartnerDetailsSharingScreenState
    extends State<PartnerDetailsSharingScreen> {
  late final Map<String, bool> _permissions;
  final _service = PartnerLinkService();
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _permissions = defaultPartnerPermissions()..addAll(widget.permissions);
  }

  Future<void> _changePermission(String category, bool value) async {
    final previous = _permissions[category] ?? false;
    setState(() {
      _permissions[category] = value;
      _saving.add(category);
    });
    try {
      if (widget.linkId != null) {
        await (widget.service ?? _service).savePermissions(
          widget.linkId!,
          _permissions,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _permissions[category] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(category));
    }
  }

  String _title(String category) => switch (category) {
    'Medication schedules' => 'Share Medication Schedule',
    'Appointments' => 'Share Appointments',
    'Medical Reports' => 'Share Medical Reports',
    _ => category,
  };

  String _description(String category) => switch (category) {
    'Medication schedules' =>
      'Allow authorized medication schedules and reminders.',
    'Appointments' =>
      'Allow appointment dates, doctor details, and appointment status.',
    'Medical Reports' =>
      'Allow authorized investigation reports and medical documents.',
    _ => '',
  };

  Widget _profileIcon(String name, IconData icon) => Column(
    children: [
      CircleAvatar(
        radius: 30,
        backgroundColor: AppColors.blushPink,
        child: Icon(icon, color: AppColors.burgundy, size: 28),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 110,
        child: Text(
          name,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  Widget _sharingCard(String category) => Card(
    color: AppColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.divider),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  _title(category),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                LocalizedText(
                  _description(category),
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _permissions[category] ?? false,
            onChanged: _saving.contains(category)
                ? null
                : (value) => _changePermission(category, value),
            activeTrackColor: AppColors.success,
            inactiveTrackColor: AppColors.divider,
            activeThumbColor: AppColors.white,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const LocalizedText('Partner details'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _profileIcon(widget.patientName, Icons.person_rounded),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.link_rounded, color: AppColors.success),
            ),
            _profileIcon(widget.partnerName, Icons.person_outline_rounded),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Chip(
            avatar: const Icon(Icons.check_circle, color: AppColors.success),
            label: const LocalizedText('Connected'),
            backgroundColor: AppColors.blushPink,
          ),
        ),
        const SizedBox(height: 18),
        const LocalizedText(
          'Sharing settings',
          style: TextStyle(
            color: AppColors.burgundy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...partnerSharingCategories.map(_sharingCard),
      ],
    ),
  );
}

extension on Iterable<String> {
  String ifEmpty(String value) => isEmpty ? value : join(', ');
}
