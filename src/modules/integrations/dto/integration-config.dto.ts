import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class IntegrationConfigsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @IsOptional()
  @IsString()
  provider?: string;

  @IsOptional()
  @IsString()
  scope?: string;

  @IsOptional()
  @IsIn(['true', 'false'])
  enabledOnly?: string;
}
