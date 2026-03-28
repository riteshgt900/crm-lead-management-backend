import { IsString, IsNotEmpty, IsOptional, IsUUID, IsEnum } from 'class-validator';

export class CreateTaskDto {
  @IsString() @IsNotEmpty() title!: string;
  @IsUUID() projectId!: string;
  @IsUUID() @IsOptional() phaseId?: string;
  @IsUUID() @IsOptional() milestoneId?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() priority?: string;
  @IsOptional() @IsUUID() assignedTo?: string;
}

export class UpdateTaskDto {
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() priority?: string;
  @IsOptional() @IsUUID() assignedTo?: string;
}
