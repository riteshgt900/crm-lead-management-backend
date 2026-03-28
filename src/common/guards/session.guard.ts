import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { DatabaseService } from '../../database/database.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class SessionGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private db: DatabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const token = request.cookies['crm_session'];

    if (!token) {
      throw new UnauthorizedException({ rid: 'e-unauthorized', message: 'Session expired or missing' });
    }

    const result = await this.db.callDispatcher('fn_auth_operations', {
      operation: 'validate_session',
      data: { token },
    });

    if (result.statusCode !== 200) {
      throw new UnauthorizedException({ rid: result.rid, message: result.message });
    }

    request.user = result.data;
    return true;
  }
}
