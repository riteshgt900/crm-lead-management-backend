import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class SearchQueryDto {
  @ApiProperty({ example: 'villa', description: 'Global search query string' })
  @IsString() @IsNotEmpty() q!: string;
}
