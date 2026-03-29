import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export class CreateContactDto {
  @ApiPropertyOptional({ example: 'uuid-account' })
  @IsUUID() @IsOptional() accountId?: string;

  @ApiProperty({ example: 'John' })
  @IsString() @IsNotEmpty() firstName!: string;

  @ApiProperty({ example: 'Doe' })
  @IsString() @IsNotEmpty() lastName!: string;

  @ApiPropertyOptional({ example: 'john.doe@example.com' })
  @IsEmail() @IsOptional() email?: string;

  @ApiPropertyOptional({ example: '+1234567890' })
  @IsString() @IsOptional() phone?: string;

  @ApiPropertyOptional({ example: '+1234567891' })
  @IsString() @IsOptional() altPhone?: string;

  @ApiPropertyOptional({ example: 'Senior Architect' })
  @IsString() @IsOptional() designation?: string;

  @ApiPropertyOptional({ example: 'Design co.' })
  @IsString() @IsOptional() companyName?: string;

  @ApiPropertyOptional({ example: 'architect', enum: ['individual', 'architect', 'pmc', 'vendor'] })
  @IsOptional() @IsEnum(['individual', 'architect', 'pmc', 'vendor']) category?: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean() @IsOptional() isPrimary?: boolean;

  @ApiPropertyOptional({ example: '12 Crescent Road' })
  @IsString() @IsOptional() address?: string;

  @ApiPropertyOptional({ example: 'Gurugram' })
  @IsString() @IsOptional() city?: string;

  @ApiPropertyOptional({ example: 'Haryana' })
  @IsString() @IsOptional() state?: string;

  @ApiPropertyOptional({ example: 'India' })
  @IsString() @IsOptional() country?: string;

  @ApiPropertyOptional({ example: 'Asia/Kolkata' })
  @IsString() @IsOptional() timezone?: string;

  @ApiPropertyOptional({ example: 'Key decision maker' })
  @IsString() @IsOptional() notes?: string;
}

export class UpdateContactDto {
  @ApiPropertyOptional({ example: 'uuid-account' })
  @IsOptional() @IsUUID() accountId?: string;

  @ApiPropertyOptional({ example: 'John' })
  @IsOptional() @IsString() firstName?: string;

  @ApiPropertyOptional({ example: 'Doe' })
  @IsOptional() @IsString() lastName?: string;

  @ApiPropertyOptional({ example: 'john.doe@example.com' })
  @IsOptional() @IsEmail() email?: string;

  @ApiPropertyOptional({ example: '+1234567890' })
  @IsOptional() @IsString() phone?: string;

  @ApiPropertyOptional({ example: '+1234567891' })
  @IsOptional() @IsString() altPhone?: string;

  @ApiPropertyOptional({ example: 'Senior Architect' })
  @IsOptional() @IsString() designation?: string;

  @ApiPropertyOptional({ example: 'Design co.' })
  @IsOptional() @IsString() companyName?: string;

  @ApiPropertyOptional({ example: 'pmc', enum: ['individual', 'architect', 'pmc', 'vendor'] })
  @IsOptional() @IsEnum(['individual', 'architect', 'pmc', 'vendor']) category?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional() @IsBoolean() isPrimary?: boolean;

  @ApiPropertyOptional({ example: '12 Crescent Road' })
  @IsOptional() @IsString() address?: string;

  @ApiPropertyOptional({ example: 'Gurugram' })
  @IsOptional() @IsString() city?: string;

  @ApiPropertyOptional({ example: 'Haryana' })
  @IsOptional() @IsString() state?: string;

  @ApiPropertyOptional({ example: 'India' })
  @IsOptional() @IsString() country?: string;

  @ApiPropertyOptional({ example: 'Asia/Kolkata' })
  @IsOptional() @IsString() timezone?: string;

  @ApiPropertyOptional({ example: 'Key decision maker' })
  @IsOptional() @IsString() notes?: string;
}
