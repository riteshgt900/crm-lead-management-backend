import { Injectable, UnauthorizedException } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { LoginDto } from './dto/login.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

@Injectable()
export class AuthService {
  constructor(private db: DatabaseService) {}

  async login(dto: LoginDto) {
    // In a real app, we'd hash check the password here if not handled in SQL
    // But architecture says ALL logic in SQL. 
    // However, bcrypt is usually done in JS for CPU salt safety.
    // I will assume the dispatcher handles the user lookup and returns the hash if needed,
    // or better, the dispatcher handles the login entirely.
    
    return this.db.callDispatcher('fn_auth_operations', {
      operation: 'login',
      data: dto,
    });
  }

  async logout(token: string) {
    return this.db.callDispatcher('fn_auth_operations', {
      operation: 'logout',
      data: { token },
    });
  }

  async getProfile(userId: string) {
    return this.db.callDispatcher('fn_auth_operations', {
      operation: 'get_profile',
      data: { userId },
    });
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    return this.db.callDispatcher('fn_auth_operations', {
      operation: 'forgot_password',
      data: dto,
    });
  }

  async resetPassword(dto: ResetPasswordDto) {
    return this.db.callDispatcher('fn_auth_operations', {
      operation: 'reset_password',
      data: dto,
    });
  }

  async validateSession(token: string) {
    return this.db.callDispatcher('fn_auth_operations', {
      operation: 'validate_session',
      data: { token },
    });
  }
}
