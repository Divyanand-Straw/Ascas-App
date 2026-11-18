enum OtpPurpose {
  login,
  registration,
  linkedMember;

  String toApiString() {
    switch (this) {
      case OtpPurpose.login:
        return 'LOGIN';
      case OtpPurpose.registration:
        return 'REGISTRATION';
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
      case 'LINKED_MEMBER':
        return OtpPurpose.linkedMember;
      default:
        return OtpPurpose.login;
    }
  }
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
    return SendOtpResponse(
      challengeId: json['challengeId'] as String? ?? '',
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 300,
      retryAfterSeconds: json['retryAfterSeconds'] as int? ?? 45,
    );
  }
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
        if (deviceInfo != null && deviceInfo!.isNotEmpty)
          'deviceInfo': deviceInfo,
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
  final String role;
  final String status;

  AuthUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.status,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'PATIENT',
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}

class PatientProfileData {
  final String id;
  final String firstName;
  final String lastName;
  final String? dob;
  final String? clinicMrn;
  final String preferredLanguage;
  final String linkingStatus;

  PatientProfileData({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.dob,
    this.clinicMrn,
    required this.preferredLanguage,
    required this.linkingStatus,
  });

  factory PatientProfileData.fromJson(Map<String, dynamic> json) {
    return PatientProfileData(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      dob: json['dob'] as String?,
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
          ? PatientProfileData.fromJson(
              json['profile'] as Map<String, dynamic>)
          : null,
      tokens:
          AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>? ?? {}),
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
          ? PatientProfileData.fromJson(
              json['profile'] as Map<String, dynamic>)
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
      errorCode: data?['errorCode'] as String? ?? 'UNKNOWN_ERROR',
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
  String toString() => 'ApiError($statusCode, $errorCode: $message)';
}
