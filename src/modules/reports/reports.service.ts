import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ReportQueryDto } from './dto/report.dto';

@Injectable()
export class ReportsService {
  constructor(private db: DatabaseService) {}

  async generate(dto: ReportQueryDto, user: any) {
    return this.callRuntimeAware('report.generate', 'fn_report_operations', {
      operation: 'generate_report',
      data: dto,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  async exportCsv(type: string, user: any): Promise<string> {
    const result = await this.callRuntimeAware('report.export_csv', 'fn_report_operations', {
      operation: 'export_csv',
      data: { type },
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });

    if (result.statusCode !== 200 || !Array.isArray(result.data)) {
      return 'Status,Message\nError,No data available for export';
    }

    return this.convertToCsv(result.data);
  }

  async getWeeklySummary(user: any) {
    return this.callRuntimeAware('dashboard.stats', 'fn_dashboard_operations', {
      operation: 'get_stats',
      data: { period: 'last_7_days' },
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  private async callRuntimeAware(
    endpointKey: string,
    fallbackFn: string,
    payload: Record<string, unknown>,
  ) {
    const registryEntry = await this.db.getRegistryEntry(endpointKey);

    if (registryEntry?.dispatcherFn && registryEntry.isEnabled) {
      return this.db.callDispatcher(registryEntry.dispatcherFn, payload);
    }

    return this.db.callDispatcher(fallbackFn, payload);
  }

  private convertToCsv(data: any[]): string {
    if (data.length === 0) return 'Status,Message\nEmpty,No rows to export';

    const headers = Object.keys(data[0]);
    const escapeValue = (value: unknown) => {
      if (value === null || value === undefined) {
        return '""';
      }

      const normalized = String(value).replace(/"/g, '""');
      return `"${normalized}"`;
    };

    const csvContent = data
      .map((row) => headers.map((header) => escapeValue((row as any)[header])).join(','))
      .join('\n');

    return `${headers.join(',')}\n${csvContent}`;
  }
}
