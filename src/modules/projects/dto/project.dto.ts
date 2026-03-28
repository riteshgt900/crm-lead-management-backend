import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsEnum, IsUUID, IsNumber, IsPositive } from 'class-validator';

export class CreateProjectDto {
  @ApiProperty({ example: 'Villa Fit-out - Sector 45', description: 'The title of the project' })
  @IsString() @IsNotEmpty() title!: string;

  @ApiPropertyOptional({ example: 'Full interior fit-out including MEP and furniture' })
  @IsString() @IsOptional() description?: string;

  @ApiPropertyOptional({ example: 'active', description: 'Initial status of the project' })
  @IsString() @IsOptional() status?: string;

  @ApiPropertyOptional({ example: 1500000, description: 'Budget/Estimated value' })
  @IsNumber() @IsPositive() @IsOptional() estimatedValue?: number;

  @ApiPropertyOptional({ example: 'uuid-contact' })
  @IsUUID() @IsOptional() contactId?: string;

  @ApiPropertyOptional({ example: 'uuid-lead' })
  @IsUUID() @IsOptional() leadId?: string;

  @ApiPropertyOptional({ example: 'uuid-manager', description: 'Assigned Project Manager ID' })
  @IsUUID() @IsOptional() projectManagerId?: string;
}

export class UpdateProjectDto {
  @ApiPropertyOptional({ example: 'Revised Villa Fit-out' })
  @IsOptional() @IsString() title?: string;

  @ApiPropertyOptional({ example: 'completed' })
  @IsOptional() @IsString() status?: string;
}
