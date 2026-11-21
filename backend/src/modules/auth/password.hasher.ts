import bcrypt from 'bcryptjs';
import { ValidationError } from '../../utils/errors';

export interface IPasswordHasher {
  hash(password: string): Promise<string>;
  verify(password: string, passwordHash: string): Promise<boolean>;
}

export class BcryptPasswordHasher implements IPasswordHasher {
  private readonly rounds = 12;

  async hash(password: string): Promise<string> {
    this.validateByteLength(password);
    return bcrypt.hash(password, this.rounds);
  }

  async verify(password: string, passwordHash: string): Promise<boolean> {
    if (Buffer.byteLength(password, 'utf8') > 72) return false;
    return bcrypt.compare(password, passwordHash);
  }

  private validateByteLength(password: string): void {
    if (Buffer.byteLength(password, 'utf8') > 72) {
      throw new ValidationError('Password must not exceed 72 UTF-8 bytes.');
    }
  }
}
