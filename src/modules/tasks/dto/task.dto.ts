import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsUUID } from 'class-validator';

export class CreateTaskDto {
  @ApiProperty({ example: 'Final Painting - Living Room', description: 'The title of the task' })
  @IsString() @IsNotEmpty() title!: string;

  @ApiProperty({ example: 'uuid-project', description: 'Linked Project ID' })
  @IsUUID() @IsNotEmpty() projectId!: string;

  @ApiPropertyOptional({ example: 'uuid-phase' })
  @IsUUID() @IsOptional() phaseId?: string;

  @ApiPropertyOptional({ example: 'uuid-milestone' })
  @IsUUID() @IsOptional() milestoneId?: string;

  @ApiPropertyOptional({ example: 'Wall painting for the living room including ceiling' })
  @IsOptional() @IsString() description?: string;

  @ApiPropertyOptional({ example: 'todo', description: 'Initial status of the task' })
  @IsOptional() @IsString() status?: string;

  @ApiPropertyOptional({ example: 'high', description: 'Priority level' })
  @IsOptional() @IsString() priority?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional() @IsUUID() assignedTo?: string;
}

export class UpdateTaskDto {
  @ApiPropertyOptional({ example: 'in_progress' })
  @IsOptional() @IsString() status?: string;

  @ApiPropertyOptional({ example: 'critical' })
  @IsOptional() @IsString() priority?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional() @IsUUID() assignedTo?: string;
}
