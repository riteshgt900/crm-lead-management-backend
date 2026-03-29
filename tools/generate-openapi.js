require('ts-node/register');
require('tsconfig-paths/register');
require('reflect-metadata');

const fs = require('fs');
const path = require('path');
const { NestFactory } = require('@nestjs/core');
const { SwaggerModule, DocumentBuilder } = require('@nestjs/swagger');
const { AppModule } = require('../src/app.module');

async function generateOpenApi() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('api');
  await app.init();

  const config = new DocumentBuilder()
    .setTitle('CRM Backend API')
    .setDescription('The core API for CRM Lead Management and Project Coordination.')
    .setVersion('1.0')
    .addCookieAuth('crm_session', {
      type: 'apiKey',
      in: 'cookie',
      name: 'crm_session',
      description: 'Session cookie (HttpOnly)',
    })
    .build();

  const document = SwaggerModule.createDocument(app, config);
  const outputPath = path.join(__dirname, '../docs/openapi.json');
  fs.writeFileSync(outputPath, JSON.stringify(document, null, 2), 'utf8');

  await app.close();
  console.log(`OpenAPI document written to ${outputPath}`);
}

generateOpenApi().catch((error) => {
  console.error('Failed to generate OpenAPI document:', error);
  process.exitCode = 1;
});
