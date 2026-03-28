import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, loginAsAdmin } from './test-utils';

describe('ProjectBackbone (e2e)', () => {
  let app: INestApplication;
  let adminCookie: string[];
  let createdProjectId: string;

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
        title: 'E2E Operational Project',
        description: 'Test project backbone',
        status: 'planning',
        estimatedValue: 10000
      })
      .expect(201);

    expect(response.body.rid).toBe('s-project-created');
    createdProjectId = response.body.data.id;
  });

  it('/api/tasks (POST) - Create Task', () => {
    return request(app.getHttpServer())
      .post('/api/tasks')
      .set('Cookie', adminCookie)
      .send({
        projectId: createdProjectId,
        title: 'Initial Setup Task',
        priority: 'high',
        status: 'todo'
      })
      .expect(201)
      .expect((res) => {
        expect(res.body.rid).toBe('s-task-created');
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
});
