enum OtpPurpose {
  login,
  registration,
  existingPatient,
  linkedMember;

  String toApiString() {
    switch (this) {
      case OtpPurpose.login:
        return 'LOGIN';
      case OtpPurpose.registration:
        return 'REGISTRATION';
      case OtpPurpose.existingPatient:
        return 'EXISTING_PATIENT';
      case OtpPurpose.linkedMember:
        return 'LINKED_MEMBER';
    }
  }

  static OtpPurpose fromApiString(String value) {
    switch (value.toUpperCase()) {
      case 'LOGIN':
        return OtpPurpose.login;
      case 'REGISTRATION':
        return OtpPurpose.registration;
      case 'EXISTING_PATIENT':
        return OtpPurpose.existingPatient;
      case 'LINKED_MEMBER':
        return OtpPurpose.linkedMember;
      default:
        throw FormatException('Unsupported mobile OTP purpose: $value');
    }
  }
}

enum EmailOtpPurpose {
  passwordReset,
  emailChange;

  String toApiString() {
    switch (this) {
      case EmailOtpPurpose.passwordReset:
        return 'PASSWORD_RESET';
      case EmailOtpPurpose.emailChange:
        return 'EMAIL_CHANGE';
    }
  }

  static EmailOtpPurpose fromApiString(String value) {
    switch (value.toUpperCase()) {
      case 'PASSWORD_RESET':
        return EmailOtpPurpose.passwordReset;
      case 'EMAIL_CHANGE':
        return EmailOtpPurpose.emailChange;
      default:
        throw FormatException('Unsupported email OTP purpose: $value');
    }
  }
}

String normalizeEmail(String email) => email.trim().toLowerCase();

enum PendingRegistrationStep {
  credentials,
  patientDetails;

  String get storageValue {
    switch (this) {
      case PendingRegistrationStep.credentials:
        return 'credentials';
      case PendingRegistrationStep.patientDetails:
        return 'patientDetails';
    }
  }

  static PendingRegistrationStep? fromStorageValue(String value) {
    switch (value) {
      case 'credentials':
        return PendingRegistrationStep.credentials;
      case 'patientDetails':
        return PendingRegistrationStep.patientDetails;
      default:
        return null;
    }
  }
}

class PendingNewPatientRegistration {
  final String userId;
  final PendingRegistrationStep step;
  final String email;

  const PendingNewPatientRegistration({
    required this.userId,
    required this.step,
    required this.email,
  });
}

class SendOtpRequest {
  final String phone;
  final OtpPurpose purpose;

  SendOtpRequest({required this.phone, required this.purpose});

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'purpose': purpose.toApiString(),
  };
}

class SendEmailOtpRequest {
  final String email;
  final EmailOtpPurpose purpose;

  SendEmailOtpRequest({required this.email, required this.purpose});

  Map<String, dynamic> toJson() => {
    'email': normalizeEmail(email),
    'purpose': purpose.toApiString(),
  };
}

class PasswordResetOtpRequest {
  final String phone;
  final String email;

  const PasswordResetOtpRequest({required this.phone, required this.email});

  Map<String, dynamic> toJson() => {
    'phone': _normalizePhoneNumber(phone),
    'email': normalizeEmail(email),
  };
}

String _normalizePhoneNumber(String phone) {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
  if (RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) return '+91$cleaned';
  if (RegExp(r'^\+?[1-9]\d{9,14}$').hasMatch(cleaned)) {
    return cleaned.startsWith('+') ? cleaned : '+$cleaned';
  }
  return cleaned;
}

class SendEmailActivationOtpRequest {
  final String email;

  SendEmailActivationOtpRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': normalizeEmail(email)};
}

class DeveloperEmailTestOtpRequest {
  final String email;

  DeveloperEmailTestOtpRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': normalizeEmail(email)};
}

class VerifyDeveloperEmailTestOtpRequest {
  final String challengeId;
  final String email;
  final String otp;

  VerifyDeveloperEmailTestOtpRequest({
    required this.challengeId,
    required this.email,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
    'challengeId': challengeId,
    'email': normalizeEmail(email),
    'otp': otp,
  };
}

class SendEmailOtpResponse {
  final String challengeId;
  final int expiresInSeconds;
  final int retryAfterSeconds;

  const SendEmailOtpResponse({
    required this.challengeId,
    required this.expiresInSeconds,
    required this.retryAfterSeconds,
  });

  factory SendEmailOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendEmailOtpResponse(
      challengeId: _requiredString(json, 'challengeId'),
      expiresInSeconds: _requiredInt(json, 'expiresInSeconds'),
      retryAfterSeconds: _requiredInt(json, 'retryAfterSeconds'),
    );
  }
}

