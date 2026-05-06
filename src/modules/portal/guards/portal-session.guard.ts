import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class PortalSessionGuard implements CanActivate {
  constructor(private readonly databaseService: DatabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const token = request.cookies?.crm_portal_session || request.headers['authorization']?.replace('Bearer ', '');

    if (!token) {
      throw new UnauthorizedException('Missing portal session token');
    }

    try {
      const payload: any = await this.databaseService.callDispatcher('fn_portal_operations', {
        operation: 'validate_session',
        token
      });

      if (!payload || !payload.valid) {
        throw new UnauthorizedException('Invalid or expired portal session');
      }

      request.portalUser = { token, ...payload.sessionData };
      return true;
    } catch (error) {
      throw new UnauthorizedException('Invalid portal session');
    }
  }
}
