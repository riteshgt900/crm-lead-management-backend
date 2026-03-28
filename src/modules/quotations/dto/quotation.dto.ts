import { IsString, IsNotEmpty, IsOptional, IsUUID, IsNumber, IsPositive, IsArray, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class QuotationItemDto {
  @IsString() @IsNotEmpty() description!: string;
  @IsNumber() @IsPositive() quantity!: number;
  @IsNumber() @IsPositive() unitPrice!: number;
}

export class CreateQuotationDto {
  @IsUUID() @IsOptional() leadId?: string;
  @IsUUID() @IsOptional() contactId?: string;
  @IsString() @IsOptional() notes?: string;
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => QuotationItemDto)
  items!: QuotationItemDto[];
}
