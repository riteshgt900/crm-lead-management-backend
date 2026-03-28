import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as cookieParser from 'cookie-parser';
import { AppModule } from '../src/app.module';
import { HttpExceptionFilter } from '../src/common/filters/http-exception.filter';
import { ResponseInterceptor } from '../src/common/interceptors/response.interceptor';
import * as request from 'supertest';

export async function createTestApp(): Promise<INestApplication> {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = moduleFixture.createNestApplication();
  
  app.use(cookieParser());
  app.setGlobalPrefix('api');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new ResponseInterceptor());

  await app.init();
  return app;
}

export async function loginAsAdmin(app: INestApplication): Promise<string[]> {
  const response = await request(app.getHttpServer())
    .post('/api/auth/login')
    .send({
      email: 'admin@crm.local',
      password: 'Admin@123',
    });

  const cookie = response.get('Set-Cookie');
  if (!cookie) {
    throw new Error('Failed to obtain session cookie');
  }
  return Array.isArray(cookie) ? cookie : [cookie];
}
