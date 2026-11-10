import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PartnerLinkStatus {
  invitation,
  pending,
  rejected,
  active,
  revoked,
  expired,
}

class PartnerRelationship {
  final String linkId;
  final String patientUserId;
  final String patientId;
  final String patientName;
  final String patientMobile;
  final String patientState;
  final String partnerUserId;
  final String partnerName;
  final String partnerMobile;
  final String relationshipType;
  final String invitationCode;
  final DateTime invitationExpiry;
  final PartnerLinkStatus status;
  final Map<String, bool> permissions;
  final DateTime? patientConsentTimestamp;
  final DateTime? partnerAcceptanceTimestamp;
  final String clinicApprovalStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? revokedAt;

  const PartnerRelationship({
    required this.linkId,
    required this.patientUserId,
    required this.patientId,
    required this.patientName,
    required this.patientMobile,
    required this.patientState,
    required this.partnerUserId,
    required this.partnerName,
    required this.partnerMobile,
    required this.relationshipType,
    required this.invitationCode,
    required this.invitationExpiry,
    required this.status,
    required this.permissions,
    required this.patientConsentTimestamp,
    required this.partnerAcceptanceTimestamp,
    required this.clinicApprovalStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.revokedAt,
  });

  PartnerRelationship copyWith({
    PartnerLinkStatus? status,
    Map<String, bool>? permissions,
    String? partnerUserId,
    String? partnerName,
    String? partnerMobile,
    DateTime? patientConsentTimestamp,
    DateTime? partnerAcceptanceTimestamp,
    DateTime? updatedAt,
    DateTime? revokedAt,
  }) => PartnerRelationship(
    linkId: linkId,
    patientUserId: patientUserId,
    patientId: patientId,
    patientName: patientName,
    patientMobile: patientMobile,
    patientState: patientState,
    partnerUserId: partnerUserId ?? this.partnerUserId,
    partnerName: partnerName ?? this.partnerName,
    partnerMobile: partnerMobile ?? this.partnerMobile,
    relationshipType: relationshipType,
    invitationCode: invitationCode,
    invitationExpiry: invitationExpiry,
    status: status ?? this.status,
    permissions: permissions ?? this.permissions,
    patientConsentTimestamp:
        patientConsentTimestamp ?? this.patientConsentTimestamp,
    partnerAcceptanceTimestamp:
        partnerAcceptanceTimestamp ?? this.partnerAcceptanceTimestamp,
    clinicApprovalStatus: clinicApprovalStatus,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revokedAt: revokedAt ?? this.revokedAt,
  );

  Map<String, Object?> toJson() => {
    'link_id': linkId,
    'patient_user_id': patientUserId,
    'patient_id': patientId,
    'patient_name': patientName,
    'patient_mobile': patientMobile,
    'patient_state': patientState,
    'partner_user_id': partnerUserId,
    'partner_name': partnerName,
    'partner_mobile': partnerMobile,
    'relationship_type': relationshipType,
    'invitation_code': invitationCode,
    'invitation_expiry': invitationExpiry.toIso8601String(),
    'linking_status': status.name,
    'permission_settings': permissions,
    'patient_consent_timestamp': patientConsentTimestamp?.toIso8601String(),
    'partner_acceptance_timestamp': partnerAcceptanceTimestamp
        ?.toIso8601String(),
    'clinic_approval_status': clinicApprovalStatus,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'revoked_at': revokedAt?.toIso8601String(),
  };

