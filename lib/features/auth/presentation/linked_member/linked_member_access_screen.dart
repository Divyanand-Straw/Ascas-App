import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/account_identity_service.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';
import '../../../partner_access/data/partner_link_service.dart';

class LinkedMemberAccessScreen extends StatefulWidget {
  final String mobileNumber;

  const LinkedMemberAccessScreen({super.key, required this.mobileNumber});

  @override
  State<LinkedMemberAccessScreen> createState() =>
      _LinkedMemberAccessScreenState();
}

class _LinkedMemberAccessScreenState extends State<LinkedMemberAccessScreen> {
  final _service = PartnerLinkService();
  final _accounts = AccountIdentityService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  PartnerRelationship? _invitation;
  List<PartnerRelationship> _relationships = [];
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
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final relationships = await _service.forPartner(widget.mobileNumber);
    if (!mounted) return;
    setState(() {
      _relationships = relationships;
      _invitation = null;
    });
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  Future<void> _validateInvitation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _working = true);
    try {
      final invitation = await _service.validateInvitation(
        _codeController.text,
      );
      if (!mounted) return;
      setState(() => _invitation = invitation);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submitRequest() async {
    final invitation = _invitation;
    if (invitation == null) return;
    setState(() => _working = true);
    try {
      final partner = await _accounts.createOrGetPartner(
        mobileNumber: widget.mobileNumber,
        fullName: _nameController.text,
      );
      final link = await _service.submitRequest(
        code: _codeController.text,
        partnerName: partner.fullName,
        partnerMobile: partner.mobileNumber,
        partnerUserId: partner.accountId,
      );
      await _refresh();
      if (!mounted) return;
      _openActiveLink(link);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _openActiveLink(PartnerRelationship relationship) {
    final patientState = DashboardPatientState.values.firstWhere(
      (state) => state.name == relationship.patientState,
      orElse: () => DashboardPatientState.newPatient,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          patientName: relationship.patientName,
          patientId: relationship.patientId,
          patientState: patientState,
          mobileNumber: relationship.patientMobile,
          accountId: relationship.partnerUserId,
          isLinkedPartner: true,
          partnerUserName: relationship.partnerName,
          partnerMobile: relationship.partnerMobile,
          partnerPermissions: relationship.permissions,
          partnerLinkId: relationship.linkId,
          dataOwnerAccountId: relationship.patientUserId,
        ),
      ),
    );
  }

  Widget _linkCard(PartnerRelationship relationship) {
    final active = relationship.status == PartnerLinkStatus.active;
    final status = switch (relationship.status) {
      PartnerLinkStatus.invitation => 'Invitation entered',
      PartnerLinkStatus.pending => 'Request pending',
      PartnerLinkStatus.rejected => 'Request rejected',
      PartnerLinkStatus.active => 'Link active',
      PartnerLinkStatus.revoked => 'Link revoked',
      PartnerLinkStatus.expired => 'Invitation expired',
    };
    return Card(
      color: AppColors.white,
      elevation: 0,
      child: ListTile(
        leading: Icon(
          active ? Icons.verified_user_rounded : Icons.hourglass_top_rounded,
          color: AppColors.burgundy,
        ),
        title: LocalizedText('${relationship.patientName} · $status'),
        subtitle: Text(
          active
              ? 'Patient ID: ${relationship.patientId.isEmpty ? 'Not provided' : relationship.patientId}'
              : relationship.status == PartnerLinkStatus.pending
              ? 'Awaiting patient approval.'
              : 'No active patient link.',
        ),
        trailing: active
            ? IconButton(
                tooltip: 'View linked patient',
                onPressed: () => _openActiveLink(relationship),
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _relationships.where(
      (relationship) => relationship.status == PartnerLinkStatus.active,
    );
    final pending = _relationships.where(
      (relationship) => relationship.status == PartnerLinkStatus.pending,
    );
    final otherStatuses = _relationships.where(
      (relationship) =>
          relationship.status != PartnerLinkStatus.active &&
          relationship.status != PartnerLinkStatus.pending,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const LocalizedText('Link to Patient'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const LocalizedText(
            'Use your own account and mobile number. Confirm a patient-issued invitation to activate your link.',
            style: TextStyle(color: AppColors.secondaryText, height: 1.5),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText('Partner account · ${widget.mobileNumber}'),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Patient invitation code',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter the invitation code.'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _working ? null : _validateInvitation,
                      child: const LocalizedText('Validate invitation'),
                    ),
                  ),
                  if (_invitation != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.blushPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LocalizedText(
                            'Confirm the patient',
                            style: TextStyle(
                              color: AppColors.burgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(_invitation!.patientName),
                          if (_invitation!.patientId.isNotEmpty)
                            LocalizedText(
                              'Patient ID: ${_invitation!.patientId}',
                            ),
                          const SizedBox(height: 8),
                          const LocalizedText(
                            'Confirming this invitation activates your link to the patient.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _working ? null : _submitRequest,
                              child: const LocalizedText('Accept invitation'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const LocalizedText(
            'Your linking status',
            style: TextStyle(
              color: AppColors.burgundy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const LocalizedText('Refresh status'),
          ),
          ...active.map(_linkCard),
          ...pending.map(_linkCard),
          ...otherStatuses.map(_linkCard),
          if (_relationships.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: LocalizedText(
                'No linked patient. Accept a patient invitation to link your account.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
          const SizedBox(height: 10),
          const LocalizedText(
            'Prototype only: account identity and link state are local and are not authenticated by a server.',
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
