import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from '../src/app.module';
import * as fs from 'fs';
import * as path from 'path';

async function generate() {
  const app = await NestFactory.create(AppModule, { logger: false });
  
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
  
  fs.writeFileSync(outputPath, JSON.stringify(document, null, 2));
  console.log(`OpenAPI JSON generated successfully at: ${outputPath}`);
  
  await app.close();
}

generate().catch(err => {
  console.error('Failed to generate OpenAPI JSON:', err);
  process.exit(1);
});
