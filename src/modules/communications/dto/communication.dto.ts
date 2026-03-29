import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export class CreateCommunicationDto {
  @ApiPropertyOptional({ example: 'lead' })
  @IsString() @IsOptional() entityType?: string;

  @ApiPropertyOptional({ example: 'uuid-entity' })
  @IsUUID() @IsOptional() entityId?: string;

  @ApiProperty({ example: 'call' })
  @IsEnum(['call', 'email', 'meeting', 'whatsapp', 'slack', 'other'])
  channel!: string;

  @ApiPropertyOptional({ example: 'inbound', enum: ['inbound', 'outbound', 'internal'] })
  @IsOptional() @IsEnum(['inbound', 'outbound', 'internal']) direction?: string;

  @ApiProperty({ example: 'Initial discovery call' })
  @IsString() @IsNotEmpty() subject!: string;

  @ApiPropertyOptional({ example: 'Discussed project scope and budget' })
  @IsString() @IsOptional() summary?: string;

  @ApiPropertyOptional({ example: '2026-03-28T10:00:00.000Z' })
  @IsDateString() @IsOptional() occurredAt?: string;

  @ApiPropertyOptional({ example: ['uuid-user-1', 'uuid-user-2'] })
  @IsArray() @IsUUID(undefined, { each: true }) @IsOptional() participantIds?: string[];

  @ApiPropertyOptional({ example: '2026-03-29T10:00:00.000Z' })
  @IsDateString() @IsOptional() nextActionAt?: string;

  @ApiPropertyOptional({ example: 'Call notes and transcript text' })
  @IsString() @IsOptional() content?: string;

  @ApiPropertyOptional({ example: 'uuid-contact' })
  @IsUUID() @IsOptional() contactId?: string;

  @ApiPropertyOptional({ example: 'communications' })
  @IsString() @IsOptional() moduleName?: string;

  @ApiPropertyOptional({ example: { source: 'phone' } })
  @IsOptional() metadata?: Record<string, unknown>;

  @ApiPropertyOptional({ example: 'whatsapp', description: 'Backward-compatible alias for channel' })
  @IsOptional() @IsEnum(['call', 'email', 'meeting', 'whatsapp', 'slack', 'other']) type?: string;
}
