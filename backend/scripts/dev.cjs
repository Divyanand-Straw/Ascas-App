const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const dotenv = require('dotenv');

const backendDirectory = path.resolve(__dirname, '..');
const configuredFile = process.env.THAAI_BACKEND_ENV_FILE
  ? process.env.THAAI_BACKEND_ENV_FILE.trim()
  : '';
const environmentFile = configuredFile
  ? path.resolve(process.cwd(), configuredFile)
  : path.join(backendDirectory, '.env.development.local');

if (!fs.existsSync(environmentFile)) {
  throw new Error('Development backend environment file was not found.');
}

const developmentEnvironment = dotenv.parse(
  fs.readFileSync(environmentFile)
);
if (developmentEnvironment.APP_ENV !== 'development') {
  throw new Error(
    'Development backend environment must set APP_ENV=development.'
  );
}

const childEnvironment = { ...process.env };
const inheritedEnvironmentFiles = new Set([
  path.join(backendDirectory, '.env'),
  path.resolve(process.cwd(), '.env'),
]);
if (process.env.DOTENV_CONFIG_PATH?.trim()) {
  inheritedEnvironmentFiles.add(
    path.resolve(process.cwd(), process.env.DOTENV_CONFIG_PATH.trim())
  );
}
for (const file of inheritedEnvironmentFiles) {
  if (!fs.existsSync(file)) continue;
  for (const key of Object.keys(dotenv.parse(fs.readFileSync(file)))) {
    delete childEnvironment[key];
  }
}
for (const key of Object.keys(childEnvironment)) {
  if (key.startsWith('STAGING_')) delete childEnvironment[key];
}

childEnvironment.APP_ENV = 'development';
childEnvironment.NODE_ENV = 'development';
childEnvironment.THAAI_BACKEND_ENV_FILE = environmentFile;
childEnvironment.DOTENV_CONFIG_PATH = environmentFile;

console.info(`Development environment file: ${path.basename(environmentFile)}`);

if (process.argv.includes('--print-environment-file')) {
  process.exitCode = 0;
} else {
  const tsxCli = require.resolve('tsx/cli');
  const child = spawn(
    process.execPath,
    [tsxCli, 'watch', 'src/server.ts'],
    {
      cwd: backendDirectory,
      env: childEnvironment,
      stdio: 'inherit',
    }
  );
  child.on('error', (error) => {
    console.error('Development backend failed to start.', error);
    process.exitCode = 1;
  });
  child.on('exit', (code, signal) => {
    process.exitCode = signal ? 1 : (code ?? 1);
  });
}
