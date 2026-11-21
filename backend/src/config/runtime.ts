export type AuthRepositoryMode =
  | 'development'
  | 'development-persistent'
  | 'staging'
  | 'production';

type Environment = Readonly<Record<string, string | undefined>>;

const isConfigured = (value: string | undefined): boolean =>
  Boolean(value?.trim());

const hasProductionDatabaseUrl = (env: Environment): boolean => {
  const url = env.DATABASE_URL?.trim();
  return Boolean(url && url !== 'your_supabase_connection_string');
};

export const assertStagingEnvironment = (env: Environment = process.env): void => {
  if (env.APP_ENV !== 'staging') {
    throw new Error('APP_ENV=staging is required for staging configuration.');
  }
  if (env.NODE_ENV === 'production') {
    throw new Error('APP_ENV=staging cannot be combined with NODE_ENV=production.');
  }
};

export const getStagingDatabaseUrl = (
  env: Environment = process.env
): string => {
  assertStagingEnvironment(env);

  if (hasProductionDatabaseUrl(env)) {
    throw new Error(
      'DATABASE_URL must be unset in staging; use STAGING_DATABASE_URL.'
    );
  }
  if (env.STAGING_DATABASE_DISPOSABLE !== 'true') {
    throw new Error(
      'STAGING_DATABASE_DISPOSABLE must be explicitly set to true.'
    );
  }

  const databaseUrl = env.STAGING_DATABASE_URL?.trim();
  if (!databaseUrl) {
    throw new Error('STAGING_DATABASE_URL is required in staging.');
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(databaseUrl);
  } catch {
    throw new Error('STAGING_DATABASE_URL is invalid.');
  }

  let databaseName: string;
  try {
    databaseName = decodeURIComponent(
      parsedUrl.pathname.split('/').filter(Boolean).pop() ?? ''
    );
  } catch {
    throw new Error('STAGING_DATABASE_URL is invalid.');
  }
  const isPostgres =
    parsedUrl.protocol === 'postgresql:' || parsedUrl.protocol === 'postgres:';
  const isLoopback =
    parsedUrl.hostname === 'localhost' ||
    parsedUrl.hostname === '127.0.0.1';
  const hasDisposableDatabaseName =
    /(?:_dev|_development|_test|_staging)$/i.test(databaseName);

  if (!isPostgres || !isLoopback || !hasDisposableDatabaseName) {
    throw new Error(
      'STAGING_DATABASE_URL must target a loopback PostgreSQL database whose name ends in _dev, _development, _test, or _staging.'
    );
  }

  return databaseUrl;
};

export const getLocalDevelopmentDatabaseUrl = (
  env: Environment = process.env
): string => {
  if (
    env.APP_ENV !== 'development' ||
    env.NODE_ENV !== 'development' ||
    env.DEV_PERSISTENT_AUTH !== 'true'
  ) {
    throw new Error(
      'Persistent local auth requires APP_ENV=development, NODE_ENV=development, and DEV_PERSISTENT_AUTH=true.'
    );
  }
  if (env.STAGING_DATABASE_URL?.trim()) {
    throw new Error(
      'STAGING_DATABASE_URL must be unset in local development.'
    );
  }

  const databaseUrl = env.DATABASE_URL?.trim();
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required for persistent local auth.');
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(databaseUrl);
  } catch {
    throw new Error('DATABASE_URL is invalid for persistent local auth.');
  }

  let databaseName: string;
  try {
    databaseName = decodeURIComponent(
      parsedUrl.pathname.split('/').filter(Boolean).pop() ?? ''
    );
  } catch {
    throw new Error('DATABASE_URL is invalid for persistent local auth.');
  }
  const isPostgres =
    parsedUrl.protocol === 'postgresql:' || parsedUrl.protocol === 'postgres:';
  const isLoopback =
    parsedUrl.hostname === 'localhost' ||
    parsedUrl.hostname === '127.0.0.1';

  if (!isPostgres || !isLoopback || databaseName !== 'thaai_seyali_test') {
    throw new Error(
      'Persistent local auth DATABASE_URL must target loopback PostgreSQL database thaai_seyali_test.'
    );
  }

  return databaseUrl;
};

export const getStagingEmailAllowedRecipients = (
  env: Environment = process.env
): string[] => {
  if (isStagingEmailAnyRecipientEnabled(env)) {
    return [];
  }

  return getStagingEmailAllowlist(env);
};

