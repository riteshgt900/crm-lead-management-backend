import {
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UploadDocumentDto {
  @ApiPropertyOptional({ example: 'project-brief.pdf' })
  @IsString()
  @IsOptional()
  title?: string;

  @ApiPropertyOptional({ example: 'projects', description: 'Preferred runtime entity or legacy module name' })
  @IsString()
  @IsOptional()
  entityType?: string;

  @ApiPropertyOptional({ example: 'projects', description: 'Legacy alias kept for compatibility' })
  @IsString()
  @IsOptional()
  moduleName?: string;

  @ApiPropertyOptional({ example: 'uuid' })
  @IsUUID()
  @IsOptional()
  entityId?: string;

  @ApiPropertyOptional({ example: 'design' })
  @IsString()
  @IsOptional()
  category?: string;

  @ApiPropertyOptional({ example: 'v1.0' })
  @IsString()
  @IsOptional()
  versionLabel?: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  approvalRequired?: boolean;

  @ApiPropertyOptional({ example: 'internal', enum: ['internal', 'external', 'restricted'] })
  @IsIn(['internal', 'external', 'restricted'])
  @IsOptional()
  shareMode?: string;

  @ApiPropertyOptional({ example: 'Initial release package' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ example: ['design', 'client'] })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  tags?: string[];
}

export class ApproveDocumentDto {
  @ApiPropertyOptional({ example: 'approved', enum: ['approved', 'rejected'] })
  @IsIn(['approved', 'rejected'])
  @IsOptional()
  decision?: string;

  @ApiPropertyOptional({ example: 'Approved after final review' })
  @IsString()
  @IsOptional()
  comment?: string;

  @ApiPropertyOptional({ example: 'v1.1' })
  @IsString()
  @IsOptional()
  versionLabel?: string;

  @ApiPropertyOptional({ example: 'uuid-parent-document' })
  @IsUUID()
  @IsOptional()
  parentDocumentId?: string;
}
