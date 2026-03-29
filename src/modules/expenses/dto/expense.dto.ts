import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
} from 'class-validator';

export class CreateExpenseDto {
  @ApiProperty({ example: 'uuid-project' })
  @IsUUID() projectId!: string;

  @ApiProperty({ example: 'materials', enum: ['travel', 'materials', 'labor', 'software', 'marketing', 'other'] })
  @IsEnum(['travel', 'materials', 'labor', 'software', 'marketing', 'other'])
  category!: string;

  @ApiProperty({ example: 12500 })
  @IsNumber() @IsPositive() amount!: number;

  @ApiPropertyOptional({ example: 'INR' })
  @IsString() @IsOptional() currency?: string;

  @ApiPropertyOptional({ example: 'Vendor invoice for wardrobes' })
  @IsString() @IsOptional() description?: string;

  @ApiPropertyOptional({ example: '2026-03-28' })
  @IsDateString() @IsOptional() expenseDate?: string;

  @ApiPropertyOptional({ example: 'uuid-vendor' })
  @IsUUID() @IsOptional() vendorId?: string;

  @ApiPropertyOptional({ example: 'uuid-document' })
  @IsUUID() @IsOptional() receiptDocumentId?: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean() @IsOptional() billable?: boolean;

  @ApiPropertyOptional({ example: 2250 })
  @IsOptional() @IsNumber() taxAmount?: number;

  @ApiPropertyOptional({ example: 'Pending approval' })
  @IsString() @IsOptional() notes?: string;
}
