import { IsString, IsNotEmpty, IsEnum, IsNumber, IsPositive, IsOptional, IsUUID } from 'class-validator';

export class CreateLeadDto {
  @IsString() @IsNotEmpty() title!: string;
  @IsString() @IsOptional() description?: string;
  @IsString() @IsOptional() source?: string;
  @IsString() @IsOptional() status?: string;
  @IsNumber() @IsPositive() @IsOptional() estimatedValue?: number;
  @IsUUID() @IsOptional() contactId?: string;
  @IsUUID() @IsOptional() assignedTo?: string;
}

export class UpdateLeadStatusDto {
  @IsNotEmpty() status!: string;
  @IsOptional() @IsString() reason?: string;
  @IsOptional() @IsString() followUpAt?: string;
}

export class BulkUpdateLeadsDto {
  @IsUUID(undefined, { each: true }) ids!: string[];
  @IsOptional() status?: string;
  @IsOptional() assignedTo?: string;
}
