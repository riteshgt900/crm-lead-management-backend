import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);

  constructor(private configService: ConfigService) {}

  async sendEmail(to: string, subject: string, template: string, context: any) {
    this.logger.log(`Sending email to ${to}: ${subject}`);
    this.logger.debug(`Template: ${template}, Context: ${JSON.stringify(context)}`);
    
    // SMTP Placeholder implementation
    const smtpHost = this.configService.get('SMTP_HOST');
    if (!smtpHost) {
      this.logger.warn('SMTP_HOST not configured. Email will not be sent in reality.');
    }

    return { success: true, messageId: `msg-${Date.now()}` };
  }
}
