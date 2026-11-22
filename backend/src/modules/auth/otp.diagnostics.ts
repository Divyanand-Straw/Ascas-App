export const maskMobileNumber = (phone: string | undefined): string => {
  const digits = phone?.replace(/\D/g, '') ?? '';
  return digits.length >= 4 ? `***${digits.slice(-4)}` : '****';
};
