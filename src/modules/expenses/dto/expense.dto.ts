import { IsString, IsNotEmpty, IsOptional, IsUUID, IsNumber, IsPositive } from 'class-validator';

export class CreateExpenseDto {
  @IsUUID() projectId!: string;
  @IsString() @IsNotEmpty() category!: string;
  @IsNumber() @IsPositive() amount!: number;
  @IsString() @IsOptional() description?: string;
  @IsString() @IsOptional() expenseDate?: string;
}
