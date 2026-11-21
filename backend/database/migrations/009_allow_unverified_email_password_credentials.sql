ALTER TABLE users
  DROP CONSTRAINT IF EXISTS chk_users_password_requires_verified_email;
