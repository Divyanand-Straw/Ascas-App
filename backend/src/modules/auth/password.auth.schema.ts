import { z } from 'zod';
import { normalizeEmailAddress } from './auth.types';

const emailAddressSchema = z
  .string()
  .trim()
  .max(320, 'Email address is too long')
  .email('Please provide a valid email address')
  .transform((email) => normalizeEmailAddress(email));

const passwordByteLimit = (password: string): boolean =>
  Buffer.byteLength(password, 'utf8') <= 72;

const newPasswordSchema = z
  .string()
  .min(12, 'Password must be at least 12 characters')
  .max(128, 'Password is too long')
  .refine(passwordByteLimit, 'Password must not exceed 72 UTF-8 bytes');

const loginPasswordSchema = z
  .string()
  .min(1, 'Password is required')
  .max(128, 'Password is too long')
  .refine(passwordByteLimit, 'Password must not exceed 72 UTF-8 bytes');

export const setupPasswordSchema = z.object({
  password: newPasswordSchema,
});

export const setupRegistrationCredentialsSchema = z
  .object({
    email: emailAddressSchema,
    password: newPasswordSchema,
  })
  .strict();

export const emailPasswordLoginSchema = z.object({
  email: emailAddressSchema,
  password: loginPasswordSchema,
  deviceInfo: z.string().max(255).optional(),
});

export const completePasswordResetSchema = z.object({
  resetGrant: z.string().regex(/^[A-Za-z0-9_-]{43}$/, 'Reset grant is invalid'),
  newPassword: newPasswordSchema,
});

export type SetupPasswordInput = z.infer<typeof setupPasswordSchema>;
export type SetupRegistrationCredentialsInput = z.infer<
  typeof setupRegistrationCredentialsSchema
>;
export type EmailPasswordLoginInput = z.infer<
  typeof emailPasswordLoginSchema
>;
export type CompletePasswordResetInput = z.infer<
  typeof completePasswordResetSchema
>;
