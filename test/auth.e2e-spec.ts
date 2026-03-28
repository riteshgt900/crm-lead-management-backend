import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, loginAsAdmin } from './test-utils';

describe('AuthModule (e2e)', () => {
  let app: INestApplication;
  let adminCookie: string[];

  beforeAll(async () => {
    app = await createTestApp();
    adminCookie = await loginAsAdmin(app);
  });

  afterAll(async () => {
    await app.close();
  });

  it('/api/auth/login (POST) - Success', () => {
    return request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: 'admin@crm.local', password: 'Admin@123' })
      .expect(200)
      .expect((res) => {
        expect(res.body.rid).toBe('s-login-success');
        expect(res.header['set-cookie']).toBeDefined();
      });
  });

  it('/api/auth/login (POST) - Failure', () => {
    return request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: 'admin@crm.local', password: 'WrongPassword' })
      .expect(401)
      .expect((res) => {
        expect(res.body.rid).toBe('e-invalid-credentials');
      });
  });

  it('/api/auth/profile (GET) - Authenticated', () => {
    return request(app.getHttpServer())
      .get('/api/auth/profile')
      .set('Cookie', adminCookie)
      .expect(200)
      .expect((res) => {
        expect(res.body.data.email).toBe('admin@crm.local');
      });
  });

  it('/api/auth/profile (GET) - Unauthenticated', () => {
    return request(app.getHttpServer())
      .get('/api/auth/profile')
      .expect(401);
  });

  it('/api/auth/logout (POST)', () => {
    return request(app.getHttpServer())
      .post('/api/auth/logout')
      .set('Cookie', adminCookie)
      .expect(200);
  });
});
