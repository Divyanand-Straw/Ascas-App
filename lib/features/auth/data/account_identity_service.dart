import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum AccountRole { patient, partner }

class AccountIdentity {
  final String accountId;
  final String mobileNumber;
  final String fullName;
  final String dateOfBirth;
  final String patientId;
  final String preferredLanguage;
  final AccountRole role;

  const AccountIdentity({
    required this.accountId,
    required this.mobileNumber,
    required this.fullName,
    required this.dateOfBirth,
    required this.patientId,
    required this.preferredLanguage,
    required this.role,
  });

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'mobile_number': mobileNumber,
    'full_name': fullName,
    'date_of_birth': dateOfBirth,
    'patient_id': patientId,
    'preferred_language': preferredLanguage,
    'role': role.name,
  };

  factory AccountIdentity.fromJson(Map<String, dynamic> json) =>
      AccountIdentity(
        accountId: json['account_id'] as String,
        mobileNumber: json['mobile_number'] as String,
        fullName: json['full_name'] as String,
        dateOfBirth: json['date_of_birth'] as String? ?? '',
        patientId: json['patient_id'] as String? ?? '',
        preferredLanguage: json['preferred_language'] as String? ?? 'English',
        role: AccountRole.values.firstWhere(
          (role) => role.name == json['role'],
        ),
      );
}

class AccountIdentityService {
  static Future<void> _writeTail = Future<void>.value();
  static const _accountsKey = 'prototype_account_identities_v1';

  Future<T> _serialize<T>(Future<T> Function() action) {
    final previous = _writeTail;
    final completed = Completer<void>();
    _writeTail = completed.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        completed.complete();
      }
    }();
  }

  Future<List<AccountIdentity>> _readAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_accountsKey);
    if (encoded == null) return [];
    final rows = jsonDecode(encoded) as List<dynamic>;
    return rows
        .map(
          (row) =>
              AccountIdentity.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> _writeAccounts(List<AccountIdentity> accounts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  String _normalizeMobile(String mobileNumber) {
    final normalized = mobileNumber.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(normalized)) {
      throw StateError('A verified 10-digit mobile number is required.');
    }
    return normalized;
  }

  String accountIdForMobile(String mobileNumber) =>
      'user:${_normalizeMobile(mobileNumber)}';

  String _generatePatientId(List<AccountIdentity> accounts) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random.secure();
    final existingIds = accounts.map((account) => account.patientId).toSet();

    for (var attempt = 0; attempt < 100; attempt++) {
      final id =
          'TS-'
          '${letters[random.nextInt(letters.length)]}'
          '${letters[random.nextInt(letters.length)]}'
          '${random.nextInt(1000).toString().padLeft(3, '0')}';
      if (!existingIds.contains(id)) return id;
    }

    throw StateError('Unable to generate a unique patient ID.');
  }

  Future<AccountIdentity?> accountForMobile(String mobileNumber) async {
    final normalized = _normalizeMobile(mobileNumber);
    for (final account in await _readAccounts()) {
      if (account.mobileNumber == normalized) return account;
    }
    return null;
  }

  Future<AccountIdentity> createOrGetNewPatient({
    required String mobileNumber,
    required String fullName,
    required String dateOfBirth,
    required String preferredLanguage,
  }) => _serialize(() async {
    final mobile = _normalizeMobile(mobileNumber);
    if (fullName.trim().isEmpty) {
      throw StateError('A patient name is required.');
    }
    final accounts = await _readAccounts();
    for (final account in accounts) {
      if (account.mobileNumber == mobile) {
        if (account.role != AccountRole.patient) {
          throw StateError(
            'This mobile number belongs to a separate partner account.',
          );
        }
        return account;
      }
    }
    final identity = AccountIdentity(
      accountId: 'user:$mobile',
      mobileNumber: mobile,
      fullName: fullName.trim(),
      dateOfBirth: dateOfBirth,
      patientId: _generatePatientId(accounts),
      preferredLanguage: preferredLanguage,
      role: AccountRole.patient,
    );
    accounts.add(identity);
    await _writeAccounts(accounts);
    return identity;
  });

  Future<AccountIdentity> resolveExistingPatient({
    required String mobileNumber,
    required String patientId,
    required String dateOfBirth,
  }) => _serialize(() async {
    final mobile = _normalizeMobile(mobileNumber);
    final normalizedPatientId = patientId.trim().toUpperCase();
    final normalizedDob = _dateKey(dateOfBirth);
    if (normalizedPatientId.isEmpty || normalizedDob == null) {
      throw StateError('Enter the patient ID and a valid date of birth.');
    }

    final accounts = await _readAccounts();
    for (final account in accounts) {
      if (account.mobileNumber == mobile) {
        if (account.role != AccountRole.patient ||
            account.patientId.toUpperCase() != normalizedPatientId ||
            _dateKey(account.dateOfBirth) != normalizedDob) {
          throw StateError(
            'The patient ID or date of birth does not match this mobile account.',
          );
        }
        return account;
      }
      if (account.patientId == normalizedPatientId) {
        throw StateError(
          'This clinic record is already linked to a different mobile account.',
        );
      }
    }
    throw StateError(
      'No matching existing patient record is saved on this device. Clinic account verification requires the clinic service.',
    );
  });

  String? _dateKey(String value) {
    final normalized = value.trim();
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(normalized);
    final dayFirst = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$')
        .firstMatch(normalized);
    if (iso == null && dayFirst == null) return null;
    final parts = iso ?? dayFirst!;
    final year = int.parse(parts.group(iso != null ? 1 : 3)!);
    final month = int.parse(parts.group(2)!);
    final day = int.parse(parts.group(iso != null ? 3 : 1)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<AccountIdentity> createOrGetPartner({
    required String mobileNumber,
    required String fullName,
  }) => _serialize(() async {
    final mobile = _normalizeMobile(mobileNumber);
    if (fullName.trim().isEmpty) {
      throw StateError('A partner account name is required.');
    }
    final accounts = await _readAccounts();
    for (final account in accounts) {
      if (account.mobileNumber == mobile) {
        if (account.role != AccountRole.partner) {
          throw StateError(
            'This mobile number already belongs to a patient account.',
          );
        }
        return account;
      }
    }
    final identity = AccountIdentity(
      accountId: 'user:$mobile',
      mobileNumber: mobile,
      fullName: fullName.trim(),
      dateOfBirth: '',
      patientId: '',
      preferredLanguage: 'English',
      role: AccountRole.partner,
    );
    accounts.add(identity);
    await _writeAccounts(accounts);
    return identity;
  });
}
