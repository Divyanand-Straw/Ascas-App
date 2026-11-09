import 'package:flutter/material.dart';

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
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
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
    final result = await Navigator.push<Map<String, bool>>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerPermissionManagementScreen(
          permissions: relationship.permissions,
        ),
      ),
    );
    if (result == null) return;
    try {
      await _service.savePermissions(relationship.linkId, result);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _revoke(PartnerRelationship relationship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke partner access?'),
        content: Text(
          '${relationship.partnerName} will immediately lose access to shared categories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep access'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke access'),
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
    child: Text(
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
    final statusLabel = switch (relationship.status) {
      PartnerLinkStatus.invitation => 'Invitation available',
      PartnerLinkStatus.pending => 'Request pending',
      PartnerLinkStatus.rejected => 'Request rejected',
      PartnerLinkStatus.active => 'Access active',
      PartnerLinkStatus.revoked => 'Access revoked',
      PartnerLinkStatus.expired => 'Invitation expired',
    };
    return Card(
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
                      Text(
                        relationship.partnerMobile.isEmpty
                            ? statusLabel
                            : '${relationship.partnerMobile} · $statusLabel',
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
              const Text(
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
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _reviewRequest(relationship, approve: true),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            if (isActive) ...[
              const SizedBox(height: 8),
              Text(
                'Sharing: ${relationship.permissions.entries.where((entry) => entry.value).map((entry) => entry.key).toList().ifEmpty('none')}',
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
                    child: const Text('Manage permissions'),
                  ),
                  TextButton(
                    onPressed: () => _revoke(relationship),
                    child: const Text('Revoke access'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
        title: const Text('Partner Access'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const Text(
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
                          const Text(
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
                          const SizedBox(height: 6),
                          Text(
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
                    label: Text(
                      hasActive
                          ? 'An active partner is already linked'
                          : 'Generate invitation',
                    ),
                  ),
                ),
                _sectionTitle('Requests and linked partners'),
                if (visible.isEmpty)
                  const Card(
                    color: AppColors.white,
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No linking requests or active partners.',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                  ),
                ...visible.map(_relationshipCard),
                const SizedBox(height: 12),
                const Text(
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

class PartnerPermissionManagementScreen extends StatefulWidget {
  final Map<String, bool> permissions;

  const PartnerPermissionManagementScreen({
    super.key,
    required this.permissions,
  });

  @override
  State<PartnerPermissionManagementScreen> createState() =>
      _PartnerPermissionManagementScreenState();
}

class _PartnerPermissionManagementScreenState
    extends State<PartnerPermissionManagementScreen> {
  late final Map<String, bool> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = defaultPartnerPermissions()..addAll(widget.permissions);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const Text('Manage sharing permissions'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Only enabled categories will be available to the linked partner.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 10),
        ..._permissions.keys.map(
          (permission) => SwitchListTile(
            value: _permissions[permission]!,
            activeThumbColor: AppColors.burgundy,
            title: Text(permission),
            onChanged: (value) =>
                setState(() => _permissions[permission] = value),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _permissions),
          child: const Text('Save permissions'),
        ),
      ],
    ),
  );
}

extension on Iterable<String> {
  String ifEmpty(String value) => isEmpty ? value : join(', ');
}
