import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, loginAsAdmin } from './test-utils';

describe('LeadsModule (e2e)', () => {
  let app: INestApplication;
  let adminCookie: string[];
  let createdLeadId: string;
  const suffix = `lead-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

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
        title: `Lead ${suffix}`,
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

  it('/api/leads/:id/convert (POST) - Convert Lead with Template', async () => {
    // 1. Get a template
    const templatesRes = await request(app.getHttpServer())
      .get('/api/projects/templates')
      .set('Cookie', adminCookie);
    const templateId = templatesRes.body.data[0]?.id;

    if (!templateId) {
      console.warn('No templates found in seed data, skipping template clonning test part');
      return;
    }

    // 2. Create lead with contact (using high-entropy unique email)
    const uniqueEmail = `temp-${Date.now()}-${Math.floor(Math.random() * 100000)}@test.local`;
    const contactRes = await request(app.getHttpServer())
      .post('/api/contacts')
      .set('Cookie', adminCookie)
      .send({ firstName: 'Templated', lastName: 'Lead', email: uniqueEmail });
    const contactId = contactRes.body.data.id;

    const leadRes = await request(app.getHttpServer())
      .post('/api/leads')
      .set('Cookie', adminCookie)
      .send({ title: `Templated Lead ${suffix}`, contactId });
    const leadId = leadRes.body.data.id;

    // 3. Convert with template
    const response = await request(app.getHttpServer())
      .post(`/api/leads/${leadId}/convert`)
      .set('Cookie', adminCookie)
      .send({ templateId });

    expect(response.status).toBe(201); // Standard POST status
    expect(response.body.rid).toBe('s-lead-converted');
    expect(response.body.data.projectId).toBeDefined();
  });
});
