import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { loadBackendEnvironment } from '../src/config/environment';

describe('backend environment loading', () => {
  it('selects the development-local file for npm run dev and honors an explicit override', () => {
    const backendDirectory = fs.mkdtempSync(
      path.join(os.tmpdir(), 'ascas-backend-env-')
    );
    const originalDirectory = process.cwd();
    const keys = [
      'APP_ENV',
      'NODE_ENV',
      'npm_lifecycle_event',
      'DOTENV_CONFIG_PATH',
      'THAAI_BACKEND_ENV_FILE',
      'DATABASE_URL',
      'DEV_EMAIL_ALLOW_ANY_RECIPIENT',
    ];
    const previous = new Map(keys.map((key) => [key, process.env[key]]));

    fs.writeFileSync(
      path.join(backendDirectory, '.env'),
      [
        'APP_ENV=staging',
        'STAGING_DATABASE_URL=staging-database',
        'STAGING_BREVO_ENABLED=true',
        'BREVO_API_KEY=staging-api-key',
      ].join('\n')
    );
    fs.writeFileSync(
      path.join(backendDirectory, '.env.development.local'),
      [
        'APP_ENV=development',
        'NODE_ENV=development',
        'DATABASE_URL=local-test-database',
        'DEV_EMAIL_ALLOW_ANY_RECIPIENT=true',
        'DEV_EMAIL_ALLOWED_RECIPIENTS=',
      ].join('\n')
    );
    fs.writeFileSync(
      path.join(backendDirectory, 'custom-development.env'),
      ['APP_ENV=development', 'DATABASE_URL=custom-local-database'].join('\n')
    );

    try {
      process.chdir(backendDirectory);
      delete process.env.THAAI_BACKEND_ENV_FILE;
      Object.assign(process.env, {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        npm_lifecycle_event: 'dev',
        DOTENV_CONFIG_PATH: '.env',
      });

      assert.equal(
        loadBackendEnvironment(backendDirectory),
        path.join(backendDirectory, '.env.development.local')
      );

      assert.equal(process.env.APP_ENV, 'development');
      assert.equal(process.env.NODE_ENV, 'development');
      assert.equal(process.env.DATABASE_URL, 'local-test-database');
      assert.equal(process.env.DEV_EMAIL_ALLOW_ANY_RECIPIENT, 'true');

      process.env.THAAI_BACKEND_ENV_FILE = 'custom-development.env';
      assert.equal(
        loadBackendEnvironment(backendDirectory),
        path.join(backendDirectory, 'custom-development.env')
      );
      assert.equal(process.env.DATABASE_URL, 'custom-local-database');

      const startup = spawnSync(
        process.execPath,
        ['scripts/dev.cjs', '--print-environment-file'],
        {
          cwd: path.resolve(__dirname, '..'),
          encoding: 'utf8',
          env: {
            ...process.env,
            DOTENV_CONFIG_PATH: path.resolve(
              __dirname,
              '..',
              '.env'
            ),
            NODE_OPTIONS: '--require dotenv/config',
            THAAI_BACKEND_ENV_FILE: path.join(
              backendDirectory,
              'custom-development.env'
            ),
          },
        }
      );
      assert.equal(startup.status, 0, startup.stderr);
      assert.equal(
        startup.stdout.trim(),
        'Development environment file: custom-development.env'
      );
      assert.equal(startup.stdout.includes('staging'), false);
    } finally {
      process.chdir(originalDirectory);
      for (const [key, value] of previous) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
      fs.rmSync(backendDirectory, { recursive: true, force: true });
    }
  });
});