  factory PartnerRelationship.fromJson(Map<String, dynamic> json) {
    final permissions = (json['permission_settings'] as Map?)?.map(
      (key, value) => MapEntry(key.toString(), value == true),
    );
    return PartnerRelationship(
      linkId: json['link_id'] as String,
      patientUserId: json['patient_user_id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String,
      patientMobile: json['patient_mobile'] as String,
      patientState: json['patient_state'] as String,
      partnerUserId: json['partner_user_id'] as String? ?? '',
      partnerName: json['partner_name'] as String? ?? '',
      partnerMobile: json['partner_mobile'] as String? ?? '',
      relationshipType: json['relationship_type'] as String,
      invitationCode: json['invitation_code'] as String,
      invitationExpiry: DateTime.parse(json['invitation_expiry'] as String),
      status: PartnerLinkStatus.values.firstWhere(
        (status) => status.name == json['linking_status'],
      ),
      permissions: permissions ?? defaultPartnerPermissions(),
      patientConsentTimestamp: _date(json['patient_consent_timestamp']),
      partnerAcceptanceTimestamp: _date(json['partner_acceptance_timestamp']),
      clinicApprovalStatus: json['clinic_approval_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      revokedAt: _date(json['revoked_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

const partnerPermissionLabels = [
  'Patient profile information',
  'Treatment Journey',
  'Appointments',
  'Medication schedules',
  'Prescriptions',
  'Medical Reports',
  'Discharge Summary',
  'Bills and Payments',
  'IP Billing',
  'Notifications and clinic updates',
];

Map<String, bool> defaultPartnerPermissions() => {
  for (final label in partnerPermissionLabels) label: false,
};

class PartnerLinkService {
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static const _storageKey = 'partner_link_relationships_v1';
  static const invitationLifetime = Duration(days: 7);
  static const _codeCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<List<PartnerRelationship>> _readAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) return [];
    final rows = jsonDecode(encoded) as List<dynamic>;
    return rows
        .map(
          (row) => PartnerRelationship.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> _writeAll(List<PartnerRelationship> relationships) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(
        relationships.map((relationship) => relationship.toJson()).toList(),
      ),
    );
    changes.value++;
  }

  Future<PartnerRelationship> generateInvitation({
    required String patientUserId,
    required String patientId,
    required String patientName,
    required String patientMobile,
    required String patientState,
    DateTime? now,
  }) async {
    if (patientUserId.isEmpty || patientName.trim().isEmpty) {
      throw StateError('A patient account and name are required.');
    }
    final current = now ?? DateTime.now();
    final relationships = await _readAll();
    final existing = relationships.where(
      (relationship) =>
          (relationship.patientUserId == patientUserId ||
              relationship.patientId == patientId) &&
          relationship.status == PartnerLinkStatus.active,
    );
    if (existing.isNotEmpty) {
      throw StateError(
        'Revoke the active partner link before inviting another partner.',
      );
    }
    for (var index = 0; index < relationships.length; index++) {
      final relationship = relationships[index];
      if ((relationship.patientUserId == patientUserId ||
              relationship.patientId == patientId) &&
          relationship.status == PartnerLinkStatus.invitation) {
        relationships[index] = relationship.copyWith(
          status: PartnerLinkStatus.expired,
          updatedAt: current,
        );
      }
    }
    final random = Random.secure();
    String code;
    do {
      code = List.generate(
        8,
        (_) => _codeCharacters[random.nextInt(_codeCharacters.length)],
      ).join();
    } while (relationships.any(
      (relationship) => relationship.invitationCode == code,
    ));
    final relationship = PartnerRelationship(
      linkId: 'link-${current.microsecondsSinceEpoch}-$code',
      patientUserId: patientUserId,
      patientId: patientId,
      patientName: patientName.trim(),
      patientMobile: patientMobile,
      patientState: patientState,
      partnerUserId: '',
      partnerName: '',
      partnerMobile: '',
      relationshipType: 'partner',
      invitationCode: code,
      invitationExpiry: current.add(invitationLifetime),
      status: PartnerLinkStatus.invitation,
      permissions: defaultPartnerPermissions(),
      patientConsentTimestamp: null,
      partnerAcceptanceTimestamp: null,
      clinicApprovalStatus: 'not_required',
      createdAt: current,
      updatedAt: current,
      revokedAt: null,
    );
    relationships.add(relationship);
    await _writeAll(relationships);
    return relationship;
  }

  Future<PartnerRelationship> validateInvitation(
    String code, {
    DateTime? now,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw StateError('Enter an invitation code.');
    }
    final relationships = await _readAll();
    final index = relationships.indexWhere(
      (relationship) =>
          relationship.invitationCode == normalized &&
          relationship.status == PartnerLinkStatus.invitation,
    );
    if (index < 0) {
      throw StateError('Invitation is invalid or has already been used.');
    }
    final invitation = relationships[index];
    if (!(now ?? DateTime.now()).isBefore(invitation.invitationExpiry)) {
      relationships[index] = invitation.copyWith(
        status: PartnerLinkStatus.expired,
        updatedAt: now ?? DateTime.now(),
      );
      await _writeAll(relationships);
      throw StateError('This invitation has expired.');
    }
    return invitation;
  }

  Future<PartnerRelationship> submitRequest({
    required String code,
    required String partnerName,
    required String partnerMobile,
    String? partnerUserId,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final relationships = await _readAll();
    final index = relationships.indexWhere(
      (relationship) =>
          relationship.invitationCode == code.trim().toUpperCase() &&
          relationship.status == PartnerLinkStatus.invitation,
    );
    if (index < 0) {
      throw StateError('Invitation is invalid or has already been used.');
    }
    final invitation = relationships[index];
    if (!current.isBefore(invitation.invitationExpiry)) {
      relationships[index] = invitation.copyWith(
        status: PartnerLinkStatus.expired,
        updatedAt: current,
      );
      await _writeAll(relationships);
      throw StateError('This invitation has expired.');
    }
    if (partnerName.trim().isEmpty ||
        !RegExp(r'^[6-9]\d{9}$').hasMatch(partnerMobile)) {
      throw StateError(
        'Enter a partner name and verified 10-digit mobile number.',
      );
    }
    if (partnerMobile == invitation.patientMobile) {
      throw StateError('The partner must use a separate mobile number.');
    }
    if (relationships.any(
      (relationship) =>
          relationship.partnerMobile == partnerMobile &&
          relationship.status == PartnerLinkStatus.active,
    )) {
      throw StateError(
        'This partner account already has an active patient link.',
      );
    }
    final updated = invitation.copyWith(
      status: PartnerLinkStatus.active,
      partnerUserId: partnerUserId ?? 'user:$partnerMobile',
      partnerName: partnerName.trim(),
      partnerMobile: partnerMobile,
      patientConsentTimestamp: invitation.createdAt,
      partnerAcceptanceTimestamp: current,
      updatedAt: current,
    );
    relationships[index] = updated;
    await _writeAll(relationships);
    return updated;
  }

  Future<List<PartnerRelationship>> forPatient(
    String patientUserId, {
    String legacyPatientId = '',
  }) async {
    final relationships = await _readAll();
    return relationships
        .where(
          (relationship) =>
              relationship.patientUserId == patientUserId ||
              (legacyPatientId.isNotEmpty &&
                  relationship.patientId == legacyPatientId),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<PartnerRelationship>> forPartner(String partnerMobile) async {
    final relationships = await _readAll();
    return relationships
        .where((relationship) => relationship.partnerMobile == partnerMobile)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<PartnerRelationship> _update(
    String linkId,
    PartnerRelationship Function(PartnerRelationship relationship) update,
  ) async {
    final relationships = await _readAll();
    final index = relationships.indexWhere(
      (relationship) => relationship.linkId == linkId,
    );
    if (index < 0) throw StateError('The linking request could not be found.');
    relationships[index] = update(relationships[index]);
    await _writeAll(relationships);
    return relationships[index];
  }

  Future<PartnerRelationship> approveRequest(String linkId) async {
    final relationships = await _readAll();
    final index = relationships.indexWhere(
      (relationship) => relationship.linkId == linkId,
    );
    if (index < 0) throw StateError('The linking request could not be found.');
    final request = relationships[index];
    if (request.status != PartnerLinkStatus.pending) {
      throw StateError('Only a pending request can be approved.');
    }
    if (relationships.any(
      (relationship) =>
          relationship.linkId != linkId &&
          relationship.status == PartnerLinkStatus.active &&
          (relationship.patientUserId == request.patientUserId ||
              relationship.partnerUserId == request.partnerUserId),
    )) {
      throw StateError(
        'An active relationship already exists for this account.',
      );
    }
    final current = DateTime.now();
    final active = request.copyWith(
      status: PartnerLinkStatus.active,
      permissions: Map<String, bool>.from(request.permissions),
      patientConsentTimestamp: current,
      updatedAt: current,
    );
    relationships[index] = active;
    await _writeAll(relationships);
    return active;
  }

  Future<PartnerRelationship> rejectRequest(String linkId) =>
      _update(linkId, (relationship) {
        if (relationship.status != PartnerLinkStatus.pending) {
          throw StateError('Only a pending request can be rejected.');
        }
        return relationship.copyWith(
          status: PartnerLinkStatus.rejected,
          updatedAt: DateTime.now(),
        );
      });

  Future<PartnerRelationship> savePermissions(
    String linkId,
    Map<String, bool> permissions,
  ) => _update(linkId, (relationship) {
    if (relationship.status != PartnerLinkStatus.active) {
      throw StateError('Permissions can only be changed for an active link.');
    }
    final validated = defaultPartnerPermissions();
    for (final entry in permissions.entries) {
      if (validated.containsKey(entry.key)) validated[entry.key] = entry.value;
    }
    return relationship.copyWith(
      permissions: validated,
      updatedAt: DateTime.now(),
    );
  });

  Future<PartnerRelationship> revokeAccess(String linkId) =>
      _update(linkId, (relationship) {
        if (relationship.status != PartnerLinkStatus.active) {
          throw StateError('Only an active link can be revoked.');
        }
        final current = DateTime.now();
        return relationship.copyWith(
          status: PartnerLinkStatus.revoked,
          revokedAt: current,
          updatedAt: current,
        );
      });

  Future<PartnerRelationship?> activeLinkForPartner(
    String partnerMobile, {
    String? partnerUserId,
  }) async {
    final links = await forPartner(partnerMobile);
    for (final relationship in links) {
      if (relationship.status == PartnerLinkStatus.active &&
          (partnerUserId == null ||
              relationship.partnerUserId == partnerUserId)) {
        return relationship;
      }
    }
    return null;
  }

  Future<bool> isCategoryAuthorized({
    required String partnerMobile,
    required String category,
  }) async {
    final relationship = await activeLinkForPartner(partnerMobile);
    return relationship != null && relationship.permissions[category] == true;
  }
}
