import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, loginAsAdmin } from './test-utils';

describe('ProjectBackbone (e2e)', () => {
  let app: INestApplication;
  let adminCookie: string[];
  let createdProjectId: string;
  const suffix = `proj-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

  beforeAll(async () => {
    app = await createTestApp();
    adminCookie = await loginAsAdmin(app);
  });

  afterAll(async () => {
    await app.close();
  });

  it('/api/projects (POST) - Create Project', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/projects')
      .set('Cookie', adminCookie)
      .send({
        title: `Project ${suffix}`,
        description: 'Test project backbone',
        status: 'planning',
        estimatedValue: 10000
      })
      .expect(201);

    expect(response.body.rid).toBe('s-project-created');
    expect(response.body.data.projectNumber).toBeDefined();
    createdProjectId = response.body.data.id;
  });

  it('/api/tasks (POST) - Create Task', () => {
    return request(app.getHttpServer())
      .post('/api/tasks')
      .set('Cookie', adminCookie)
      .send({
        projectId: createdProjectId,
        title: `Task ${suffix}`,
        priority: 'high',
        status: 'todo',
        estimatedHours: 8
      })
      .expect(201)
      .expect((res) => {
        expect(res.body.rid).toBe('s-task-created');
        expect(res.body.data.taskNumber).toBeDefined();
      });
  });

  it('/api/tasks (GET) - List Tasks', () => {
    return request(app.getHttpServer())
      .get(`/api/tasks?projectId=${createdProjectId}`)
      .set('Cookie', adminCookie)
      .expect(200)
      .expect((res) => {
        expect(res.body.rid).toBe('s-tasks-listed');
      });
  });

  it('/api/projects (GET) - List Templates', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/projects/templates')
      .set('Cookie', adminCookie)
      .expect(200);

    expect(response.body.rid).toBe('s-templates-listed');
    expect(Array.isArray(response.body.data)).toBe(true);
  });

  it('/api/projects/:id/activity (GET) - Activity Feed', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/projects/${createdProjectId}/activity`)
      .set('Cookie', adminCookie)
      .expect(200);

    expect(response.body.rid).toBe('s-audit-logs-listed');
    expect(Array.isArray(response.body.data)).toBe(true);
  });
});
