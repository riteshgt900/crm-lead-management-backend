import { IsString, IsNotEmpty, IsOptional, IsEnum, IsUUID, IsNumber, IsPositive } from 'class-validator';

export class CreateProjectDto {
  @IsString() @IsNotEmpty() title!: string;
  @IsString() @IsOptional() description?: string;
  @IsString() @IsOptional() status?: string;
  @IsNumber() @IsPositive() @IsOptional() estimatedValue?: number;
  @IsUUID() @IsOptional() contactId?: string;
  @IsUUID() @IsOptional() leadId?: string;
  @IsUUID() @IsOptional() projectManagerId?: string;
}

export class UpdateProjectDto {
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() status?: string;
}
