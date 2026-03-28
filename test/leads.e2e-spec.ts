import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, loginAsAdmin } from './test-utils';

describe('LeadsModule (e2e)', () => {
  let app: INestApplication;
  let adminCookie: string[];
  let createdLeadId: string;

  beforeAll(async () => {
    app = await createTestApp();
    adminCookie = await loginAsAdmin(app);
  });

  afterAll(async () => {
    await app.close();
  });

  it('/api/leads (POST) - Create Lead', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/leads')
      .set('Cookie', adminCookie)
      .send({
        title: 'E2E Test Lead',
        description: 'Lead created by automated E2E test',
        source: 'referral',
        estimatedValue: 5000
      })
      .expect(201);

    expect(response.body.rid).toBe('s-lead-created');
    createdLeadId = response.body.data.id;
  });

  it('/api/leads (GET) - List Leads', () => {
    return request(app.getHttpServer())
      .get('/api/leads')
      .set('Cookie', adminCookie)
      .expect(200)
      .expect((res) => {
        expect(res.body.rid).toBe('s-leads-listed');
        expect(Array.isArray(res.body.data)).toBe(true);
      });
  });

  it('/api/leads/:id/status (PATCH) - Update Status', async () => {
    const response = await request(app.getHttpServer())
      .patch(`/api/leads/${createdLeadId}/status`)
      .set('Cookie', adminCookie)
      .send({ status: 'negotiating', reason: 'E2E Progress' });

    expect(response.status).toBe(200);
  });

  it('/api/leads/:id/convert (POST) - Convert Lead', async () => {
    const uniqueEmail = `conversion-${Date.now()}@test.local`;
    const contactRes = await request(app.getHttpServer())
      .post('/api/contacts')
      .set('Cookie', adminCookie)
      .send({
        firstName: 'Lead',
        lastName: 'Project-Contact',
        email: uniqueEmail
      });
    
    expect(contactRes.status).toBe(201);
    const contactId = contactRes.body.data.id;

    const linkedLeadRes = await request(app.getHttpServer())
      .post('/api/leads')
      .set('Cookie', adminCookie)
      .send({
        title: 'Linked Lead for Conversion',
        contactId: contactId
      });
    const linkedLeadId = linkedLeadRes.body.data.id;

    const response = await request(app.getHttpServer())
      .post(`/api/leads/${linkedLeadId}/convert`)
      .set('Cookie', adminCookie);

    expect(response.status).toBe(201);
    expect(response.body.rid).toBe('s-lead-converted');
  });
});