const assertStagingEmailDeliveryConfigured = (
  env: Environment
): void => {
  assertStagingEnvironment(env);

  if (env.STAGING_BREVO_ENABLED !== 'true') {
    throw new Error('STAGING_BREVO_ENABLED must be explicitly set to true.');
  }
  for (const key of [
    'BREVO_API_KEY',
    'BREVO_SENDER_EMAIL',
    'BREVO_SENDER_NAME',
  ]) {
    if (!isConfigured(env[key])) {
      throw new Error(`${key} is required for staging email delivery.`);
    }
  }
  const senderEmail = env.BREVO_SENDER_EMAIL?.trim();
  if (!senderEmail || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(senderEmail)) {
    throw new Error('BREVO_SENDER_EMAIL must be a valid email address.');
  }
};

export const isStagingEmailAnyRecipientEnabled = (
  env: Environment = process.env
): boolean => {
  assertStagingEmailDeliveryConfigured(env);
  if (
    env.STAGING_EMAIL_ALLOW_ANY_RECIPIENT !== undefined &&
    env.STAGING_EMAIL_ALLOW_ANY_RECIPIENT !== 'true' &&
    env.STAGING_EMAIL_ALLOW_ANY_RECIPIENT !== 'false'
  ) {
    throw new Error(
      'STAGING_EMAIL_ALLOW_ANY_RECIPIENT must be true or false.'
    );
  }
  return env.STAGING_EMAIL_ALLOW_ANY_RECIPIENT === 'true';
};

const getStagingEmailAllowlist = (
  env: Environment
): string[] => {
  const recipients = (env.STAGING_EMAIL_ALLOWED_RECIPIENTS ?? '')
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean);
  if (
    recipients.length === 0 ||
    recipients.some((email) => !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email))
  ) {
    throw new Error(
      'STAGING_EMAIL_ALLOWED_RECIPIENTS must contain one or more valid email addresses.'
    );
  }

  return [...new Set(recipients)];
};

export const getDevelopmentEmailAllowedRecipients = (
  env: Environment = process.env
): string[] => {
  if (isDevelopmentEmailAnyRecipientEnabled(env)) {
    return [];
  }

  const recipients = (env.DEV_EMAIL_ALLOWED_RECIPIENTS ?? '')
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean);
  if (
    recipients.length === 0 ||
    recipients.some((email) => !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email))
  ) {
    throw new Error(
      'DEV_EMAIL_ALLOWED_RECIPIENTS must contain one or more valid email addresses.'
    );
  }

  return [...new Set(recipients)];
};

const assertDevelopmentEmailDeliveryEnabled = (
  env: Environment
): void => {
  if (
    env.APP_ENV !== 'development' ||
    env.NODE_ENV !== 'development' ||
    !isDeveloperEmailOtpTestEnabled(env)
  ) {
    throw new Error(
      'Development Brevo delivery requires the developer email OTP test feature.'
    );
  }
};

export const isDevelopmentEmailAnyRecipientEnabled = (
  env: Environment = process.env
): boolean => {
  assertDevelopmentEmailDeliveryEnabled(env);
  const allowAnyRecipient = env.DEV_EMAIL_ALLOW_ANY_RECIPIENT;
  if (
    allowAnyRecipient !== undefined &&
    allowAnyRecipient !== 'true' &&
    allowAnyRecipient !== 'false'
  ) {
    throw new Error('DEV_EMAIL_ALLOW_ANY_RECIPIENT must be true or false.');
  }
  return allowAnyRecipient === 'true';
};

export const isDeveloperEmailOtpTestEnabled = (
  env: Environment = process.env
): boolean => {
  if (
    env.APP_ENV === 'staging' &&
    env.NODE_ENV !== 'production' &&
    env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED === 'true'
  ) {
    return true;
  }
  if (
    env.APP_ENV === 'development' &&
    env.NODE_ENV === 'development' &&
    env.DEV_EMAIL_OTP_TEST_ENABLED === 'true' &&
    env.DEV_PERSISTENT_AUTH === 'true'
  ) {
    getLocalDevelopmentDatabaseUrl(env);
    return true;
  }
  return false;
};

export interface StagingDeveloperEmailOtpRateLimits {
  maxRequestsPerHourPerEmail: number;
  maxRequestsPerHourPerIp: number;
}

const getPositiveIntegerSetting = (
  env: Environment,
  key: string,
  defaultValue: number
): number => {
  const configuredValue = env[key]?.trim();
  if (!configuredValue) return defaultValue;
  if (!/^[1-9]\d*$/.test(configuredValue)) {
    throw new Error(`${key} must be a positive safe integer.`);
  }
  const value = Number(configuredValue);
  if (!Number.isSafeInteger(value)) {
    throw new Error(`${key} must be a positive safe integer.`);
  }
  return value;
};

