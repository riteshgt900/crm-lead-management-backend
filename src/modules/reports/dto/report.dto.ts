import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class ReportQueryDto {
  @IsString() @IsNotEmpty() type!: string;
  @IsOptional() startDate?: string;
  @IsOptional() endDate?: string;
}
