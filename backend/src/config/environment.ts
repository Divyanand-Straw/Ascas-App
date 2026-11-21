import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

export const loadBackendEnvironment = (
  backendDirectory = path.resolve(__dirname, '../..')
): string => {
  const configuredFile = process.env.THAAI_BACKEND_ENV_FILE?.trim();
  const isDevelopmentLaunch =
    process.env.npm_lifecycle_event === 'dev' ||
    process.env.APP_ENV === 'development';
  const envFile = configuredFile
    ? path.resolve(process.cwd(), configuredFile)
    : isDevelopmentLaunch
      ? path.resolve(backendDirectory, '.env.development.local')
      : path.resolve(backendDirectory, '.env');

  if (!fs.existsSync(envFile)) {
    throw new Error('Backend environment file was not found.');
  }

  const result = dotenv.config({
    path: envFile,
    override: Boolean(configuredFile) || isDevelopmentLaunch,
    quiet: true,
  });
  if (result.error) {
    throw new Error('Backend environment file could not be loaded.');
  }
  return envFile;
};
