import { z } from 'zod';

/**
 * Normalizes phone numbers to standard E.164 format (+91XXXXXXXXXX).
 * Accepts 10-digit numbers (assumes +91) or international format.
 */
export const normalizePhoneNumber = (input: string): string => {
  const clean = input.replace(/[\s\-\(\)]/g, '').trim();
  if (/^[6-9]\d{9}$/.test(clean)) {
    return `+91${clean}`;
  }
  if (/^\+?[1-9]\d{9,14}$/.test(clean)) {
    return clean.startsWith('+') ? clean : `+${clean}`;
  }
  return clean;
};

export const phoneSchema = z
  .string()
  .min(10, 'Phone number must have at least 10 digits')
  .max(16, 'Phone number is too long')
  .transform((val) => normalizePhoneNumber(val))
  .refine((val) => /^\+[1-9]\d{9,14}$/.test(val), {
    message: 'Invalid phone number format. Provide a valid mobile number.',
  });

export const otpPurposeSchema = z.enum(['LOGIN', 'REGISTRATION', 'LINKED_MEMBER']);

export const sendOtpSchema = z.object({
  phone: phoneSchema,
  purpose: otpPurposeSchema,
});

export const verifyOtpSchema = z.object({
  challengeId: z.string().min(1, 'Challenge ID is required'),
  phone: phoneSchema,
  purpose: otpPurposeSchema,
  otp: z.string().regex(/^\d{6}$/, 'OTP must be exactly 6 digits'),
  deviceInfo: z.string().max(255).optional(),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export const logoutSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export type SendOtpInput = z.infer<typeof sendOtpSchema>;
export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>;
export type RefreshTokenInput = z.infer<typeof refreshTokenSchema>;
export type LogoutInput = z.infer<typeof logoutSchema>;
