import { z } from 'zod';
import { normalizeEmailAddress } from './auth.types';
import { phoneSchema } from './auth.schema';

export const emailOtpPurposeSchema = z.enum([
  'PASSWORD_RESET',
  'EMAIL_CHANGE',
]);

export const emailAddressSchema = z
  .string()
  .trim()
  .max(320, 'Email address is too long')
  .email('Please provide a valid email address')
  .transform((email) => normalizeEmailAddress(email));

export const sendEmailOtpSchema = z.object({
  email: emailAddressSchema,
  purpose: z.literal('EMAIL_CHANGE'),
});

export const sendPasswordResetOtpSchema = z.object({
  phone: phoneSchema,
  email: emailAddressSchema,
});

export const verifyEmailOtpSchema = z.object({
  challengeId: z.string().uuid('Challenge ID must be a valid UUID'),
  email: emailAddressSchema,
  purpose: emailOtpPurposeSchema,
  otp: z.string().regex(/^\d{6}$/, 'OTP must be exactly 6 digits'),
});

export const sendEmailActivationOtpSchema = z.object({
  email: emailAddressSchema,
});

export const verifyEmailActivationOtpSchema = z.object({
  challengeId: z.string().uuid('Challenge ID must be a valid UUID'),
  email: emailAddressSchema,
  otp: z.string().regex(/^\d{6}$/, 'OTP must be exactly 6 digits'),
});

export const sendDeveloperEmailTestOtpSchema = z.object({
  email: emailAddressSchema,
});

export const verifyDeveloperEmailTestOtpSchema = z.object({
  challengeId: z.string().uuid('Challenge ID must be a valid UUID'),
  email: emailAddressSchema,
  otp: z.string().regex(/^\d{6}$/, 'OTP must be exactly 6 digits'),
});

export type SendEmailOtpInput = z.infer<typeof sendEmailOtpSchema>;
export type SendPasswordResetOtpInput = z.infer<
  typeof sendPasswordResetOtpSchema
>;
export type VerifyEmailOtpInput = z.infer<typeof verifyEmailOtpSchema>;
export type SendEmailActivationOtpInput = z.infer<
  typeof sendEmailActivationOtpSchema
>;
export type VerifyEmailActivationOtpInput = z.infer<
  typeof verifyEmailActivationOtpSchema
>;
export type SendDeveloperEmailTestOtpInput = z.infer<
  typeof sendDeveloperEmailTestOtpSchema
>;
export type VerifyDeveloperEmailTestOtpInput = z.infer<
  typeof verifyDeveloperEmailTestOtpSchema
>;
