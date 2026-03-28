import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Injectable()
export class ResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      map((res) => {
        // If it's already an envelope (from DB dispatcher), return as is
        if (res && res.rid && res.statusCode) {
          return res;
        }

        const statusCode = context.switchToHttp().getResponse().statusCode;
        
        return {
          rid: `s-success`,
          statusCode,
          data: res || null,
          message: 'Operation successful',
          meta: {
            timestamp: new Date().toISOString(),
          },
        };
      }),
    );
  }
}
