import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { DatabaseModule } from './database/database.module';
import { EmailModule } from './modules/email/email.module';
import { CronModule } from './modules/cron/cron.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { LeadsModule } from './modules/leads/leads.module';
import { ContactsModule } from './modules/contacts/contacts.module';
import { ProjectsModule } from './modules/projects/projects.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { DocumentsModule } from './modules/documents/documents.module';
import { CommunicationsModule } from './modules/communications/communications.module';
import { QuotationsModule } from './modules/quotations/quotations.module';
import { ExpensesModule } from './modules/expenses/expenses.module';
import { WorkflowsModule } from './modules/workflows/workflows.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ReportsModule } from './modules/reports/reports.module';
import { DashboardModule } from './modules/dashboard/dashboard.module';
import { SearchModule } from './modules/search/search.module';
import { AuditModule } from './modules/audit/audit.module';
import { IntegrationsModule } from './modules/integrations/integrations.module';
import { ShareModule } from './modules/share/share.module';
import { RbacModule } from './modules/rbac/rbac.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    ScheduleModule.forRoot(),
    ThrottlerModule.forRoot([
      {
        ttl: parseInt(process.env.THROTTLE_TTL || '60000'),
        limit: parseInt(process.env.THROTTLE_LIMIT || '100'),
      },
    ]),
    DatabaseModule,
    EmailModule,
    CronModule,
    AuthModule,
    UsersModule,
    LeadsModule,
    ContactsModule,
    ProjectsModule,
    TasksModule,
    DocumentsModule,
    CommunicationsModule,
    QuotationsModule,
    ExpensesModule,
    WorkflowsModule,
    NotificationsModule,
    ReportsModule,
    DashboardModule,
    SearchModule,
    AuditModule,
    IntegrationsModule,
    ShareModule,
    RbacModule,
  ],
})
export class AppModule {}
