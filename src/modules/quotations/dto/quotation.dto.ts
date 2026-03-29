import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsNumber,
  IsNotEmpty,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class QuotationLineItemDto {
  @ApiProperty({ example: 'Modular wardrobe installation' })
  @IsString() @IsNotEmpty() description!: string;

  @ApiProperty({ example: 1 })
  @IsNumber() @IsPositive() quantity!: number;

  @ApiProperty({ example: 12500 })
  @IsNumber() @IsPositive() unitPrice!: number;

  @ApiPropertyOptional({ example: 0.18 })
  @IsOptional() @IsNumber() taxRate?: number;
}

export class CreateQuotationDto {
  @ApiPropertyOptional({ example: 'uuid-lead' })
  @IsUUID() @IsOptional() leadId?: string;

  @ApiPropertyOptional({ example: 'uuid-project' })
  @IsUUID() @IsOptional() projectId?: string;

  @ApiPropertyOptional({ example: 'uuid-account' })
  @IsUUID() @IsOptional() accountId?: string;

  @ApiPropertyOptional({ example: 'uuid-contact' })
  @IsUUID() @IsOptional() contactId?: string;

  @ApiPropertyOptional({ example: 'INR' })
  @IsString() @IsOptional() currency?: string;

  @ApiPropertyOptional({ example: '2026-04-30' })
  @IsDateString() @IsOptional() validUntil?: string;

  @ApiPropertyOptional({ example: 'inclusive', enum: ['inclusive', 'exclusive', 'exempt'] })
  @IsOptional() @IsEnum(['inclusive', 'exclusive', 'exempt']) taxMode?: string;

  @ApiPropertyOptional({ example: 0 })
  @IsOptional() @IsNumber() discount?: number;

  @ApiPropertyOptional({ example: 'Standard terms apply' })
  @IsString() @IsOptional() notes?: string;

  @ApiPropertyOptional({ example: 'Net 30, subject to scope sign-off' })
  @IsString() @IsOptional() terms?: string;

  @ApiPropertyOptional({ type: [QuotationLineItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => QuotationLineItemDto)
  @IsOptional()
  lineItems?: QuotationLineItemDto[];

  @ApiPropertyOptional({ type: [QuotationLineItemDto], description: 'Backward-compatible alias for lineItems' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => QuotationLineItemDto)
  @IsOptional()
  items?: QuotationLineItemDto[];
}
