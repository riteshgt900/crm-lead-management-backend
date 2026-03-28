import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: any, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const exceptionResponse = exception instanceof HttpException 
      ? exception.getResponse() 
      : { message: exception.message, rid: 'e-internal-error' };

    const rid = (exceptionResponse as any).rid || (status === 401 ? 'e-unauthorized' : status === 403 ? 'e-forbidden' : 'e-internal-error');

    response.status(status).json({
      rid,
      statusCode: status,
      data: null,
      message: typeof exceptionResponse === 'string' ? exceptionResponse : (exceptionResponse as any).message || 'Internal server error',
      errors: (exceptionResponse as any).errors || null,
      meta: {
        timestamp: new Date().toISOString(),
      },
    });
  }
}