class DeveloperEmailTestOtpVerificationResponse {
  const DeveloperEmailTestOtpVerificationResponse();

  factory DeveloperEmailTestOtpVerificationResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    if (_requiredString(json, 'purpose') != 'DEVELOPER_EMAIL_TEST' ||
        json['verified'] != true) {
      throw const FormatException(
        'Developer email test OTP verification was not successful.',
      );
    }
    return const DeveloperEmailTestOtpVerificationResponse();
  }
}

class VerifyEmailOtpRequest {
  final String challengeId;
  final String email;
  final EmailOtpPurpose purpose;
  final String otp;

  VerifyEmailOtpRequest({
    required this.challengeId,
    required this.email,
    required this.purpose,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
    'challengeId': challengeId,
    'email': normalizeEmail(email),
    'purpose': purpose.toApiString(),
    'otp': otp,
  };
}

sealed class VerifyEmailOtpResponse {
  const VerifyEmailOtpResponse();

  factory VerifyEmailOtpResponse.fromJson(Map<String, dynamic> json) {
    final purpose = EmailOtpPurpose.fromApiString(
      _requiredString(json, 'purpose'),
    );
    if (json['verified'] != true) {
      throw const FormatException('Email OTP verification was not successful.');
    }
    switch (purpose) {
      case EmailOtpPurpose.passwordReset:
        return PasswordResetOtpVerificationResponse(
          resetGrant: _requiredString(json, 'resetGrant'),
          expiresInSeconds: _requiredInt(json, 'expiresInSeconds'),
        );
      case EmailOtpPurpose.emailChange:
        return EmailChangeOtpVerificationResponse(
          email: normalizeEmail(_requiredString(json, 'email')),
        );
    }
  }
}

class PasswordResetOtpVerificationResponse extends VerifyEmailOtpResponse {
  final String resetGrant;
  final int expiresInSeconds;

  const PasswordResetOtpVerificationResponse({
    required this.resetGrant,
    required this.expiresInSeconds,
  });
}

class EmailChangeOtpVerificationResponse extends VerifyEmailOtpResponse {
  final String email;

  const EmailChangeOtpVerificationResponse({required this.email});
}

class VerifyEmailActivationOtpRequest {
  final String challengeId;
  final String email;
  final String otp;

  VerifyEmailActivationOtpRequest({
    required this.challengeId,
    required this.email,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
    'challengeId': challengeId,
    'email': normalizeEmail(email),
    'otp': otp,
  };
}

class EmailActivationOtpVerificationResponse {
  const EmailActivationOtpVerificationResponse();

  factory EmailActivationOtpVerificationResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    if (json['purpose'] != 'ACCOUNT_ACTIVATION' || json['verified'] != true) {
      throw const FormatException(
        'Email activation verification was not successful.',
      );
    }
    return const EmailActivationOtpVerificationResponse();
  }
}

class EmailPasswordLoginRequest {
  final String email;
  final String password;
  final String? deviceInfo;

  const EmailPasswordLoginRequest({
    required this.email,
    required this.password,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() => {
    'email': normalizeEmail(email),
    'password': password,
    if (deviceInfo != null && deviceInfo!.isNotEmpty) 'deviceInfo': deviceInfo,
  };
}

class SetupPasswordRequest {
  final String password;

  const SetupPasswordRequest({required this.password});

  Map<String, dynamic> toJson() => {'password': password};
}

class SetupRegistrationCredentialsRequest {
  final String email;
  final String password;

  const SetupRegistrationCredentialsRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': normalizeEmail(email),
    'password': password,
  };
}

class CompletePasswordResetRequest {
  final String resetGrant;
  final String newPassword;

  const CompletePasswordResetRequest({
    required this.resetGrant,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'resetGrant': resetGrant,
    'newPassword': newPassword,
  };
}

class SendOtpResponse {
  final String challengeId;
  final int expiresInSeconds;
  final int retryAfterSeconds;

  SendOtpResponse({
    required this.challengeId,
    required this.expiresInSeconds,
    required this.retryAfterSeconds,
  });

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    final expiresInSeconds = _requiredInt(json, 'expiresInSeconds');
    final retryAfterSeconds = _requiredInt(json, 'retryAfterSeconds');
    if (expiresInSeconds < 0 || retryAfterSeconds < 0) {
      throw const FormatException(
        'OTP expiry and retry delays must not be negative.',
      );
    }
    return SendOtpResponse(
      challengeId: _requiredString(json, 'challengeId'),
      expiresInSeconds: expiresInSeconds,
      retryAfterSeconds: retryAfterSeconds,
    );
  }
}

class SavePatientProfileRequest {
  final String firstName;
  final String lastName;
  final String dob;
  final String? gender;
  final String emergencyContact;
  final String preferredLanguage;