export const getStagingDeveloperEmailOtpRateLimits = (
  env: Environment = process.env
): StagingDeveloperEmailOtpRateLimits => {
  if (env.APP_ENV === 'staging') {
    assertStagingEnvironment(env);
  } else if (!isDeveloperEmailOtpTestEnabled(env)) {
    assertStagingEnvironment(env);
  }
  return {
    maxRequestsPerHourPerEmail: getPositiveIntegerSetting(
      env,
      'STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL',
      5
    ),
    maxRequestsPerHourPerIp: getPositiveIntegerSetting(
      env,
      'STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP',
      15
    ),
  };
};

export interface DevelopmentOtpViewerConfig {
  secret: string;
  allowedPhones: ReadonlySet<string>;
}

export const isDevelopmentOtpTerminalLoggingEnabled = (
  env: Environment = process.env
): boolean =>
  env.DEV_OTP_TERMINAL_LOG_ENABLED === 'true' &&
  env.NODE_ENV === 'development' &&
  env.APP_ENV === 'development';

export const getDevelopmentOtpViewerConfig = (
  env: Environment = process.env
): DevelopmentOtpViewerConfig | null => {
  const enabled = env.DEV_OTP_VIEWER_ENABLED;
  if (!enabled || enabled === 'false') {
    return null;
  }
  if (enabled !== 'true') {
    throw new Error('DEV_OTP_VIEWER_ENABLED must be true or false.');
  }
  if (
    env.NODE_ENV === 'production' ||
    (env.APP_ENV !== 'development' && env.APP_ENV !== 'staging')
  ) {
    throw new Error(
      'The development OTP viewer is available only in development or staging.'
    );
  }

  const secret = env.DEV_OTP_VIEWER_SECRET?.trim();
  if (!secret || !/^[A-Za-z0-9_-]{43,}$/.test(secret)) {
    throw new Error(
      'DEV_OTP_VIEWER_SECRET must be at least 43 base64url characters.'
    );
  }
  if (
    secret === env.JWT_ACCESS_SECRET?.trim() ||
    secret === env.OTP_SECRET?.trim()
  ) {
    throw new Error(
      'DEV_OTP_VIEWER_SECRET must be different from authentication secrets.'
    );
  }

  const allowedPhones = (env.DEV_OTP_VIEWER_ALLOWED_PHONES ?? '')
    .split(',')
    .map((phone) => phone.trim())
    .filter(Boolean);
  if (
    allowedPhones.length === 0 ||
    allowedPhones.some((phone) => !/^\+[1-9]\d{9,14}$/.test(phone))
  ) {
    throw new Error(
      'DEV_OTP_VIEWER_ALLOWED_PHONES must contain E.164 test numbers.'
    );
  }

  return {
    secret,
    allowedPhones: new Set(allowedPhones),
  };
};

export const getAuthRepositoryMode = (
  env: Environment = process.env
): AuthRepositoryMode => {
  if (
    env.DEV_PERSISTENT_AUTH !== undefined &&
    env.DEV_PERSISTENT_AUTH !== 'true' &&
    env.DEV_PERSISTENT_AUTH !== 'false'
  ) {
    throw new Error('DEV_PERSISTENT_AUTH must be true or false.');
  }
  if (env.DEV_PERSISTENT_AUTH === 'true') {
    getLocalDevelopmentDatabaseUrl(env);
    return 'development-persistent';
  }
  if (env.APP_ENV === 'staging') {
    getStagingDatabaseUrl(env);
    return 'staging';
  }
  if (env.NODE_ENV === 'production') {
    return 'production';
  }
  if (env.NODE_ENV === 'staging') {
    throw new Error(
      'NODE_ENV=staging is ambiguous; use APP_ENV=staging with explicit staging configuration.'
    );
  }
  return 'development';
};

export const requiresConfiguredAuthSecrets = (
  env: Environment = process.env
): boolean => env.NODE_ENV === 'production' || env.APP_ENV === 'staging';

export const resolveDatabaseUrl = (
  env: Environment = process.env
): string | undefined =>
  env.DEV_PERSISTENT_AUTH === 'true'
    ? getLocalDevelopmentDatabaseUrl(env)
    : env.APP_ENV === 'staging'
      ? getStagingDatabaseUrl(env)
      : env.DATABASE_URL?.trim();

export const getConfiguredDatabaseName = (
  env: Environment = process.env
): string => {
  const databaseUrl = resolveDatabaseUrl(env);
  if (!databaseUrl) return 'not configured';

  try {
    const databaseName = decodeURIComponent(
      new URL(databaseUrl).pathname.split('/').filter(Boolean).pop() ?? ''
    );
    return databaseName || 'unknown';
  } catch {
    return 'invalid';
  }
};
