import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class ProjectListQueryDto {
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

  @ApiPropertyOptional({ example: 'villa' })
  @IsOptional()
  @IsString()
  q?: string;

  @ApiPropertyOptional({ example: 'planning' })
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional()
  @IsUUID()
  projectManagerId?: string;
}

export class CreateProjectDto {
  @ApiProperty({ example: 'Villa Fit-out - Sector 45', description: 'The title of the project' })
  @IsString() @IsNotEmpty() title!: string;

  @ApiPropertyOptional({ example: 'Full interior fit-out including MEP and furniture' })
  @IsString() @IsOptional() description?: string;

  @ApiPropertyOptional({ example: 'active', description: 'Initial status of the project' })
  @IsString() @IsOptional() status?: string;

  @ApiPropertyOptional({ example: 1500000, description: 'Budget/Estimated value' })
  @IsNumber() @IsPositive() @IsOptional() estimatedValue?: number;

  @ApiPropertyOptional({ example: 1500000, description: 'Alias for estimated value used by the frontend contract' })
  @IsNumber() @IsPositive() @IsOptional() budget?: number;

  @ApiPropertyOptional({ example: 'uuid-contact' })
  @IsUUID() @IsOptional() contactId?: string;

  @ApiPropertyOptional({ example: 'uuid-lead' })
  @IsUUID() @IsOptional() leadId?: string;

  @ApiPropertyOptional({ example: 'uuid', description: 'Assigned Project Manager' })
  @IsOptional() @IsUUID() projectManagerId?: string;

  @ApiPropertyOptional({ example: 'uuid', description: 'Alias for assigned project manager' })
  @IsOptional() @IsUUID() managerId?: string;

  @ApiPropertyOptional({ example: '2026-04-01T00:00:00.000Z' })
  @IsOptional() @IsString() startDate?: string;

  @ApiPropertyOptional({ example: '2026-08-01T00:00:00.000Z' })
  @IsOptional() @IsString() endDate?: string;
}

export class UpdateProjectDto {
  @ApiPropertyOptional({ example: 'Revised Villa Fit-out' })
  @IsOptional() @IsString() title?: string;

  @ApiPropertyOptional({ example: 'Revised scope with added joinery package' })
  @IsOptional() @IsString() description?: string;

  @ApiPropertyOptional({ example: 'completed' })
  @IsOptional() @IsString() status?: string;

  @ApiPropertyOptional({ example: 1750000 })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  estimatedValue?: number;

  @ApiPropertyOptional({ example: 1750000 })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  budget?: number;

  @ApiPropertyOptional({ example: 'uuid-contact' })
  @IsOptional() @IsUUID() contactId?: string;

  @ApiPropertyOptional({ example: 'uuid-lead' })
  @IsOptional() @IsUUID() leadId?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional() @IsUUID() projectManagerId?: string;

  @ApiPropertyOptional({ example: 'uuid-user' })
  @IsOptional() @IsUUID() managerId?: string;

  @ApiPropertyOptional({ example: '2026-04-01T00:00:00.000Z' })
  @IsOptional() @IsString() startDate?: string;

  @ApiPropertyOptional({ example: '2026-08-01T00:00:00.000Z' })
  @IsOptional() @IsString() endDate?: string;
}
