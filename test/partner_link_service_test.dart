import 'package:app/features/partner_access/data/partner_link_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PartnerLinkService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = PartnerLinkService();
  });

  Future<PartnerRelationship> createInvitation({DateTime? now}) =>
      service.generateInvitation(
        patientUserId: 'patient-account-1',
        patientId: 'TS-1001',
        patientName: 'Patient One',
        patientMobile: '9876543210',
        patientState: 'ivf',
        now: now,
      );

  test(
    'accepting an invitation activates a link, sharing, and revocation',
    () async {
      final invitation = await createInvitation();
      final validated = await service.validateInvitation(
        invitation.invitationCode,
      );
      expect(validated.patientName, 'Patient One');

      final request = await service.submitRequest(
        code: invitation.invitationCode,
        partnerName: 'Partner One',
        partnerMobile: '9123456780',
      );
      expect(request.status, PartnerLinkStatus.active);
      expect(request.patientConsentTimestamp, invitation.createdAt);
      expect(request.partnerAcceptanceTimestamp, isNotNull);
      expect(
        await service.activeLinkForPartner(
          '9123456780',
          partnerUserId: request.partnerUserId,
        ),
        isNotNull,
      );
      expect(
        await service.isCategoryAuthorized(
          partnerMobile: '9123456780',
          category: 'Appointments',
        ),
        isFalse,
      );

      final patientRequests = await service.forPatient('patient-account-1');
      expect(patientRequests.single.partnerName, 'Partner One');
      expect(
        await service.isCategoryAuthorized(
          partnerMobile: '9123456780',
          category: 'Appointments',
        ),
        isFalse,
      );

      await service.savePermissions(request.linkId, {
        'Appointments': true,
        'Unrecognized category': true,
      });
      expect(
        await service.isCategoryAuthorized(
          partnerMobile: '9123456780',
          category: 'Appointments',
        ),
        isTrue,
      );
      expect(
        await service.isCategoryAuthorized(
          partnerMobile: '9123456780',
          category: 'Medical Reports',
        ),
        isFalse,
      );

      await service.revokeAccess(request.linkId);
      expect(await service.activeLinkForPartner('9123456780'), isNull);
      expect(
        await service.isCategoryAuthorized(
          partnerMobile: '9123456780',
          category: 'Appointments',
        ),
        isFalse,
      );
      expect(
        (await service.forPatient('patient-account-1')).first.status,
        PartnerLinkStatus.revoked,
      );
    },
  );

  test(
    'expired invitations are persisted as expired and cannot be reused',
    () async {
      final now = DateTime(2026, 1, 1);
      final invitation = await createInvitation(now: now);

      await expectLater(
        service.validateInvitation(
          invitation.invitationCode,
          now: now.add(const Duration(days: 8)),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await service.forPatient('patient-account-1')).single.status,
        PartnerLinkStatus.expired,
      );
      await expectLater(
        service.submitRequest(
          code: invitation.invitationCode,
          partnerName: 'Partner One',
          partnerMobile: '9123456780',
          now: now.add(const Duration(days: 8)),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('invalid, reused, and same-mobile invitations are rejected', () async {
    final invitation = await createInvitation();
    await expectLater(
      service.validateInvitation('NOTACODE'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.submitRequest(
        code: invitation.invitationCode,
        partnerName: 'Patient One',
        partnerMobile: '9876543210',
      ),
      throwsA(isA<StateError>()),
    );

    final request = await service.submitRequest(
      code: invitation.invitationCode,
      partnerName: 'Partner One',
      partnerMobile: '9123456780',
    );
    await expectLater(
      service.submitRequest(
        code: invitation.invitationCode,
        partnerName: 'Partner One',
        partnerMobile: '9123456780',
      ),
      throwsA(isA<StateError>()),
    );
    expect(request.status, PartnerLinkStatus.active);
  });

  test(
    'active invitation links prevent duplicate active partner links',
    () async {
      final secondInvitation = await service.generateInvitation(
        patientUserId: 'patient-account-2',
        patientId: 'TS-1002',
        patientName: 'Patient Two',
        patientMobile: '9876543211',
        patientState: 'iui',
      );
      final activeLink = await service.submitRequest(
        code: secondInvitation.invitationCode,
        partnerName: 'Partner One',
        partnerMobile: '9123456780',
      );
      expect(activeLink.status, PartnerLinkStatus.active);

      final thirdInvitation = await service.generateInvitation(
        patientUserId: 'patient-account-3',
        patientId: 'TS-1003',
        patientName: 'Patient Three',
        patientMobile: '9876543212',
        patientState: 'fet',
      );
      await expectLater(
        service.submitRequest(
          code: thirdInvitation.invitationCode,
          partnerName: 'Partner One',
          partnerMobile: '9123456780',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}
