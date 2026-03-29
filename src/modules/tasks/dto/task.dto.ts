import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class TaskListQueryDto {
  @ApiPropertyOptional({ example: 'uuid-project' })
  @IsOptional()
  @IsUUID()
  projectId?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ example: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @ApiPropertyOptional({ example: 'todo' })
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional({ example: 'painting' })
  @IsOptional()
  @IsString()
  q?: string;
}

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

  @ApiPropertyOptional({ example: 'uuid-user', description: 'Alias for assigned user' })
  @IsOptional() @IsUUID() assigneeId?: string;

  @ApiPropertyOptional({ example: '2026-04-01T08:00:00.000Z' })
  @IsOptional() @IsString() dueDate?: string;

  @ApiPropertyOptional({ example: 8 })
  @IsOptional() @IsNumber() estimatedHours?: number;

  @ApiPropertyOptional({ example: 'uuid-parent-task' })
  @IsOptional() @IsUUID() parentTaskId?: string;
}

export class UpdateTaskDto {
  @ApiPropertyOptional({ example: 'in_progress' })
  @IsOptional() @IsString() status?: string;

  @ApiPropertyOptional({ example: 'critical' })
  @IsOptional() @IsString() priority?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional() @IsUUID() assignedTo?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional() @IsUUID() assigneeId?: string;

  @ApiPropertyOptional({ example: '2026-04-01T08:00:00.000Z' })
  @IsOptional() @IsString() dueDate?: string;

  @ApiPropertyOptional({ example: 8 })
  @IsOptional() @IsNumber() estimatedHours?: number;

  @ApiPropertyOptional({ example: 'uuid-parent-task' })
  @IsOptional() @IsUUID() parentTaskId?: string;
}
