import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, loginAsAdmin } from './test-utils';

describe('Financials & System (e2e)', () => {
  let app: INestApplication;
  let adminCookie: string[];
  const suffix = `fin-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

  beforeAll(async () => {
    app = await createTestApp();
    adminCookie = await loginAsAdmin(app);
  });

  afterAll(async () => {
    await app.close();
  });

  it('/api/quotations (POST) - Create Quotation', () => {
    return request(app.getHttpServer())
      .post('/api/quotations')
      .set('Cookie', adminCookie)
      .send({
        notes: `Quote ${suffix}`,
        items: [
          { description: 'Service A', quantity: 1, unitPrice: 1000 },
          { description: 'Service B', quantity: 2, unitPrice: 500 }
        ]
      })
      .expect(201)
      .expect((res) => {
        expect(res.body.data.total).toBe(2000); // 1000 + (2 * 500)
      });
  });

  it('/api/dashboard/stats (GET) - Verify Metrics', () => {
    return request(app.getHttpServer())
      .get('/api/dashboard/stats')
      .set('Cookie', adminCookie)
      .expect(200)
      .expect((res) => {
        expect(res.body.data.leads).toBeDefined();
      });
  });

  it('/api/search/global (GET) - Verify Search', () => {
    return request(app.getHttpServer())
      .get('/api/search?q=E2E')
      .set('Cookie', adminCookie)
      .expect(200);
  });

  it('/api/reports/export (GET) - CSV Export', async () => {
    // Ensure data exists locally for this run
    await request(app.getHttpServer())
      .post('/api/leads')
      .set('Cookie', adminCookie)
      .send({ title: `Export Lead ${suffix}`, estimatedValue: 1000 });

    const response = await request(app.getHttpServer())
      .get('/api/reports/export?type=leads')
      .set('Cookie', adminCookie);

    expect(response.status).toBe(200);
    // Use the most robust header check to handle charset or case variations
    const contentType = (response.get('content-type') || '').toLowerCase();
    expect(contentType).toContain('text/csv');
  });
});
