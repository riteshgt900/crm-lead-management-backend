import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsEnum, IsNumber, IsPositive, IsOptional, IsUUID } from 'class-validator';

export class CreateLeadDto {
  @ApiProperty({ example: 'Interior design for 3BHK', description: 'The title of the lead' })
  @IsString() @IsNotEmpty() title!: string;

  @ApiPropertyOptional({ example: 'Client looking for premium villa fit-out' })
  @IsString() @IsOptional() description?: string;

  @ApiPropertyOptional({ example: 'website', description: 'Source of the lead' })
  @IsString() @IsOptional() source?: string;

  @ApiPropertyOptional({ example: 'new', description: 'Current status of the lead' })
  @IsString() @IsOptional() status?: string;

  @ApiPropertyOptional({ example: 500000, description: 'Projected value in INR' })
  @IsNumber() @IsPositive() @IsOptional() estimatedValue?: number;

  @ApiPropertyOptional({ example: 'uuid', description: 'Optional linked contact ID' })
  @IsUUID() @IsOptional() contactId?: string;

  @ApiPropertyOptional({ example: 'uuid', description: 'Optional assigned user ID' })
  @IsUUID() @IsOptional() assignedTo?: string;
}

export class UpdateLeadStatusDto {
  @ApiProperty({ example: 'negotiating', description: 'New status for the lead' })
  @IsNotEmpty() status!: string;

  @ApiPropertyOptional({ example: 'Client requested a discount' })
  @IsOptional() @IsString() reason?: string;

  @ApiPropertyOptional({ example: '2026-04-01', description: 'Next follow-up date' })
  @IsOptional() @IsString() followUpAt?: string;
}

export class BulkUpdateLeadsDto {
  @ApiProperty({ example: ['uuid1', 'uuid2'], description: 'List of Lead IDs to update' })
  @IsUUID(undefined, { each: true }) ids!: string[];

  @ApiPropertyOptional({ example: 'qualified' })
  @IsOptional() status?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional() assignedTo?: string;
}
