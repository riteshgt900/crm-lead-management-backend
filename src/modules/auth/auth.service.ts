import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

@Injectable()
export class AuthService {
  constructor(private readonly db: DatabaseService) {}

  async login(dto: LoginDto) {
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
