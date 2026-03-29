import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateNotificationDto {
  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  isRead?: boolean;

  @ApiPropertyOptional({ example: '2026-03-28T10:00:00.000Z' })
  @IsString()
  @IsOptional()
  readAt?: string;

  @ApiPropertyOptional({ example: 'dismissed from inbox' })
  @IsString()
  @IsOptional()
  note?: string;
}