  const SavePatientProfileRequest({
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.emergencyContact,
    this.gender,
    required this.preferredLanguage,
  });

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'dob': dob,
    'emergencyContact': emergencyContact,
    if (gender?.isNotEmpty == true) 'gender': gender,
    'preferredLanguage': preferredLanguage,
  };
}

class VerifyOtpRequest {
  final String challengeId;
  final String phone;
  final OtpPurpose purpose;
  final String otp;
  final String? deviceInfo;

  VerifyOtpRequest({
    required this.challengeId,
    required this.phone,
    required this.purpose,
    required this.otp,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() => {
    'challengeId': challengeId,
    'phone': phone,
    'purpose': purpose.toApiString(),
    'otp': otp,
    if (deviceInfo != null && deviceInfo!.isNotEmpty) 'deviceInfo': deviceInfo,
  };
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresIn: json['expiresIn'] as int? ?? 900,
    );
  }
}

class AuthUser {
  final String id;
  final String phone;
  final String? email;
  final String role;
  final String status;

  AuthUser({
    required this.id,
    required this.phone,
    this.email,
    required this.role,
    required this.status,
  });

  AuthUser copyWith({String? email}) => AuthUser(
    id: id,
    phone: phone,
    email: email ?? this.email,
    role: role,
    status: status,
  );

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'PATIENT',
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}

class PatientProfileData {
  final String id;
  final String? userId;
  final String firstName;
  final String lastName;
  final String? dob;
  final String? gender;
  final String? emergencyContact;
  final String? clinicMrn;
  final String preferredLanguage;
  final String linkingStatus;

  PatientProfileData({
    required this.id,
    this.userId,
    required this.firstName,
    required this.lastName,
    this.dob,
    this.gender,
    this.emergencyContact,
    this.clinicMrn,
    required this.preferredLanguage,
    required this.linkingStatus,
  });

  factory PatientProfileData.fromJson(Map<String, dynamic> json) {
    return PatientProfileData(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String?,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      dob: json['dob'] as String?,
      gender: json['gender'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      clinicMrn: json['clinicMrn'] as String?,
      preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
      linkingStatus: json['linkingStatus'] as String? ?? 'UNLINKED',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class AuthSession {
  final AuthUser user;
  final PatientProfileData? profile;
  final AuthTokens tokens;
  final bool isNewUser;
  final bool hasCompletedProfile;

  AuthSession({
    required this.user,
    this.profile,
    required this.tokens,
    required this.isNewUser,
    required this.hasCompletedProfile,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      profile: json['profile'] != null
          ? PatientProfileData.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      tokens: AuthTokens.fromJson(
        json['tokens'] as Map<String, dynamic>? ?? {},
      ),
      isNewUser: json['isNewUser'] as bool? ?? false,
      hasCompletedProfile: json['hasCompletedProfile'] as bool? ?? false,
    );
  }
}

class CurrentUserResponse {
  final AuthUser user;
  final PatientProfileData? profile;
  final bool hasCompletedProfile;

  CurrentUserResponse({
    required this.user,
    this.profile,
    required this.hasCompletedProfile,
  });

  factory CurrentUserResponse.fromJson(Map<String, dynamic> json) {
    return CurrentUserResponse(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      profile: json['profile'] != null
          ? PatientProfileData.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      hasCompletedProfile: json['hasCompletedProfile'] as bool? ?? false,
    );
  }
}

class ApiError implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;
  final dynamic details;

  ApiError({
    required this.statusCode,
    required this.errorCode,
    required this.message,
    this.details,
  });

  factory ApiError.fromResponse(int statusCode, Map<String, dynamic>? data) {
    return ApiError(
      statusCode: statusCode,
      errorCode:
          data?['errorCode'] as String? ??
          data?['code'] as String? ??
          'UNKNOWN_ERROR',
      message: data?['message'] as String? ?? 'An unexpected error occurred.',
      details: data?['details'],
    );
  }

  int? get remainingAttempts {
    if (details is Map && details['remainingAttempts'] != null) {
      return details['remainingAttempts'] as int?;
    }
    return null;
  }

  int? get retryAfterSeconds {
    if (details is Map && details['retryAfterSeconds'] != null) {
      return details['retryAfterSeconds'] as int?;
    }
    return null;
  }

  @override
  String toString() => message;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Expected a non-empty "$key" string.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected an integer "$key".');
}
