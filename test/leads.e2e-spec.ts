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
      .send({ status: 'negotiation', reason: 'E2E Progress' }); // Note: 'negotiating' was deprecated in favor of 'negotiation'

    expect(response.status).toBe(200);
  });

  it('/api/leads/:id/convert (POST) - Convert Lead to Opportunity', async () => {
    // 1. Create a Contact to satisfy professional guardrails for conversion
    const uniqueEmail = `temp-${Date.now()}-${Math.floor(Math.random() * 100000)}@deal.local`;
    const contactRes = await request(app.getHttpServer())
      .post('/api/contacts')
      .set('Cookie', adminCookie)
      .send({ firstName: 'Deal', lastName: 'Maker', email: uniqueEmail });
      
    const contactId = contactRes.body.data.id;

    // 2. Create the Lead
    const leadRes = await request(app.getHttpServer())
      .post('/api/leads')
      .set('Cookie', adminCookie)
      .send({ 
        title: `Deal Lead ${suffix}`,
        contactId
      });
      
    const leadId = leadRes.body.data.id;

    // 3. Convert Lead to Opportunity
    const response = await request(app.getHttpServer())
      .post(`/api/leads/${leadId}/convert`)
      .set('Cookie', adminCookie)
      .send({}); // DTO only accepts templateId?: string

    console.log('CONVERT LEAD RESPONSE:', JSON.stringify(response.body, null, 2));

    // Accept 200 or 201
    expect([200, 201]).toContain(response.status); 
    expect(response.body.rid).toBe('s-lead-converted');
    
    // Check for the new format returning Deal/Opportunity layer entities
    expect(response.body.data.opportunityId).toBeDefined();
    // accountId/contactId might be explicitly returned by the backend logic as per previous docs
  });
});
