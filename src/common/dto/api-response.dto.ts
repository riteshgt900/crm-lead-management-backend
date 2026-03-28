import { ApiProperty } from '@nestjs/swagger';

export class ApiResponseDto<T> {
  @ApiProperty({ example: 's-success-rid' })
  rid!: string;

  @ApiProperty({ example: 200 })
  statusCode!: number;

  @ApiProperty()
  data!: T;

  @ApiProperty({ example: 'Operation successful' })
  message!: string;

  @ApiProperty({ example: { timestamp: '2026-03-28T07:44:00Z' } })
  meta!: any;
}
